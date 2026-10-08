# DSD_MNIST_Systolic: Real-Time FPGA CNN Hardware Accelerator for MNIST Handwritten Digit Recognition

[![Verilog HDL](https://img.shields.io/badge/Language-Verilog_HDL-blue.svg)](https://en.wikipedia.org/wiki/Verilog)
[![FPGA Target](https://img.shields.io/badge/Target-Xilinx_Nexys_Video_Artix--7_XC7A200T-red.svg)](https://www.xilinx.com)
[![Accuracy](https://img.shields.io/badge/MNIST_Accuracy->98%25-brightgreen.svg)]()
[![Inference Latency](https://img.shields.io/badge/Inference_Latency-<10_ms-yellow.svg)]()
[![Course](https://img.shields.io/badge/Course-E3_231_Digital_Systems_Design_with_FPGAs-purple.svg)](https://iisc.ac.in)

**Authors:**  
- **Prayanshu Sharma** (SR: 27451)  
- **Vedant Saxena** (SR: 26110)  
- **Anirudh Chaturvedi** (SR: 25850)  

Department of Electronic Systems Engineering (DESE), **Indian Institute of Science (IISc), Bangalore**  
Course: **E3-231: Digital System Design with FPGAs, 2026**

---

## 1. Executive Summary

This repository contains the complete hardware design, Python training & quantization pipeline, interactive GUI host software, and physical FPGA implementation of a standalone, fully hardware-accelerated **Convolutional Neural Network (CNN) inference engine** targeting the **AMD Xilinx Nexys Video Artix-7 FPGA (`XC7A200T-1SBG484C`)**.

The system receives raw $28 	imes 28$ grayscale handwritten digit images over high-speed UART (2 Mbaud / configurable) from a Python host application, executes end-to-end forward inference entirely in FPGA hardware without CPU runtime involvement, and presents the recognized 4-bit digit on discrete board LEDs and multiplexed 7-segment displays.

---

## 2. Microarchitectural Innovations

### A. Row-Stationary Compute Dataflow with Line Buffers
Conventional CNN implementations require memory-intensive `im2col` tensor expansion, creating prohibitive memory bandwidth bottlenecks. We architected a hardware **Row-Stationary dataflow utilizing on-chip line buffers** that store incoming pixel rows and stream local $3 	imes 3$ sliding receptive fields directly into the PE array, completely eliminating `im2col` expansion overhead.

### B. Massive 120-PE Parallel Multiply-Accumulate Array
- Spatial unrolling of **120 Processing Elements (PE rows)** operating concurrently.
- 128-bit dual-port Activation BRAM streaming **8 Q1.5.10 quantized pixels per clock cycle**.
- **614 DSP48 slices** mapped for single-cycle fixed-point MAC computations.

### C. Module-Level Synchronous Clock Gating (`BUFGCE`)
Integrated synchronous `BUFGCE` clock gates across each pipeline module (`ops_convrelu`, `ops_maxpool`, `ops_classifier`). Each module clock is gated low when inactive, reducing total on-chip dynamic power to **1.483 W**.

---

## 3. Physical Implementation & PPA Metrics

Post-route implementation results on **Xilinx Artix-7 XC7A200T-1SBG484C**:

| Metric | Target / Specification | Achieved Post-Route Sign-Off |
| :--- | :---: | :---: |
| **Clock Frequency** | 70 MHz ($T_{clk} = 14.28	ext{ ns}$) | **70.0 MHz Closed Timing** |
| **Worst Negative Slack (WNS)** | $> 0.0	ext{ ns}$ | **+0.092 ns (Timing Met)** |
| **Worst Hold Slack (WHS)** | $> 0.0	ext{ ns}$ | **+0.026 ns (Hold Met)** |
| **Pulse Width Slack** | $> 0.0	ext{ ns}$ | **+3.000 ns (Met)** |
| **Total On-Chip Power** | $< 2.0	ext{ W}$ | **1.483 W (Dynamic: 1.345 W, Static: 0.138 W)** |
| **DSP48 Utilization** | 740 available | **614 / 740 (83.0%)** |
| **Slice LUT Utilization** | 133,800 available | **65,710 / 133,800 (49.1%)** |
| **Flip-Flop Utilization** | 267,600 available | **71,277 / 267,600 (26.6%)** |
| **Block RAM (BRAM 36Kb)**| 365 available | **39 / 365 (10.7%)** |
| **Test Accuracy (MNIST)** | $> 98\%$ | **> 98.2%** |
| **End-to-End Latency** | $< 10	ext{ ms}$ | **~28,822 clock cycles (< 0.45 ms compute)** |

---

## 4. Repository Structure

```
.
├── CNN_development/               # Model training, Q1.5.10 quantization & COE generators
│   ├── CNN_for_MNIST.ipynb        # Jupyter notebook for CNN exploration
│   └── modelTtraining_memInitFilesGen_testVectorsGen/
│       ├── train_and_gen_model_init_files_V5.py
│       ├── best_model.pth         # PyTorch trained model weights
│       ├── bram_weights_init.coe  # Quantized weights for Vivado BRAM
│       ├── bram_instructions_init.coe
│       └── test_images_uart/      # UART hex verification image vectors
├── GUI/                           # Interactive Python GUI for live digit drawing & UART streaming
│   └── main.py
├── ip/                            # Xilinx Vivado IP configuration cores
│   ├── bram_activations.xci
│   ├── bram_instructions.xci
│   └── bram_weights.xci
├── scripts/                       # TCL automation scripts for Vivado project creation & build
│   └── DSD_CNN_MNIST.tcl
├── src/                           # Synthesizable Verilog HDL design & testbenches
│   ├── bram_init/                 # Activation, weight, and instruction COE files
│   ├── constraints/               # Pinout and physical timing constraints (XDC)
│   ├── design/                    # Verilog RTL modules (top, convrelu, maxpool, classifier, etc.)
│   └── testbenches/               # Complete multi-level testbench suite (10 testbenches)
└── docs/                          # Architectural documentation, monographs & reports
    ├── Hardware_Accelerator_MNIST_Project.pdf # Complete technical monograph report
    ├── Guide_5_CNN_FPGA_Hardware_Accelerator.pdf # Technical defense interview guide
    ├── Block_diagram.png
    └── Block_diagrams.pptx
```

---

## 5. Quickstart & Hardware Replication

### 1. Vivado Project Generation via TCL
Launch AMD Xilinx Vivado (2022.2 or later) and run the automated build script:
```bash
vivado -mode batch -source scripts/DSD_CNN_MNIST.tcl
```

### 2. Launching Interactive Host GUI
Connect the Nexys Video board via micro-USB and run the interactive drawing GUI:
```bash
cd GUI
python main.py
```
Draw digits on the canvas and stream them over UART directly to the FPGA inference core!
