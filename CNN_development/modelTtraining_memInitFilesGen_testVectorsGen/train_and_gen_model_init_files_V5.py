#!/usr/bin/env python3
"""
train_and_gen_model_init_files_V5.py
====================================
Generalized CNN-to-hardware compiler.

Accepts **any** custom CNN built from Conv2d, ReLU, MaxPool2d, and Linear
layers and compiles it into the exact instruction, weight, and activation
BRAM images consumed by the RTL accelerator.

USAGE
-----
1.  Define your model class (bias=False on all Conv2d / Linear layers).
2.  Describe the hardware mapping with the layer descriptors:
        HWConv('conv1', relu=True)   – maps nn.Conv2d 'conv1'
        HWPool(kernel_size=2)        – max-pool instruction
        HWFC('fc1', relu=True)       – maps nn.Linear 'fc1' (as full-kernel conv)
        HWFlatten()                  – (optional) marks conv→FC boundary
3.  Set configuration constants and run.

OUTPUT FILES
------------
  Vivado : bram_weights_init.coe, bram_instructions_init.coe
  Sim    : bram_weights_init.hex, bram_instructions_init.hex,
           test_image_uart_bytes.hex, expected_class.hex,
           ground_truth_summary.txt

HARDWARE CONSTRAINTS (validated automatically)
----------------------------------------------
  NO_OF_FILTER  : 4-bit  → max 15 output channels per conv instruction
  Addresses     : 14-bit → max 16 383 BRAM words
  Dims          : 10-bit → max 1 023
  MAX_FMAP_DIM  : 32  (synthesis-time)
  MAX_KERNEL_W  : 5   (synthesis-time, as instantiated in top.v)
  MAX_OUT_WIDTH : 28  (synthesis-time)
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
import torchvision
import torchvision.transforms as transforms
from tqdm.auto import tqdm
import numpy as np
import os, struct, sys

# ==========================================================================
#  HARDWARE LAYER DESCRIPTORS  (used by the compiler, not by PyTorch)
# ==========================================================================

class HWConv:
    """Map an nn.Conv2d parameter to a hardware convolution instruction."""
    def __init__(self, param_name, relu=True):
        self.op         = 'conv'
        self.param_name = param_name   # name in model.named_modules()
        self.relu       = relu

class HWPool:
    """Emit a hardware max-pool instruction."""
    def __init__(self, kernel_size=2):
        self.op          = 'pool'
        self.kernel_size = kernel_size

class HWFC:
    """Map an nn.Linear parameter to a full-kernel conv instruction."""
    def __init__(self, param_name, relu=False):
        self.op         = 'fc'
        self.param_name = param_name
        self.relu       = relu

class HWFlatten:
    """Optional marker at the conv→FC boundary (no hardware instruction)."""
    def __init__(self):
        self.op = 'flatten'


# ==========================================================================
#  ██  USER CONFIGURATION — EDIT THIS SECTION  ██
# ==========================================================================

# ---- 1. Model definition ------------------------------------------------
class UserCNN(nn.Module):
    """
    Replace this with any architecture.  Rules:
      • Every Conv2d and Linear must use  bias=False.
      • Conv2d must use  padding=0  (the hardware does valid convolution).
      • The forward() must return  (logits, *optional_intermediates).
    """
    def __init__(self):
        super().__init__()
        # Layer 1: 28x28 in -> 24x24 out
        self.conv1 = nn.Conv2d(1, 4, kernel_size=5, bias=False)
        
        # Layer 2: 12x12 in -> 8x8 out
        self.conv2 = nn.Conv2d(4, 8, kernel_size=5, bias=False)
        
        # FC Layer: 4x4 in -> mapped as a 4x4 convolution (Fits MAX_KERNEL_W=5)
        self.fc    = nn.Linear(8 * 4 * 4, 10, bias=False)

    def forward(self, x):
        c1   = self.conv1(x)
        r1   = F.relu(c1)
        p1   = F.max_pool2d(r1, 2)
        
        c2   = self.conv2(p1)
        r2   = F.relu(c2)
        p2   = F.max_pool2d(r2, 2)
        
        flat = p2.view(p2.size(0), -1)
        out  = self.fc(flat)
        return out                    # return logits (at minimum)


# ---- 2. Hardware layer mapping -------------------------------------------
#   List the operations in the EXACT order the hardware must execute them.
#   The compiler walks this list to emit instructions.

LAYERS = [
    HWConv('conv1', relu=True),       # Conv1 + ReLU  → opcode 0x01
    HWPool(kernel_size=2),            # MaxPool 2×2   → opcode 0x02
    HWConv('conv2', relu=True),       # Conv2 + ReLU  → opcode 0x01
    HWPool(kernel_size=2),            # MaxPool 2×2   → opcode 0x02
    HWFC('fc', relu=False),           # FC (no ReLU)  → opcode 0x01
    # Classifier (argmax) + Halt are appended automatically.
]


# ---- 3. Training / quantisation knobs -----------------------------------
TRAIN_MODEL    = False            # Model must be retrained to learn new features
NUM_EPOCHS     = 5
LEARNING_RATE  = 0.005
BATCH_SIZE     = 256
FRAC_BITS      = 10
SCALE          = 2 ** FRAC_BITS
TEST_IMAGE_IDX = 0               # MNIST test image sent to the DUT
NUM_TEST_IMAGES = 10             # multi-image test set (balanced across digits)

# ---- 4. Synthesis-time PE-array limits (from your top.v instantiation) ---
HW_MAX_FMAP_DIM    = 32
HW_MAX_KERNEL_W    = 5           # Reduced to 5 to match ops_convrelu instantiation
HW_MAX_OUT_WIDTH   = 28
HW_MAX_FILTERS     = 15          # NO_OF_FILTER is 4 bits

# ==========================================================================
#  ██  END OF USER CONFIGURATION  ██
# ==========================================================================


# ==========================================================================
#  INSTRUCTION PACKING HELPERS (match controller.v decode logic)
# ==========================================================================
def pack_word0(opcode, in_act, in_wgt, out_act):
    """Word 0: opcode[63:56] | in_act_addr[55:42] | in_wgt_addr[41:28] | out_act_addr[27:14]"""
    return ((opcode & 0xFF) << 56) | ((in_act & 0x3FFF) << 42) | \
           ((in_wgt & 0x3FFF) << 28) | ((out_act & 0x3FFF) << 14)

def pack_word1(d1, d2, d3, w1, w2, w3):
    """Word 1: inp_dim1[63:54] | inp_dim2[53:44] | inp_dim3[43:34] |
               wgt_dim1[33:24] | wgt_dim2[23:14] | wgt_dim3[13:4]"""
    return ((d1 & 0x3FF) << 54) | ((d2 & 0x3FF) << 44) | ((d3 & 0x3FF) << 34) | \
           ((w1 & 0x3FF) << 24) | ((w2 & 0x3FF) << 14) | ((w3 & 0x3FF) << 4)

def pack_word2(o1, o2, o3, pool, stride, nfilt, flags):
    """Word 2: out_dim1[63:54] | out_dim2[53:44] | out_dim3[43:34] |
               pool_dim[33:26] | stride[25:18] | nfilt[17:14] | flags[13:0]"""
    return ((o1 & 0x3FF) << 54) | ((o2 & 0x3FF) << 44) | ((o3 & 0x3FF) << 34) | \
           ((pool & 0xFF) << 26) | ((stride & 0xFF) << 18) | \
           ((nfilt & 0xF) << 14) | (flags & 0x3FFF)


# ==========================================================================
#  QUANTISATION HELPERS
# ==========================================================================
def quantize_tensor(tensor, scale):
    q = torch.round(tensor * scale)
    return torch.clamp(q, -32768, 32767).to(torch.int16)

def to_s16(v):
    """Reinterpret an integer as signed 16-bit."""
    v = int(v) & 0xFFFF
    return v - 0x10000 if v >= 0x8000 else v

def to_s32(v):
    """Reinterpret an integer as signed 32-bit (match HW accumulator wrap)."""
    v = int(v) & 0xFFFFFFFF
    return v - 0x100000000 if v >= 0x80000000 else v


def build_uart_stream(img_q_2d, H, W, C):
    """
    Build the complete UART byte stream for one image.
    Matches serial_to_bram.v: start magic → H/W/C header → pixel data → end magic.

    Parameters
    ----------
    img_q_2d : np.ndarray[int16]  –  quantised pixels, shape (H, W) or (C, H, W)
    H, W, C  : int                –  spatial dims (always passed explicitly)

    Returns
    -------
    bytearray of length  8 + 6 + ((W+7)//8)*H*C*16 + 8
    """
    uart = bytearray()

    # Start magic
    uart.extend(bytes([0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x11, 0x22]))

    # Header: H, W, C  (16-bit little-endian)
    uart.extend(struct.pack('<HHH', H, W, C))

    words_per_row = (W + 7) // 8

    # Pixel data  — packing matches the serial_to_bram shift register
    for c in range(C):
        for row in range(H):
            for wd in range(words_per_row):
                for p in range(8):
                    col = wd * 8 + p
                    if img_q_2d.ndim == 2:
                        pix = int(img_q_2d[row, col]) & 0xFFFF if col < W else 0
                    else:  # (C, H, W)
                        pix = int(img_q_2d[c, row, col]) & 0xFFFF if col < W else 0
                    uart.append(pix & 0xFF)
                    uart.append((pix >> 8) & 0xFF)

    # End magic
    uart.extend(bytes([0x22, 0x11, 0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA]))
    return uart


# ==========================================================================
#  HARDWARE COMPILER
# ==========================================================================
HW_SEG7_RESULT_ADDR = 8190  # shifted far ahead of possible activations in BRAM. Must match seg7_driver.v
class HWCompiler:
    """
    Walks the LAYERS list, allocates BRAM addresses, emits instructions,
    extracts quantised weights, and computes fixed-point ground truth.
    """

    def __init__(self, model, layers, input_hwc):
        """
        Parameters
        ----------
        model     : nn.Module  –  trained model with quantisable weights
        layers    : list       –  sequence of HWConv / HWPool / HWFC / HWFlatten
        input_hwc : tuple      –  (H, W, C) of the input image
        """
        self.model  = model
        self.layers = layers
        self.in_h, self.in_w, self.in_c = input_hwc

        # Populated by compile()
        self.all_weights_i16 = None          # np.ndarray  int16
        self.instructions    = []            # list[int]   64-bit words
        self.stage_shapes    = []            # [(H, W, C), ...]  per activation stage
        self.stage_addrs     = []            # [base_addr, ...]
        self.stage_names     = []            # [str, ...]
        self.wgt_map         = {}            # param_name → (bram_offset, count)
        self.num_classes     = None
        self.classifier_in_addr  = None
        self.classifier_out_addr = None

    # ------------------------------------------------------------------
    @staticmethod
    def _words_for(H, W, C):
        """Number of 128-bit BRAM words for an [H, W, C] activation map."""
        wpr = (W + 7) // 8     # words per row
        return wpr * H * C

    # ------------------------------------------------------------------
    def _get_module(self, name):
        """Retrieve a named sub-module from the model."""
        mods = dict(self.model.named_modules())
        if name not in mods:
            raise KeyError(f"Module '{name}' not found.  "
                           f"Available: {[n for n,_ in self.model.named_modules() if n]}")
        return mods[name]

    # ------------------------------------------------------------------
    def _validate(self, tag, out_c, kH, kW, out_h, out_w, in_w, act_addr):
        """Check hardware constraints and warn / abort."""
        errors = []
        if out_c > HW_MAX_FILTERS:
            errors.append(f"out_channels={out_c} exceeds NO_OF_FILTER max ({HW_MAX_FILTERS})")
        if kH > HW_MAX_KERNEL_W or kW > HW_MAX_KERNEL_W:
            errors.append(f"kernel {kH}×{kW} exceeds MAX_KERNEL_WIDTH ({HW_MAX_KERNEL_W})")
        if out_h > HW_MAX_OUT_WIDTH or out_w > HW_MAX_OUT_WIDTH:
            errors.append(f"output {out_h}×{out_w} exceeds MAX_OUT_WIDTH ({HW_MAX_OUT_WIDTH})")
        if in_w > HW_MAX_FMAP_DIM:
            errors.append(f"input width {in_w} exceeds MAX_FMAP_DIM ({HW_MAX_FMAP_DIM})")
        if act_addr > 16383:
            errors.append(f"activation address {act_addr} exceeds 14-bit max (16383)")
        if errors:
            for e in errors:
                print(f"  [HW-LIMIT] {tag}: {e}", file=sys.stderr)
            raise ValueError(f"Hardware constraint violation in '{tag}'.  See messages above.")

    # ------------------------------------------------------------------
    def compile(self):
        """
        Walk the LAYERS list and produce:
          • self.all_weights_i16   (flat np.ndarray of int16)
          • self.instructions      (list of 64-bit ints)
          • address / shape maps for ground-truth and diagnostics
        """
        cur_h, cur_w, cur_c = self.in_h, self.in_w, self.in_c
        act_ptr = 0          # next free activation BRAM address
        wgt_ptr = 0          # next free weight BRAM address
        weights_list = []    # collects int16 arrays

        # Record input region
        in_words = self._words_for(cur_h, cur_w, cur_c)
        self.stage_shapes.append((cur_h, cur_w, cur_c))
        self.stage_addrs.append(act_ptr)
        self.stage_names.append('input')
        act_ptr += in_words

        last_fc_name = None
        pool_idx = 0               # counter for unique pool naming

        for layer in self.layers:

            # ---- Conv2d → opcode 0x01 --------------------------------
            if layer.op == 'conv':
                mod = self._get_module(layer.param_name)
                assert isinstance(mod, nn.Conv2d),  f"'{layer.param_name}' is not Conv2d"
                assert mod.bias is None,            f"'{layer.param_name}' must have bias=False"
                pad = mod.padding if isinstance(mod.padding, tuple) else (mod.padding, mod.padding)
                assert pad == (0, 0),               f"'{layer.param_name}' must have padding=0"

                kH, kW = (mod.kernel_size if isinstance(mod.kernel_size, tuple)
                          else (mod.kernel_size, mod.kernel_size))
                stride = (mod.stride[0] if isinstance(mod.stride, tuple) else mod.stride)
                out_c  = mod.out_channels
                in_c   = cur_c   # must match mod.in_channels
                out_h  = (cur_h - kH) // stride + 1
                out_w  = (cur_w - kW) // stride + 1

                self._validate(layer.param_name, out_c, kH, kW, out_h, out_w, cur_w, act_ptr)

                # Quantise & store weights  [out_c, in_c, kH, kW]
                w_q = quantize_tensor(mod.weight.data, SCALE).cpu().numpy().astype(np.int16).flatten()
                self.wgt_map[layer.param_name] = (wgt_ptr, len(w_q))
                weights_list.append(w_q)

                # Activation regions
                in_act_addr  = self.stage_addrs[-1]
                out_act_addr = act_ptr
                out_words    = self._words_for(out_h, out_w, out_c)
                self.stage_shapes.append((out_h, out_w, out_c))
                self.stage_addrs.append(out_act_addr)
                self.stage_names.append(f'{layer.param_name}_out')
                act_ptr += out_words

                # Emit 3-word instruction
                flags = 0x2000 if layer.relu else 0
                self.instructions += [
                    pack_word0(0x01, in_act_addr, wgt_ptr, out_act_addr),
                    pack_word1(cur_h, cur_w, in_c, kH, kW, in_c),
                    pack_word2(out_h, out_w, out_c, 0, stride, out_c, flags),
                ]
                wgt_ptr += len(w_q)
                cur_h, cur_w, cur_c = out_h, out_w, out_c

            # ---- MaxPool → opcode 0x02 --------------------------------
            elif layer.op == 'pool':
                ks    = layer.kernel_size
                out_h = cur_h // ks
                out_w = cur_w // ks
                out_c = cur_c

                in_act_addr  = self.stage_addrs[-1]
                out_act_addr = act_ptr
                out_words    = self._words_for(out_h, out_w, out_c)
                self.stage_shapes.append((out_h, out_w, out_c))
                self.stage_addrs.append(out_act_addr)
                self.stage_names.append(f'pool{pool_idx}_{ks}x{ks}_out')
                act_ptr += out_words

                self.instructions += [
                    pack_word0(0x02, in_act_addr, 0, out_act_addr),
                    pack_word1(cur_h, cur_w, cur_c, 0, 0, 0),
                    pack_word2(out_h, out_w, out_c, ks, ks, 0, 0),
                ]
                cur_h, cur_w, cur_c = out_h, out_w, out_c
                pool_idx += 1

            # ---- Flatten (no-op in hardware) --------------------------
            elif layer.op == 'flatten':
                pass      # shape stays (H, W, C) in BRAM; FC uses it as-is

            # ---- Linear → full-kernel conv (opcode 0x01) ---------------
            elif layer.op == 'fc':
                mod = self._get_module(layer.param_name)
                assert isinstance(mod, nn.Linear), f"'{layer.param_name}' is not Linear"
                assert mod.bias is None,           f"'{layer.param_name}' must have bias=False"

                # The FC is a conv whose kernel equals the input spatial dims
                kH, kW, in_c = cur_h, cur_w, cur_c
                out_c  = mod.out_features
                out_h  = 1
                out_w  = 1
                stride = 1

                self._validate(layer.param_name, out_c, kH, kW, out_h, out_w, cur_w, act_ptr)

                # Weight: [out_features, in_features] – already in [f, C*H*W] order
                # which matches conv engine's [f, c, kh, kw] access pattern.
                w_q = quantize_tensor(mod.weight.data, SCALE).cpu().numpy().astype(np.int16).flatten()
                self.wgt_map[layer.param_name] = (wgt_ptr, len(w_q))
                weights_list.append(w_q)

                in_act_addr  = self.stage_addrs[-1]
                out_act_addr = act_ptr
                out_words    = self._words_for(out_h, out_w, out_c)
                self.stage_shapes.append((out_h, out_w, out_c))
                self.stage_addrs.append(out_act_addr)
                self.stage_names.append(f'{layer.param_name}_out')
                act_ptr += out_words

                flags = 0x2000 if layer.relu else 0
                self.instructions += [
                    pack_word0(0x01, in_act_addr, wgt_ptr, out_act_addr),
                    pack_word1(kH, kW, in_c, kH, kW, in_c),
                    pack_word2(out_h, out_w, out_c, 0, stride, out_c, flags),
                ]
                wgt_ptr += len(w_q)
                cur_h, cur_w, cur_c = out_h, out_w, out_c
                last_fc_name = layer.param_name

        # ---- Classifier (argmax) → opcode 0x03 ----------------------
        self.num_classes         = cur_c
        self.classifier_in_addr  = self.stage_addrs[-1]
        self.classifier_out_addr = HW_SEG7_RESULT_ADDR        # single-word result

        self.stage_shapes.append((1, 1, 1))
        self.stage_addrs.append(act_ptr)
        self.stage_names.append('classifier_out')
        act_ptr += 1

        self.instructions += [
            pack_word0(0x03, self.classifier_in_addr, 0, self.classifier_out_addr),
            (self.num_classes & 0x3FF) << 54,      # INPUT_SIZE in dim1 field
            0,
        ]

        # ---- Halt → opcode 0xFF --------------------------------------
        self.instructions += [0xFF << 56, 0, 0]

        # ---- Concatenate all weights ---------------------------------
        self.all_weights_i16 = np.concatenate(weights_list).astype(np.int16)

        print(f"  Compiled {len(self.layers)} layers → "
              f"{len(self.instructions)} instruction words, "
              f"{len(self.all_weights_i16)} weight entries")
        print(f"  Activation BRAM usage : {act_ptr} words")
        print(f"  Weight BRAM usage     : {wgt_ptr} entries")
        return self.instructions, self.all_weights_i16

    # ------------------------------------------------------------------
    #  GROUND TRUTH (fixed-point, matching hardware arithmetic)
    # ------------------------------------------------------------------

    def ground_truth(self, img_q):
        """
        Run the full CNN pipeline in fixed-point to produce a
        hardware-accurate expected output.

        Parameters
        ----------
        img_q : np.ndarray[int16]  –  quantised image, shape (H, W) or (H, W, C)

        Returns
        -------
        predicted_class : int
        fc_logits       : np.ndarray[int16]   (length = num_classes)
        all_acts        : dict[str → np.ndarray]  intermediate activations
        """
        if img_q.ndim == 2:
            img_q = img_q[:, :, np.newaxis]

        cur_act  = img_q.astype(np.int16)
        all_acts = {'input': cur_act.copy()}
        fc_logits = None
        pool_idx = 0

        for layer in self.layers:

            if layer.op == 'conv':
                cur_act = self._gt_conv(cur_act, layer)
                all_acts[f'{layer.param_name}_out'] = cur_act.copy()

            elif layer.op == 'pool':
                cur_act = self._gt_pool(cur_act, layer)
                ks = layer.kernel_size
                all_acts[f'pool{pool_idx}_{ks}x{ks}_out'] = cur_act.copy()
                pool_idx += 1

            elif layer.op == 'flatten':
                pass   # spatial layout unchanged in BRAM

            elif layer.op == 'fc':
                cur_act = self._gt_fc(cur_act, layer)
                all_acts[f'{layer.param_name}_out'] = cur_act.copy()

        # Flatten final activations to 1-D for argmax
        fc_logits = cur_act.flatten().astype(np.int16)
        predicted = int(np.argmax(fc_logits))
        return predicted, fc_logits, all_acts

    # ---- conv ground truth -------------------------------------------
    def _gt_conv(self, inp, layer):
        """Fixed-point conv + optional ReLU, matching ops_convrelu.v."""
        mod = self._get_module(layer.param_name)
        w   = quantize_tensor(mod.weight.data, SCALE).cpu().numpy().astype(np.int16)
        # w shape: [out_c, in_c, kH, kW]

        H, W, C = inp.shape
        out_c, in_c, kH, kW = w.shape
        stride = mod.stride[0] if isinstance(mod.stride, tuple) else mod.stride
        oH = (H - kH) // stride + 1
        oW = (W - kW) // stride + 1

        out = np.zeros((oH, oW, out_c), dtype=np.int16)

        for f in range(out_c):
            for oh in range(oH):
                for ow in range(oW):
                    acc = np.int64(0)
                    for c in range(in_c):
                        for kh in range(kH):
                            for kw in range(kW):
                                a = np.int64(inp[oh * stride + kh, ow * stride + kw, c])
                                wt = np.int64(w[f, c, kh, kw])
                                acc += a * wt
                    # Match hardware: 32-bit wrap → extract bits [25:10]
                    acc_32 = to_s32(acc)
                    trunc  = to_s16(acc_32 >> FRAC_BITS)
                    out[oh, ow, f] = np.int16(max(trunc, 0) if layer.relu else trunc)
        return out

    # ---- max-pool ground truth ----------------------------------------
    def _gt_pool(self, inp, layer):
        """Fixed-point max-pool matching ops_maxpool.v (unsigned compare)."""
        H, W, C = inp.shape
        ks = layer.kernel_size
        oH, oW = H // ks, W // ks
        out = np.zeros((oH, oW, C), dtype=np.int16)

        for c in range(C):
            for oh in range(oH):
                for ow in range(oW):
                    # Hardware uses unsigned 16-bit comparison
                    best = 0
                    for ph in range(ks):
                        for pw in range(ks):
                            v = int(inp[oh * ks + ph, ow * ks + pw, c]) & 0xFFFF
                            if v > best:
                                best = v
                    out[oh, ow, c] = np.int16(to_s16(best))
        return out

    # ---- FC ground truth (as full-kernel conv) -----------------------
    def _gt_fc(self, inp, layer):
        """Fixed-point FC via full-kernel conv, matching hardware."""
        mod = self._get_module(layer.param_name)
        H, W, C = inp.shape
        out_features = mod.out_features

        # Reshape Linear weight [out_features, in_features] → [out_f, C, H, W]
        w_raw = quantize_tensor(mod.weight.data, SCALE).cpu().numpy().astype(np.int16)
        w = w_raw.reshape(out_features, C, H, W)

        out = np.zeros((1, 1, out_features), dtype=np.int16)

        for f in range(out_features):
            acc = np.int64(0)
            for c in range(C):
                for kh in range(H):
                    for kw in range(W):
                        a  = np.int64(inp[kh, kw, c])
                        wt = np.int64(w[f, c, kh, kw])
                        acc += a * wt
            acc_32 = to_s32(acc)
            trunc  = to_s16(acc_32 >> FRAC_BITS)
            out[0, 0, f] = np.int16(max(trunc, 0) if layer.relu else trunc)
        return out


# ==========================================================================
#  MAIN SCRIPT
# ==========================================================================
if __name__ == '__main__':

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"--> Using device: {device}")

    # ==================================================================
    # 1.  DATASET
    # ==================================================================
    transform   = transforms.Compose([transforms.ToTensor()])
    trainset    = torchvision.datasets.MNIST(root='./data', train=True,
                                             download=True, transform=transform)
    testset     = torchvision.datasets.MNIST(root='./data', train=False,
                                             download=True, transform=transform)
    trainloader = torch.utils.data.DataLoader(trainset, batch_size=BATCH_SIZE,
                                              shuffle=True)
    testloader  = torch.utils.data.DataLoader(testset,  batch_size=1000,
                                              shuffle=False)

    # ==================================================================
    # 2.  TRAIN / LOAD
    # ==================================================================
    model     = UserCNN().to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = torch.optim.Adam(model.parameters(), lr=LEARNING_RATE)
    ckpt_path = 'best_model.pth'
    best_acc  = 0.0

    if TRAIN_MODEL:
        print(f"\n--> Training for {NUM_EPOCHS} epochs ...")
        for epoch in range(NUM_EPOCHS):
            model.train()
            for imgs, labels in tqdm(trainloader, desc=f"Epoch {epoch+1}", leave=False):
                imgs, labels = imgs.to(device), labels.to(device)
                optimizer.zero_grad()
                logits = model(imgs)
                if isinstance(logits, tuple):
                    logits = logits[0]
                loss = criterion(logits, labels)
                loss.backward(); optimizer.step()

            model.eval()
            correct = total = 0
            with torch.no_grad():
                for imgs, labels in testloader:
                    imgs, labels = imgs.to(device), labels.to(device)
                    logits = model(imgs)
                    if isinstance(logits, tuple):
                        logits = logits[0]
                    _, pred = torch.max(logits, 1)
                    total   += labels.size(0)
                    correct += (pred == labels).sum().item()
            acc = 100 * correct / total
            print(f"  Epoch {epoch+1}/{NUM_EPOCHS}  Val-Acc {acc:.2f}%")
            if acc > best_acc:
                best_acc = acc
                torch.save(model.state_dict(), ckpt_path)

    model.load_state_dict(torch.load(ckpt_path, map_location=device))
    model.eval()
    print(f"--> Best model loaded  (Val-Acc {best_acc:.2f}%)\n")

    # ==================================================================
    # 3.  COMPILE  →  instructions + weights
    # ==================================================================
    print("--> Compiling model to hardware ...")
    img_tensor, label = testset[TEST_IMAGE_IDX]      # [1, 28, 28]
    IMG_C, IMG_H, IMG_W = img_tensor.shape            # PyTorch: C, H, W

    compiler = HWCompiler(model, LAYERS, input_hwc=(IMG_H, IMG_W, IMG_C))
    instructions, all_weights = compiler.compile()

    # ==================================================================
    # 4.  GENERATE  .coe  FILES  (Vivado IP init)
    # ==================================================================
    print("\n--> Writing .coe files ...")

    with open("bram_weights_init.coe", "w") as f:
        f.write("memory_initialization_radix=16;\nmemory_initialization_vector=\n")
        for i, val in enumerate(all_weights):
            f.write(f"{int(val) & 0xFFFF:04X}")
            f.write(";\n" if i == len(all_weights) - 1 else ",\n")

    with open("bram_instructions_init.coe", "w") as f:
        f.write("memory_initialization_radix=16;\nmemory_initialization_vector=\n")
        for i, inst in enumerate(instructions):
            f.write(f"{inst:016X}")
            f.write(";\n" if i == len(instructions) - 1 else ",\n")

    # ==================================================================
    # 5.  GENERATE  .hex  FILES  ($readmemh for testbench)
    # ==================================================================
    print("--> Writing .hex files ...")

    with open("bram_weights_init.hex", "w") as f:
        for val in all_weights:
            f.write(f"{int(val) & 0xFFFF:04X}\n")

    with open("bram_instructions_init.hex", "w") as f:
        for inst in instructions:
            f.write(f"{inst:016X}\n")

    # ==================================================================
    # 6.  GENERATE UART BYTE STREAM (single-image, backward compat)
    # ==================================================================
    print("--> Building UART byte stream ...")

    img_np = img_tensor.numpy().squeeze()     # [28, 28]
    img_q  = np.round(img_np * SCALE).clip(-32768, 32767).astype(np.int16)

    WORDS_PER_ROW = (IMG_W + 7) // 8

    uart_bytes = build_uart_stream(img_q, IMG_H, IMG_W, IMG_C)

    with open("test_image_uart_bytes.hex", "w") as f:
        for b in uart_bytes:
            f.write(f"{b:02X}\n")

    print(f"    {len(uart_bytes)} bytes  (label = {label})")

    # ==================================================================
    # 7.  FIXED-POINT GROUND TRUTH
    # ==================================================================
    print("--> Computing fixed-point ground truth ...")

    predicted, fc_logits, all_acts = compiler.ground_truth(img_q)

    print(f"    True label             : {label}")
    print(f"    Fixed-point prediction : {predicted}")
    print(f"    FC logits (hex)        : "
          f"{['%04X' % (int(v) & 0xFFFF) for v in fc_logits]}")

    with open("expected_class.hex", "w") as f:
        f.write(f"{predicted:04X}\n")

    # ==================================================================
    # 8.  GROUND-TRUTH SUMMARY (human-readable debug file)
    # ==================================================================
    with open("ground_truth_summary.txt", "w") as f:
        f.write(f"Ground Truth Summary\n{'='*60}\n")
        f.write(f"Test image index : {TEST_IMAGE_IDX}\n")
        f.write(f"True label       : {label}\n")
        f.write(f"Predicted class  : {predicted}\n")
        f.write(f"Best Val Acc     : {best_acc:.2f}%\n\n")

        # ---- Address map ----
        f.write("--- Activation BRAM Address Map ---\n")
        for name, addr, shape in zip(compiler.stage_names,
                                     compiler.stage_addrs,
                                     compiler.stage_shapes):
            words = compiler._words_for(*shape)
            f.write(f"  {name:25s}  addr {addr:5d}  shape {shape}  "
                    f"({words} words)\n")
        f.write(f"\n--- Weight BRAM Address Map ---\n")
        for name, (offset, count) in compiler.wgt_map.items():
            f.write(f"  {name:25s}  offset {offset:5d}  count {count}\n")

        # ---- Instructions ----
        f.write(f"\n--- Instructions ({len(instructions)} words) ---\n")
        for i, inst in enumerate(instructions):
            f.write(f"  [{i:3d}] 0x{inst:016X}\n")

        # ---- FC logits ----
        f.write(f"\n--- FC Logits (Q5.{FRAC_BITS}) ---\n")
        for i, v in enumerate(fc_logits):
            f.write(f"  class {i}: 0x{int(v) & 0xFFFF:04X}  ({int(v):+7d})\n")

        # ---- Intermediate activations (first 4×4 corner of first channel) ----
        for name, act in all_acts.items():
            if name == 'input':
                continue
            H, W, C = act.shape
            f.write(f"\n--- {name}  shape={act.shape} ---\n")
            rows = min(4, H)
            cols = min(4, W)
            for r in range(rows):
                vals = [f"{int(act[r, c, 0]) & 0xFFFF:04X}" for c in range(cols)]
                f.write("  " + "  ".join(vals) + "\n")
            if H > 4 or W > 4:
                f.write("  ...\n")

        # ---- UART stats ----
        f.write(f"\n--- UART Byte-Stream ---\n")
        f.write(f"  Total bytes : {len(uart_bytes)}\n")
        f.write(f"  Header      : H={IMG_H} W={IMG_W} C={IMG_C}\n")
        f.write(f"  Pixel words : {WORDS_PER_ROW * IMG_H * IMG_C}\n")

        # ---- First 10 weight values for spot-check ----
        f.write(f"\n--- Weight BRAM Spot-Check (first 10) ---\n")
        for i in range(min(10, len(all_weights))):
            f.write(f"  addr {i:4d}: 0x{int(all_weights[i]) & 0xFFFF:04X}\n")

    # ==================================================================
    # 9.  MULTI-IMAGE TEST SET (balanced across all 10 digits)
    # ==================================================================
    if NUM_TEST_IMAGES > 0:
        print(f"\n--> Generating multi-image test set ({NUM_TEST_IMAGES} images) ...")
        os.makedirs('test_images_uart', exist_ok=True)

        # ---- 9a. Select balanced images from test set ----
        per_digit = NUM_TEST_IMAGES // 10
        remainder = NUM_TEST_IMAGES % 10
        selected_indices = []

        # Build an index of test-set positions for each digit
        digit_indices = {d: [] for d in range(10)}
        for idx in range(len(testset)):
            _, lbl = testset[idx]
            digit_indices[lbl].append(idx)

        for digit in range(10):
            need = per_digit + (1 if digit < remainder else 0)
            chosen = digit_indices[digit][:need]
            if len(chosen) < need:
                print(f"  [WARN] Only {len(chosen)} images for digit {digit} "
                      f"(requested {need})")
            selected_indices.extend(chosen)

        # Sort by digit then by dataset index for deterministic ordering
        # (they're already grouped by digit from the loop above)
        actual_count = len(selected_indices)
        print(f"    Selected {actual_count} images "
              f"({per_digit}+ per digit, {10} digits)")

        # ---- 9b. Generate UART streams & ground truth for each ----
        all_uart_flat     = bytearray()
        expected_classes  = []           # fixed-point model prediction
        true_labels       = []           # MNIST ground truth
        bytes_per_image   = len(uart_bytes)   # all MNIST images have same size

        for sel_i, ds_idx in enumerate(selected_indices):
            img_t, lbl = testset[ds_idx]
            img_np_i = img_t.numpy().squeeze()
            img_q_i  = np.round(img_np_i * SCALE).clip(-32768, 32767).astype(np.int16)

            # Ground truth through the compiled pipeline
            pred_i, _, _ = compiler.ground_truth(img_q_i)

            # UART byte stream
            uart_i = build_uart_stream(img_q_i, IMG_H, IMG_W, IMG_C)
            assert len(uart_i) == bytes_per_image, \
                f"Image {sel_i} UART length {len(uart_i)} != {bytes_per_image}"

            all_uart_flat.extend(uart_i)
            expected_classes.append(pred_i)
            true_labels.append(lbl)

            if (sel_i + 1) % 10 == 0 or sel_i == actual_count - 1:
                print(f"    [{sel_i+1:3d}/{actual_count}] processed")

        # ---- 9c. Write test_images_uart/ files ----

        # Flat UART byte array (all images concatenated)
        with open("test_images_uart/all_uart_bytes.hex", "w") as f:
            for b in all_uart_flat:
                f.write(f"{b:02X}\n")

        # Expected classes (one 16-bit hex per line)
        with open("test_images_uart/expected_classes.hex", "w") as f:
            for c in expected_classes:
                f.write(f"{c:04X}\n")

        # True MNIST labels
        with open("test_images_uart/true_labels.hex", "w") as f:
            for l in true_labels:
                f.write(f"{l:04X}\n")

        # Configuration file for testbench
        # Line 0 : num_test_images
        # Line 1 : bytes_per_image
        # Line 2 : fc_out_base_addr (for logit dump)
        # Line 3 : num_classes
        fc_base = compiler.classifier_in_addr
        n_cls   = compiler.num_classes
        with open("test_images_uart/test_config.hex", "w") as f:
            f.write(f"{actual_count:08X}\n")
            f.write(f"{bytes_per_image:08X}\n")
            f.write(f"{fc_base:08X}\n")
            f.write(f"{n_cls:08X}\n")

        # Human-readable manifest
        with open("test_images_uart/manifest.txt", "w") as f:
            f.write(f"Multi-Image Test Manifest\n{'='*60}\n")
            f.write(f"Total images     : {actual_count}\n")
            f.write(f"Bytes per image  : {bytes_per_image}\n")
            f.write(f"FC output base   : {fc_base}\n")
            f.write(f"Num classes      : {n_cls}\n\n")
            f.write(f"{'Idx':>4s}  {'DS#':>5s}  {'Label':>5s}  {'FP_Pred':>7s}\n")
            f.write(f"{'-'*4}  {'-'*5}  {'-'*5}  {'-'*7}\n")
            for i, (ds_idx, lbl, pred) in enumerate(
                    zip(selected_indices, true_labels, expected_classes)):
                match = 'OK' if lbl == pred else 'NOT OK'
                f.write(f"{i:4d}  {ds_idx:5d}  {lbl:5d}  {pred:7d}  {match}\n")
            fp_correct = sum(1 for l, p in zip(true_labels, expected_classes) if l == p)
            f.write(f"\nFP-model accuracy: {fp_correct}/{actual_count} "
                    f"({100*fp_correct/max(actual_count,1):.1f}%)\n")

        print(f"    Wrote {actual_count} images to test_images_uart/")
        print(f"    FP-model accuracy on test set: "
              f"{sum(1 for l,p in zip(true_labels, expected_classes) if l==p)}"
              f"/{actual_count}")

    # ==================================================================
    # 10.  LEGACY: model_weights.txt (human-readable)
    # ==================================================================
    with open("model_weights.txt", "w") as f:
        f.write(f"# Best_Model_Weights_INT16  Val-Acc {best_acc:.2f}%  Q5.{FRAC_BITS}\n\n")
        offset = 0
        for name, (bram_off, count) in compiler.wgt_map.items():
            mod = compiler._get_module(name)
            if isinstance(mod, nn.Conv2d):
                shape = list(mod.weight.shape)
            else:
                shape = list(mod.weight.shape)
            f.write(f"# Layer: {name}  {shape}\n")
            chunk = all_weights[offset:offset + count]
            for i, val in enumerate(chunk):
                f.write(f"{int(val) & 0xFFFF:04X}")
                f.write("\n" if (i + 1) % 24 == 0 else " ")
            f.write("\n\n")
            offset += count

    # ==================================================================
    print(f"\n{'='*60}")
    print("--> ALL FILES GENERATED SUCCESSFULLY")
    print(f"{'='*60}")
    print("  Vivado   : bram_weights_init.coe, bram_instructions_init.coe")
    print("  Sim      : bram_weights_init.hex, bram_instructions_init.hex")
    print("             test_image_uart_bytes.hex, expected_class.hex")
    if NUM_TEST_IMAGES > 0:
        print(f"  Multi-img: test_images_uart/  ({NUM_TEST_IMAGES} images)")
        print("             all_uart_bytes.hex, expected_classes.hex,")
        print("             true_labels.hex, test_config.hex, manifest.txt")
    print("  Debug    : ground_truth_summary.txt, model_weights.txt")
    print(f"{'='*60}")