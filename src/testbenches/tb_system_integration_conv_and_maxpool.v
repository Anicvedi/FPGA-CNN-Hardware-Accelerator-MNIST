`timescale 1ns / 1ps

module tb_system_integration_conv_and_maxpool();

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
    wire en_conv;
    wire en_maxp;
    wire sop_conv;
    wire sop_maxp;
    wire eop_conv;
    wire eop_maxp;
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

    // Activations BRAM Mux (Tri-state between TB, CONV, and MAXPOOL)
    wire act_ena          = tb_active ? tb_act_ena   : (en_conv ? conv_act_ena   : mp_bram_ena);
    wire act_wea          = tb_active ? tb_act_wea   : (en_conv ? conv_act_wea   : mp_bram_wea);
    wire [13:0] act_addra = tb_active ? tb_act_addra : (en_conv ? conv_act_addra : mp_bram_addra);
    wire [127:0] act_dina = tb_active ? tb_act_dina  : (en_conv ? conv_act_dina  : mp_bram_dina);
    wire act_enb          = tb_active ? tb_act_enb   : (en_conv ? conv_act_enb   : mp_bram_enb);
    wire [13:0] act_addrb = tb_active ? tb_act_addrb : (en_conv ? conv_act_addrb : mp_bram_addrb);

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
    //
    // MEMORY MAP:
    // Input Act (28x28x1): 4 words/row * 28 = 112 words. Base Addr: 0
    // Conv Output (24x24x6): 3 words/row * 24 * 6 = 432 words. Base Addr: 112
    // Pool Output (12x12x6): 2 words/row * 12 * 6 = 144 words. Base Addr: 544
    // Weights (5x5x1, 6 Filters): 25 words/filter * 6 = 150 words. Base Addr: 0
    //
    localparam IN_BASE = 14'd0;
    localparam WGT_BASE = 14'd0;
    localparam CONV_OUT_BASE = 14'd112;
    localparam POOL_OUT_BASE = 14'd544;

    // ---------------------------------------------------------
    // INSTANTIATIONS
    // ---------------------------------------------------------

    controller uut_controller (
        .CLK(CLK), .RST(RST), .START_CONTROLLER(START_CONTROLLER),
        .ENA(ctrl_inst_ena), .WEA(ctrl_inst_wea), .ADDRA(ctrl_inst_addra), .DINA(ctrl_inst_dina), .DOUTA(inst_douta),
        .EN_CONV(en_conv), .EN_MAXP(en_maxp), .SOP_CONV(sop_conv), .SOP_MAXP(sop_maxp), .EOP_CONV(eop_conv), .EOP_MAXP(eop_maxp),
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
        .MAX_FMAP_DIM(32), .MAX_KERNEL_WIDTH(5), .MAX_OUT_HEIGHT(24)
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
    integer f, c, h, w, k, kh_i, kw_i;
    integer addr;
    integer val, max_val;
    integer expected_val;
    integer write_errors, wgt_errors, conv_errors;
    
    reg signed [31:0] psum;
    reg [15:0] expected;

    // Flattened reference arrays to ensure strict Verilog-2001 compatibility
    reg [15:0] test_image [0:783];   // 28x28x1
    reg [15:0] test_kernel [0:149];  // 5x5x1 * 6 Filters
    reg [15:0] conv_out [0:3455];    // 24x24x6 Output
    reg [15:0] pool_out [0:863];     // 12x12x6 Output

    initial begin
        $display("==================================================");
        $display("   STARTING CNN SYSTEM INTEGRATION TEST           ");
        $display("==================================================");
        $display("   Target: PyTorch SimpleRTLCNN Architecture");
        $display("   Conv1: 28x28x1 -> 24x24x6 (Kernel 5x5)");
        $display("   MaxPool: 24x24x6 -> 12x12x6 (Pool 2x2)");
        $display("==================================================");

        // Initialize Data & Expected Values
        for (h = 0; h < 28; h = h + 1)
            for (w = 0; w < 28; w = w + 1)
                test_image[h*28 + w] = ((h + w) % 10) << 10; // Q1.5.10 values from 0.0 to 9.0

        for (f = 0; f < 6; f = f + 1)
            for (kh_i = 0; kh_i < 5; kh_i = kh_i + 1)
                for (kw_i = 0; kw_i < 5; kw_i = kw_i + 1)
                    test_kernel[f*25 + kh_i*5 + kw_i] = 16'd102; // 0.1 in Q1.5.10

        // Simulate Conv+ReLU behavior for validation
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

        // Simulate MaxPool behavior for validation
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

        // Initialize Environment
        RST = 1;
        START_CONTROLLER = 0;
        tb_active = 1;

        tb_inst_ena = 0; tb_inst_wea = 0; tb_inst_addra = 0; tb_inst_dina = 0;
        tb_act_ena = 0; tb_act_wea = 0; tb_act_enb = 0;
        tb_act_addra = 0; tb_act_addrb = 0; tb_act_dina = 0;
        tb_wgt_ena = 0; tb_wgt_wea = 0; tb_wgt_addra = 0; tb_wgt_dina = 0;

        write_errors = 0;
        wgt_errors = 0;
        conv_errors = 0;

        #100;
        @(posedge CLK); RST = 0; #20;

        // ---------------------------------------------------------
        // PHASE 1: LOAD INSTRUCTIONS
        // ---------------------------------------------------------
        $display("\n[PHASE 1] Loading Instructions into Controller BRAM...");

        // Instruction 1: Conv+ReLU
        @(posedge CLK); tb_inst_ena = 1; tb_inst_wea = 1; tb_inst_addra = 0;
        tb_inst_dina = {8'h01, IN_BASE, WGT_BASE, CONV_OUT_BASE, 14'd0};
        @(posedge CLK); tb_inst_addra = 1;
        tb_inst_dina = {10'd28, 10'd28, 10'd1, 10'd5, 10'd5, 10'd1, 4'd0};
        @(posedge CLK); tb_inst_addra = 2;
        tb_inst_dina = {10'd24, 10'd24, 10'd6, 8'd0, 8'd1, 4'd6, 14'd0}; // 6 Filters

        // Instruction 2: MaxPool
        @(posedge CLK); tb_inst_addra = 3;
        tb_inst_dina = {8'h02, CONV_OUT_BASE, 14'd0, POOL_OUT_BASE, 14'd0};
        @(posedge CLK); tb_inst_addra = 4;
        tb_inst_dina = {10'd24, 10'd24, 10'd6, 10'd0, 10'd0, 10'd0, 4'd0};
        @(posedge CLK); tb_inst_addra = 5;
        tb_inst_dina = {10'd12, 10'd12, 10'd6, 8'd2, 8'd2, 4'd0, 14'd0}; // Pool 2, Stride 2

        // Instruction 3: HALT
        @(posedge CLK); tb_inst_addra = 6; tb_inst_dina = {8'hFF, 56'd0};
        @(posedge CLK); tb_inst_addra = 7; tb_inst_dina = 64'd0;
        @(posedge CLK); tb_inst_addra = 8; tb_inst_dina = 64'd0;

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
                    if (w + k < 28) begin
                        tb_act_dina[k*16 +: 16] = test_image[h*28 + w + k];
                    end
                end
                addr = addr + 1;
            end
        end
        @(negedge CLK); tb_act_ena = 0; tb_act_wea = 0;

        // ---------------------------------------------------------
        // PHASE 3: LOAD WEIGHTS
        // ---------------------------------------------------------
        $display("\n[PHASE 3] Loading 5x5x1 Kernel (6 Filters) to Weights BRAM...");
        addr = 0;
        for (f = 0; f < 6; f = f + 1) begin
            for (h = 0; h < 5; h = h + 1) begin
                for (w = 0; w < 5; w = w + 1) begin
                    @(negedge CLK);
                    tb_wgt_ena = 1; tb_wgt_wea = 1; tb_wgt_addra = addr;
                    tb_wgt_dina = test_kernel[f*25 + h*5 + w];
                    addr = addr + 1;
                end
            end
        end
        @(negedge CLK); tb_wgt_ena = 0; tb_wgt_wea = 0;

        // ---------------------------------------------------------
        // PHASE 4: START CONTROLLER
        // ---------------------------------------------------------
        $display("\n[PHASE 4] Handing over BRAM control and Starting Controller...");
        tb_active = 0;

        @(posedge CLK);
        START_CONTROLLER = 1;
        @(posedge CLK);
        START_CONTROLLER = 0;

        // Wait for HALT with timeout using standard Verilog-2001 named block
        begin : WAIT_FOR_HALT
            fork
                begin
                    wait(halt == 1);
                    disable WAIT_FOR_HALT;
                end
                begin
                    #2000000; // Increased timeout for larger image + maxpool
                    $display("          TIMEOUT: Controller did not halt in 2ms.");
                    $finish;
                end
            join
        end

        $display("          Controller Reached HALT State!");

        // ---------------------------------------------------------
        // PHASE 5: VERIFY FINAL MAXPOOL OUTPUT
        // ---------------------------------------------------------
        $display("\n[PHASE 5] Verifying 12x12x6 MaxPool Output (Addr %0d)...", POOL_OUT_BASE);
        tb_active = 1;
        addr = POOL_OUT_BASE;

        for (f = 0; f < 6; f = f + 1) begin
            $display("          Checking Channel %0d...", f);
            for (h = 0; h < 12; h = h + 1) begin
                for (w = 0; w < 12; w = w + 8) begin

                    @(negedge CLK); tb_act_enb = 1; tb_act_addrb = addr;
                    @(negedge CLK); @(negedge CLK); #1;

                    for (k = 0; k < 8; k = k + 1) begin
                        if (w + k < 12) begin
                            expected_val = pool_out[f*144 + h*12 + w + k];

                            if (act_doutb[k*16 +: 16] !== expected_val[15:0]) begin
                                $display("          POOL ERR F=%0d H=%0d W=%0d: Exp %0d Got %0d",
                                         f, h, w+k, expected_val, act_doutb[k*16 +: 16]);
                                conv_errors = conv_errors + 1;
                            end
                        end
                    end
                    addr = addr + 1;
                end
            end
        end
        @(negedge CLK); tb_act_enb = 0;

        // ---------------------------------------------------------
        // FINAL RESULTS
        // ---------------------------------------------------------
        $display("\n==================================================");
        if (conv_errors == 0)
            $display("   CNN VERIFICATION PASSED! 0 ERRORS.");
        else
            $display("   CNN VERIFICATION FAILED WITH %0d ERRORS.", conv_errors);
        $display("==================================================");
        $finish;
    end

endmodule