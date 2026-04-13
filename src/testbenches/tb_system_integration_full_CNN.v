`timescale 1ns / 1ps

module tb_system_integration_full_CNN();

    // Clock and Reset
    reg CLK;
    reg RST;

    // Controller Start Signal
    reg START_CONTROLLER;

    // ---------------------------------------------------------
    // CONTROLLER -> BRAM INSTRUCTIONS INTERFACE
    // ---------------------------------------------------------
    wire ctrl_inst_ena;
    wire ctrl_inst_wea;
    wire [9:0]  ctrl_inst_addra;
    wire [63:0] ctrl_inst_dina;
    wire [63:0] inst_douta;

    // ---------------------------------------------------------
    // CONTROLLER -> MODULES INTERFACE
    // ---------------------------------------------------------
    wire en_conv, en_maxp, en_class;
    wire sop_conv, sop_maxp, sop_class;
    wire eop_conv, eop_maxp, eop_class;
    wire halt;

    // Decoded Parameter Wires
    wire [13:0] inp_act_addr, inp_wgt_addr, out_act_addr;
    wire [9:0]  inp_act_dim1, inp_act_dim2, inp_act_dim3;
    wire [9:0]  wgt_dim1, wgt_dim2, wgt_dim3;
    wire [9:0]  out_act_dim1, out_act_dim2, out_act_dim3;
    wire [7:0]  pool_dim, conv_stride;
    wire [3:0]  no_of_filter;

    // ---------------------------------------------------------
    // CONVRELU -> BRAM ACTIVATIONS INTERFACE
    // ---------------------------------------------------------
    wire conv_act_ena, conv_act_wea, conv_act_enb;
    wire [13:0] conv_act_addra, conv_act_addrb;
    wire [127:0] conv_act_dina;

    // ---------------------------------------------------------
    // MAXPOOL -> BRAM ACTIVATIONS INTERFACE
    // ---------------------------------------------------------
    wire mp_bram_ena, mp_bram_wea, mp_bram_enb;
    wire [13:0] mp_bram_addra, mp_bram_addrb;
    wire [127:0] mp_bram_dina;

    // ---------------------------------------------------------
    // CLASSIFIER -> BRAM ACTIVATIONS INTERFACE
    // ---------------------------------------------------------
    wire cls_bram_ena, cls_bram_wea, cls_bram_enb;
    wire [13:0] cls_bram_addra, cls_bram_addrb;
    wire [127:0] cls_bram_dina;

    // ---------------------------------------------------------
    // WEIGHTS BRAM INTERFACE (CONV ONLY)
    // ---------------------------------------------------------
    wire conv_wgt_ena, conv_wgt_wea;
    wire [13:0] conv_wgt_addra;
    wire [15:0] conv_wgt_dina, wgt_douta;
    wire [127:0] act_doutb;

    // ---------------------------------------------------------
    // TESTBENCH BRAM CONTROL (Multiplexers)
    // ---------------------------------------------------------
    reg tb_active; // 1 = TB writes to BRAMs, 0 = Controller runs

    // TB registers for Instruction BRAM
    reg tb_inst_ena, tb_inst_wea;
    reg [9:0] tb_inst_addra;
    reg [63:0] tb_inst_dina;

    // TB registers for Activations BRAM (128-BIT)
    reg tb_act_ena, tb_act_wea, tb_act_enb;
    reg [13:0] tb_act_addra, tb_act_addrb;
    reg [127:0] tb_act_dina;

    // TB registers for Weights BRAM (16-BIT)
    reg tb_wgt_ena, tb_wgt_wea;
    reg [13:0] tb_wgt_addra;
    reg [15:0] tb_wgt_dina;

    // Instruction BRAM Mux
    wire inst_ena         = tb_active ? tb_inst_ena   : ctrl_inst_ena;
    wire inst_wea         = tb_active ? tb_inst_wea   : ctrl_inst_wea;
    wire [9:0] inst_addra = tb_active ? tb_inst_addra : ctrl_inst_addra;
    wire [63:0] inst_dina = tb_active ? tb_inst_dina  : ctrl_inst_dina;

    // Activations BRAM Mux (Tri-state between TB, CONV, MAXPOOL, and CLASSIFIER)
    wire act_ena          = tb_active ? tb_act_ena   : (en_conv ? conv_act_ena   : (en_maxp ? mp_bram_ena   : cls_bram_ena));
    wire act_wea          = tb_active ? tb_act_wea   : (en_conv ? conv_act_wea   : (en_maxp ? mp_bram_wea   : cls_bram_wea));
    wire [13:0] act_addra = tb_active ? tb_act_addra : (en_conv ? conv_act_addra : (en_maxp ? mp_bram_addra : cls_bram_addra));
    wire [127:0] act_dina = tb_active ? tb_act_dina  : (en_conv ? conv_act_dina  : (en_maxp ? mp_bram_dina  : cls_bram_dina));
    wire act_enb          = tb_active ? tb_act_enb   : (en_conv ? conv_act_enb   : (en_maxp ? mp_bram_enb   : cls_bram_enb));
    wire [13:0] act_addrb = tb_active ? tb_act_addrb : (en_conv ? conv_act_addrb : (en_maxp ? mp_bram_addrb : cls_bram_addrb));

    // Weights BRAM Mux
    wire wgt_ena          = tb_active ? tb_wgt_ena   : conv_wgt_ena;
    wire wgt_wea          = tb_active ? tb_wgt_wea   : conv_wgt_wea;
    wire [13:0] wgt_addra = tb_active ? tb_wgt_addra : conv_wgt_addra;
    wire [15:0] wgt_dina  = tb_active ? tb_wgt_dina  : conv_wgt_dina;

    // ---------------------------------------------------------
    // TEST PARAMETERS & MEMORY MAP
    // ---------------------------------------------------------
    //
    // CNN TARGET:
    // Layer 1: Conv2d(1, 6, kernel=5) + ReLU -> Input: 28x28x1, Output: 24x24x6
    // Layer 2: MaxPool2d(kernel=2, stride=2) -> Input: 24x24x6, Output: 12x12x6
    // Layer 3: Linear(864, 10) -> Input: 12x12x6, Output 1x1x10
    // Layer 4: Argmax(10) -> Input: 1x1x10, Output 1 class index
    //
    localparam IN_BASE = 14'd0;
    localparam WGT_BASE = 14'd0;
    localparam CONV_OUT_BASE = 14'd112;
    localparam POOL_OUT_BASE = 14'd544;
    localparam FC_WGT_BASE = 14'd150;
    localparam FC_OUT_BASE = 14'd688;
    localparam FINAL_CLASS_BASE = 14'd800; // Memory loc for predicted class

    // ---------------------------------------------------------
    // INSTANTIATIONS
    // ---------------------------------------------------------

    controller uut_controller (
        .CLK(CLK), .RST(RST), .START_CONTROLLER(START_CONTROLLER),
        .ENA(ctrl_inst_ena), .WEA(ctrl_inst_wea), .ADDRA(ctrl_inst_addra), .DINA(ctrl_inst_dina), .DOUTA(inst_douta),
        .EN_CONV(en_conv), .EN_MAXP(en_maxp), .EN_CLASS(en_class),
        .SOP_CONV(sop_conv), .SOP_MAXP(sop_maxp), .SOP_CLASS(sop_class),
        .EOP_CONV(eop_conv), .EOP_MAXP(eop_maxp), .EOP_CLASS(eop_class),
        .INP_ACT_ADDR(inp_act_addr), .INP_WGT_ADDR(inp_wgt_addr), .OUT_ACT_ADDR(out_act_addr),
        .INP_ACT_DIM1(inp_act_dim1), .INP_ACT_DIM2(inp_act_dim2), .INP_ACT_DIM3(inp_act_dim3),
        .WGT_DIM1(wgt_dim1), .WGT_DIM2(wgt_dim2), .WGT_DIM3(wgt_dim3),
        .OUT_ACT_DIM1(out_act_dim1), .OUT_ACT_DIM2(out_act_dim2), .OUT_ACT_DIM3(out_act_dim3),
        .POOL_DIM(pool_dim), .CONV_STRIDE(conv_stride), .NO_OF_FILTER(no_of_filter), .halt(halt)
    );

    bram_instructions_wrapper uut_bram_inst (
        .CLK(CLK), .ENA(inst_ena), .WEA(inst_wea), .ADDRA(inst_addra), .DINA(inst_dina), .DOUTA(inst_douta)
    );

    ops_convrelu #(
        .MAX_FMAP_DIM(32), .MAX_KERNEL_WIDTH(12), .MAX_OUT_HEIGHT(24) 
    ) uut_convrelu (
        .CLK_IN(CLK), .RESET(RST), .MODULE_EN(en_conv),
        .EXT_START_OF_COMPUTE(sop_conv), .EXT_END_OF_COMPUTE(eop_conv),
        .IN_FMAP_BASEADDR(inp_act_addr), .IN_FMAP_DIM_H(inp_act_dim1), .IN_FMAP_DIM_W(inp_act_dim2), .IN_FMAP_DIM_C(inp_act_dim3),
        .WEIGHT_BASEADDR(inp_wgt_addr), .WEIGHT_DIM_H(wgt_dim1), .WEIGHT_DIM_W(wgt_dim2), .WEIGHT_DIM_C(wgt_dim3), .NUM_FILTERS(no_of_filter),
        .OUT_FMAP_BASEADDR(out_act_addr), .OUT_FMAP_DIM_H(out_act_dim1), .OUT_FMAP_DIM_W(out_act_dim2), .OUT_FMAP_DIM_C(out_act_dim3),
        .STRIDE(conv_stride),
        .BRAM_act_ENA(conv_act_ena), .BRAM_act_WEA(conv_act_wea), .BRAM_act_ADDRA(conv_act_addra), .BRAM_act_DINA(conv_act_dina),
        .BRAM_act_ENB(conv_act_enb), .BRAM_act_ADDRB(conv_act_addrb), .BRAM_act_DOUTB(act_doutb),
        .BRAM_wgt_ENA(conv_wgt_ena), .BRAM_wgt_WEA(conv_wgt_wea), .BRAM_wgt_ADDRA(conv_wgt_addra), .BRAM_wgt_DINA(conv_wgt_dina), .BRAM_wgt_DOUTA(wgt_douta)
    );

    ops_maxpool uut_maxpool (
        .CLK_IN(CLK), .RESET(RST), .MODULE_EN(en_maxp),
        .EXT_START_OF_COMPUTE(sop_maxp), .EXT_END_OF_COMPUTE(eop_maxp),
        .IN_FMAP_BASEADDR(inp_act_addr), .IN_FMAP_DIM_H(inp_act_dim1), .IN_FMAP_DIM_W(inp_act_dim2), .IN_FMAP_DIM_C(inp_act_dim3),
        .OUT_FMAP_BASEADDR(out_act_addr), .OUT_FMAP_DIM_H(out_act_dim1), .OUT_FMAP_DIM_W(out_act_dim2), .OUT_FMAP_DIM_C(out_act_dim3),
        .POOL_KERNEL_SIZE(pool_dim),
        .BRAM_ena(mp_bram_ena), .BRAM_wea(mp_bram_wea), .BRAM_addra(mp_bram_addra), .BRAM_dina(mp_bram_dina),
        .BRAM_enb(mp_bram_enb), .BRAM_addrb(mp_bram_addrb), .BRAM_doutb(act_doutb)
    );

    ops_classifier uut_classifier (
        .CLK_IN(CLK), .RESET(RST), .MODULE_EN(en_class),
        .EXT_START_OF_COMPUTE(sop_class), .EXT_END_OF_COMPUTE(eop_class),
        .INPUT_BASE_ADDR(inp_act_addr), .INPUT_SIZE(inp_act_dim1), .OUT_ACT_ADDR(out_act_addr),
        .BRAM_act_ENA(cls_bram_ena), .BRAM_act_WEA(cls_bram_wea), .BRAM_act_ADDRA(cls_bram_addra), .BRAM_act_DINA(cls_bram_dina),
        .BRAM_act_ENB(cls_bram_enb), .BRAM_act_ADDRB(cls_bram_addrb), .BRAM_act_DOUTB(act_doutb)
    );

    bram_activations_wrapper uut_bram_act (
        .CLK(CLK), .ena(act_ena), .wea(act_wea), .addra(act_addra), .dina(act_dina), .enb(act_enb), .addrb(act_addrb), .doutb(act_doutb)
    );

    bram_weights_wrapper uut_bram_wgt (
        .CLK(CLK), .ENA(wgt_ena), .WEA(wgt_wea), .ADDRA(wgt_addra), .DINA(wgt_dina), .DOUTA(wgt_douta)
    );

    // ---------------------------------------------------------
    // CLOCK GENERATION
    // ---------------------------------------------------------
    initial begin
        CLK = 0;
        forever #5 CLK = ~CLK;
    end

    // ---------------------------------------------------------
    // TEST SEQUENCE
    // ---------------------------------------------------------
    integer f, c_idx, h, w, k, kh_i, kw_i;
    integer addr;
    integer val, max_val;
    integer expected_val;
    integer write_errors, wgt_errors, conv_errors;
    
    integer expected_class;
    integer max_logit;
    
    reg signed [31:0] psum;
    reg [15:0] expected;

    // Flattened reference arrays
    reg [15:0] test_image [0:783];      // 28x28x1
    reg [15:0] test_kernel [0:149];     // 5x5x1 * 6 Filters
    reg [15:0] conv_out [0:3455];       // 24x24x6 Output
    reg [15:0] pool_out [0:863];        // 12x12x6 Output
    reg [15:0] test_fc_kernel[0:8639];  // 12x12x6 * 10 Filters
    reg [15:0] fc_out [0:9];            // 1x1x10 Output

    initial begin
        $display("==================================================");
        $display("   STARTING FULL CNN SYSTEM INTEGRATION TEST      ");
        $display("==================================================");
        $display("   Target: PyTorch SimpleRTLCNN Architecture");
        $display("   Conv1: 28x28x1 -> 24x24x6 (Kernel 5x5)");
        $display("   MaxPool: 24x24x6 -> 12x12x6 (Pool 2x2)");
        $display("   FC: 12x12x6 -> 1x1x10 (Configured as Conv2D)");
        $display("   Argmax: 1x1x10 -> Predicted Class");
        $display("==================================================");

        // Initialize Data & Expected Values
        for (h = 0; h < 28; h = h + 1)
            for (w = 0; w < 28; w = w + 1)
                test_image[h*28 + w] = ((h + w) % 10) << 10; 

        for (f = 0; f < 6; f = f + 1)
            for (kh_i = 0; kh_i < 5; kh_i = kh_i + 1)
                for (kw_i = 0; kw_i < 5; kw_i = kw_i + 1)
                    test_kernel[f*25 + kh_i*5 + kw_i] = 16'd102; 

        for (f = 0; f < 10; f = f + 1)
            for (c_idx = 0; c_idx < 6; c_idx = c_idx + 1)
                for (h = 0; h < 12; h = h + 1)
                    for (w = 0; w < 12; w = w + 1)
                        test_fc_kernel[f*864 + c_idx*144 + h*12 + w] = 16'd51; // 0.05 in Q1.5.10

        // Simulate Conv1+ReLU behavior
        for (f = 0; f < 6; f = f + 1) begin
            for(h = 0; h < 24; h = h + 1) begin
                for(w = 0; w < 24; w = w + 1) begin
                    psum = 0;
                    for(kh_i = 0; kh_i < 5; kh_i = kh_i + 1) begin
                        for(kw_i = 0; kw_i < 5; kw_i = kw_i + 1) begin
                            psum = psum + ($signed(test_image[(h+kh_i)*28 + (w+kw_i)]) * $signed(test_kernel[f*25 + kh_i*5 + kw_i]));
                        end
                    end
                    psum = psum >>> 10;
                    expected = (psum < 0) ? 16'd0 : psum[15:0];
                    conv_out[f*576 + h*24 + w] = expected;
                end
            end
        end

        // Simulate MaxPool behavior
        for(f = 0; f < 6; f = f + 1) begin
            for(h = 0; h < 12; h = h + 1) begin
                for(w = 0; w < 12; w = w + 1) begin
                    max_val = 0;
                    for(kh_i = 0; kh_i < 2; kh_i = kh_i + 1) begin
                        for(kw_i = 0; kw_i < 2; kw_i = kw_i + 1) begin
                            val = conv_out[f*576 + (h*2+kh_i)*24 + (w*2+kw_i)];
                            if (val > max_val) max_val = val;
                        end
                    end
                    pool_out[f*144 + h*12 + w] = max_val[15:0];
                end
            end
        end

        // Simulate FC (Conv2D mapping) + clamped hardware ReLU
        for(f = 0; f < 10; f = f + 1) begin
            psum = 0;
            for(c_idx = 0; c_idx < 6; c_idx = c_idx + 1) begin
                for(h = 0; h < 12; h = h + 1) begin
                    for(w = 0; w < 12; w = w + 1) begin
                        psum = psum + ($signed(pool_out[c_idx*144 + h*12 + w]) * $signed(test_fc_kernel[f*864 + c_idx*144 + h*12 + w]));
                    end
                end
            end
            psum = psum >>> 10;
            fc_out[f] = (psum < 0) ? 16'd0 : psum[15:0];
        end

        // Simulate ArgMax
        max_logit = -32768; // Min signed 16-bit
        expected_class = 0;
        for (f = 0; f < 10; f = f + 1) begin
            if ($signed(fc_out[f]) > max_logit) begin
                max_logit = $signed(fc_out[f]);
                expected_class = f;
            end
        end

        // Initialize Environment
        RST = 1; START_CONTROLLER = 0; tb_active = 1;
        tb_inst_ena = 0; tb_inst_wea = 0; tb_inst_addra = 0; tb_inst_dina = 0;
        tb_act_ena = 0; tb_act_wea = 0; tb_act_enb = 0; tb_act_addra = 0; tb_act_addrb = 0; tb_act_dina = 0;
        tb_wgt_ena = 0; tb_wgt_wea = 0; tb_wgt_addra = 0; tb_wgt_dina = 0;

        write_errors = 0; wgt_errors = 0; conv_errors = 0;

        #100; @(posedge CLK); RST = 0; #20;

        // ---------------------------------------------------------
        // PHASE 1: LOAD INSTRUCTIONS
        // ---------------------------------------------------------
        $display("\n[PHASE 1] Loading Instructions into Controller BRAM...");

        // Instruction 1: Conv1+ReLU (Opcode 0x01)
        @(posedge CLK); tb_inst_ena = 1; tb_inst_wea = 1; tb_inst_addra = 0;
        tb_inst_dina = {8'h01, IN_BASE, WGT_BASE, CONV_OUT_BASE, 14'd0};
        @(posedge CLK); tb_inst_addra = 1;
        tb_inst_dina = {10'd28, 10'd28, 10'd1, 10'd5, 10'd5, 10'd1, 4'd0};
        @(posedge CLK); tb_inst_addra = 2;
        tb_inst_dina = {10'd24, 10'd24, 10'd6, 8'd0, 8'd1, 4'd6, 14'd0}; 

        // Instruction 2: MaxPool (Opcode 0x02)
        @(posedge CLK); tb_inst_addra = 3;
        tb_inst_dina = {8'h02, CONV_OUT_BASE, 14'd0, POOL_OUT_BASE, 14'd0};
        @(posedge CLK); tb_inst_addra = 4;
        tb_inst_dina = {10'd24, 10'd24, 10'd6, 10'd0, 10'd0, 10'd0, 4'd0};
        @(posedge CLK); tb_inst_addra = 5;
        tb_inst_dina = {10'd12, 10'd12, 10'd6, 8'd2, 8'd2, 4'd0, 14'd0}; 

        // Instruction 3: FC Layer via Conv2D (Opcode 0x01)
        @(posedge CLK); tb_inst_addra = 6;
        tb_inst_dina = {8'h01, POOL_OUT_BASE, FC_WGT_BASE, FC_OUT_BASE, 14'd0};
        @(posedge CLK); tb_inst_addra = 7;
        tb_inst_dina = {10'd12, 10'd12, 10'd6, 10'd12, 10'd12, 10'd6, 4'd0};
        @(posedge CLK); tb_inst_addra = 8;
        tb_inst_dina = {10'd1, 10'd1, 10'd10, 8'd0, 8'd1, 4'd10, 14'd0}; 

        // Instruction 4: ArgMax Classifier (Opcode 0x03)
        // Only needs Input Addr (FC_OUT_BASE), Output Addr (FINAL_CLASS_BASE), and Input Size (10)
        @(posedge CLK); tb_inst_addra = 9;
        tb_inst_dina = {8'h03, FC_OUT_BASE, 14'd0, FINAL_CLASS_BASE, 14'd0};
        @(posedge CLK); tb_inst_addra = 10;
        tb_inst_dina = {10'd10, 54'd0}; 
        @(posedge CLK); tb_inst_addra = 11;
        tb_inst_dina = 64'd0; // Padding to maintain 3-word instruction stride

        // Instruction 5: HALT (Opcode 0xFF)
        @(posedge CLK); tb_inst_addra = 12; tb_inst_dina = {8'hFF, 56'd0};
        @(posedge CLK); tb_inst_addra = 13; tb_inst_dina = 64'd0;
        @(posedge CLK); tb_inst_addra = 14; tb_inst_dina = 64'd0;

        @(posedge CLK); tb_inst_ena = 0; tb_inst_wea = 0;

        // ---------------------------------------------------------
        // PHASE 2: LOAD ACTIVATIONS
        // ---------------------------------------------------------
        $display("\n[PHASE 2] Loading 28x28x1 Input FMAP to Activations BRAM...");
        addr = 0;
        for (h = 0; h < 28; h = h + 1) begin
            for (w = 0; w < 28; w = w + 8) begin
                @(negedge CLK);
                tb_act_ena = 1; tb_act_wea = 1; tb_act_addra = addr; tb_act_dina = 128'd0;
                for (k = 0; k < 8; k = k + 1) begin
                    if (w + k < 28) tb_act_dina[k*16 +: 16] = test_image[h*28 + w + k];
                end
                addr = addr + 1;
            end
        end
        @(negedge CLK); tb_act_ena = 0; tb_act_wea = 0;

        // ---------------------------------------------------------
        // PHASE 3: LOAD WEIGHTS
        // ---------------------------------------------------------
        $display("\n[PHASE 3] Loading Conv1 and FC Kernels to Weights BRAM...");
        addr = WGT_BASE;
        // Conv1 Weights
        for (f = 0; f < 6; f = f + 1) begin
            for (h = 0; h < 5; h = h + 1) begin
                for (w = 0; w < 5; w = w + 1) begin
                    @(negedge CLK); tb_wgt_ena = 1; tb_wgt_wea = 1; tb_wgt_addra = addr;
                    tb_wgt_dina = test_kernel[f*25 + h*5 + w];
                    addr = addr + 1;
                end
            end
        end
        
        addr = FC_WGT_BASE;
        // FC Weights
        for (f = 0; f < 10; f = f + 1) begin
            for (c_idx = 0; c_idx < 6; c_idx = c_idx + 1) begin
                for (h = 0; h < 12; h = h + 1) begin
                    for (w = 0; w < 12; w = w + 1) begin
                        @(negedge CLK); tb_wgt_ena = 1; tb_wgt_wea = 1; tb_wgt_addra = addr;
                        tb_wgt_dina = test_fc_kernel[f*864 + c_idx*144 + h*12 + w];
                        addr = addr + 1;
                    end
                end
            end
        end
        @(negedge CLK); tb_wgt_ena = 0; tb_wgt_wea = 0;

        // ---------------------------------------------------------
        // PHASE 4: START CONTROLLER
        // ---------------------------------------------------------
        $display("\n[PHASE 4] Handing over BRAM control and Starting Controller...");
        tb_active = 0;

        @(posedge CLK); START_CONTROLLER = 1;
        @(posedge CLK); START_CONTROLLER = 0;

        // Wait for HALT with timeout using standard Verilog-2001 named block
        begin : WAIT_FOR_HALT
            fork
                begin
                    wait(halt == 1);
                    disable WAIT_FOR_HALT;
                end
                begin
                    #5000000; // Large timeout for the full CNN
                    $display("          TIMEOUT: Controller did not halt in 5ms.");
                    $finish;
                end
            join
        end
        $display("          Controller Reached HALT State!");

        // ---------------------------------------------------------
        // PHASE 5: VERIFY INDIVIDUAL FC LOGITS & FINAL ARGMAX
        // ---------------------------------------------------------
        $display("\n[PHASE 5] Dumping individual FC Logits (Addr %0d to %0d)...", FC_OUT_BASE, FC_OUT_BASE + 9);
        tb_active = 1;
        
        // 5a. Read back and print the raw logits produced by the FC layer
        for (f = 0; f < 10; f = f + 1) begin
            @(negedge CLK); 
            tb_act_enb = 1; 
            tb_act_addrb = FC_OUT_BASE + f;
            
            // Wait for 2-cycle BRAM latency
            @(negedge CLK); 
            @(negedge CLK); 
            #1; 

            $display("          Class %1d Logit: Expected %6d | Readback %6d", 
                     f, $signed(fc_out[f]), $signed(act_doutb[15:0]));
            
            if ($signed(act_doutb[15:0]) !== $signed(fc_out[f])) begin
                conv_errors = conv_errors + 1;
            end
        end
        @(negedge CLK); tb_act_enb = 0;

        // 5b. Verify the final classification result from the ArgMax module
        $display("\n[PHASE 5.5] Verifying Argmax Classification Result (Addr %0d)...", FINAL_CLASS_BASE);
        addr = FINAL_CLASS_BASE;
        
        @(negedge CLK); tb_act_enb = 1; tb_act_addrb = addr;
        @(negedge CLK); @(negedge CLK); #1;

        if (act_doutb[15:0] !== expected_class[15:0]) begin
            $display("          CLASS ERR: Expected Winner = %0d | Hardware Predicted = %0d", 
                     expected_class, act_doutb[15:0]);
            conv_errors = conv_errors + 1;
        end else begin
            $display("          PASS: Final Hardware Prediction = %0d (Confidence Logit: %d)", 
                     act_doutb[15:0], max_logit);
        end
        
        @(negedge CLK); tb_act_enb = 0;

        // ---------------------------------------------------------
        // FINAL RESULTS
        // ---------------------------------------------------------
        $display("\n==================================================");
        if (conv_errors == 0)
            $display("   FULL CNN VERIFICATION PASSED! 0 ERRORS.");
        else
            $display("   FULL CNN VERIFICATION FAILED WITH %0d ERRORS.", conv_errors);
        $display("==================================================");
        $finish;
    end
endmodule