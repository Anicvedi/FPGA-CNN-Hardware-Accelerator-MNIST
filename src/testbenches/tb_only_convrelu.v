`timescale 1ns / 1ps

module tb_system_integration_onlyconvrelu();

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
    // CONTROLLER -> CONVRELU INTERFACE
    // ---------------------------------------------------------
    wire en_conv;
    wire en_maxp;
    wire sop_conv;
    wire sop_maxp;
    wire eop_conv;
    wire eop_maxp = 1'b0; // Tied to 0: no maxpool in this test
    wire halt;

    // Decoded Parameter Wires
    wire [13:0] inp_act_addr, inp_wgt_addr, out_act_addr;
    wire [9:0]  inp_act_dim1, inp_act_dim2, inp_act_dim3;
    wire [9:0]  wgt_dim1, wgt_dim2, wgt_dim3;
    wire [9:0]  out_act_dim1, out_act_dim2, out_act_dim3;
    wire [7:0]  pool_dim, conv_stride;
    wire [3:0]  no_of_filter;

    // ---------------------------------------------------------
    // CONVRELU -> BRAM ACTIVATIONS INTERFACE (128-BIT DUAL PORT)
    // ---------------------------------------------------------
    wire conv_act_ena, conv_act_wea;
    wire [13:0] conv_act_addra;
    wire [127:0] conv_act_dina;
    wire conv_act_enb;
    wire [13:0] conv_act_addrb;
    wire [127:0] act_doutb;

    // ---------------------------------------------------------
    // CONVRELU -> BRAM WEIGHTS INTERFACE (16-BIT SINGLE PORT)
    // ---------------------------------------------------------
    wire conv_wgt_ena;
    wire conv_wgt_wea;
    wire [13:0] conv_wgt_addra;
    wire [15:0] conv_wgt_dina;
    wire [15:0] wgt_douta;

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

    // Activations BRAM Mux
    wire act_ena          = tb_active ? tb_act_ena   : conv_act_ena;
    wire act_wea          = tb_active ? tb_act_wea   : conv_act_wea;
    wire [13:0] act_addra = tb_active ? tb_act_addra : conv_act_addra;
    wire [127:0] act_dina = tb_active ? tb_act_dina  : conv_act_dina;
    wire act_enb          = tb_active ? tb_act_enb   : conv_act_enb;
    wire [13:0] act_addrb = tb_active ? tb_act_addrb : conv_act_addrb;

    // Weights BRAM Mux
    wire wgt_ena          = tb_active ? tb_wgt_ena   : conv_wgt_ena;
    wire wgt_wea          = tb_active ? tb_wgt_wea   : conv_wgt_wea;
    wire [13:0] wgt_addra = tb_active ? tb_wgt_addra : conv_wgt_addra;
    wire [15:0] wgt_dina  = tb_active ? tb_wgt_dina  : conv_wgt_dina;

    // ---------------------------------------------------------
    // TEST PARAMETERS
    // ---------------------------------------------------------
    //
    // Input FMAP:  5x5x1  (H=5, W=5, C=1)
    // Kernel:      3x3x1  (KH=3, KW=3, C=1), 1 filter
    // Stride:      1
    // Output FMAP: 3x3x1  (OH=3, OW=3, OC=1)
    //
    // Memory Map (Activation BRAM, 128-bit = 8 pixels per word):
    //   Input:  addr 0-4  (5 rows, ceil(5/8)=1 word/row)
    //   Output: addr 5-7  (3 rows, ceil(3/8)=1 word/row)
    //
    // Memory Map (Weight BRAM, 16-bit = 1 weight per addr):
    //   Filter 0: addr 0-8  (3x3 = 9 weights)
    //
    // Activation values:  act[h][w] = h*5 + w + 1  (raw Q1.5.10)
    // Weight values:      wgt[kh][kw] = 1024       (= 1.0 in Q1.5.10)
    //
    // Fixed-Point Math:
    //   product = act_raw * 1024 = act_raw * 2^10
    //   sum     = (sum_of_acts_in_window) * 2^10
    //   trunc   = sum[25:10] = sum_of_acts_in_window
    //   relu    = trunc (all positive, no clamping)
    //

    localparam IN_H = 5, IN_W = 5, IN_C = 1;
    localparam KH = 3, KW = 3;
    localparam OUT_H = 3, OUT_W = 3;
    localparam IN_BASE = 14'd0;
    localparam WGT_BASE = 14'd0;
    localparam OUT_BASE = 14'd5;
    localparam signed [15:0] WGT_VAL = 16'sd1024; // 1.0 in Q1.5.10

    // ---------------------------------------------------------
    // INSTANTIATIONS
    // ---------------------------------------------------------

    controller uut_controller (
        .CLK(CLK),
        .RST(RST),
        .START_CONTROLLER(START_CONTROLLER),

        .ENA(ctrl_inst_ena),
        .WEA(ctrl_inst_wea),
        .ADDRA(ctrl_inst_addra),
        .DINA(ctrl_inst_dina),
        .DOUTA(inst_douta),

        .EN_CONV(en_conv),
        .EN_MAXP(en_maxp),
        .SOP_CONV(sop_conv),
        .SOP_MAXP(sop_maxp),
        .EOP_CONV(eop_conv),
        .EOP_MAXP(eop_maxp),

        .INP_ACT_ADDR(inp_act_addr),
        .INP_WGT_ADDR(inp_wgt_addr),
        .OUT_ACT_ADDR(out_act_addr),

        .INP_ACT_DIM1(inp_act_dim1),
        .INP_ACT_DIM2(inp_act_dim2),
        .INP_ACT_DIM3(inp_act_dim3),
        .WGT_DIM1(wgt_dim1),
        .WGT_DIM2(wgt_dim2),
        .WGT_DIM3(wgt_dim3),

        .OUT_ACT_DIM1(out_act_dim1),
        .OUT_ACT_DIM2(out_act_dim2),
        .OUT_ACT_DIM3(out_act_dim3),
        .POOL_DIM(pool_dim),
        .CONV_STRIDE(conv_stride),
        .NO_OF_FILTER(no_of_filter),
        .halt(halt)
    );

    bram_instructions_wrapper uut_bram_inst (
        .CLK(CLK),
        .ENA(inst_ena),
        .WEA(inst_wea),
        .ADDRA(inst_addra),
        .DINA(inst_dina),
        .DOUTA(inst_douta)
    );

    ops_convrelu #(
        .MAX_FMAP_DIM     (8),
        .MAX_KERNEL_WIDTH (5),
        .MAX_OUT_HEIGHT   (4) // Adjusted from MIN_KERNEL_WIDTH to MAX_OUT_HEIGHT based on the final 120x5 ops_convrelu module
    ) uut_convrelu (
        .CLK_IN(CLK),
        .RESET(RST),
        .MODULE_EN(en_conv),

        .EXT_START_OF_COMPUTE(sop_conv),
        .EXT_END_OF_COMPUTE(eop_conv),

        // Mapped: DIM1=H, DIM2=W, DIM3=C
        .IN_FMAP_BASEADDR(inp_act_addr),
        .IN_FMAP_DIM_H(inp_act_dim1),
        .IN_FMAP_DIM_W(inp_act_dim2),
        .IN_FMAP_DIM_C(inp_act_dim3),

        .WEIGHT_BASEADDR(inp_wgt_addr),
        .WEIGHT_DIM_H(wgt_dim1),
        .WEIGHT_DIM_W(wgt_dim2),
        .WEIGHT_DIM_C(wgt_dim3),
        .NUM_FILTERS(no_of_filter),

        .OUT_FMAP_BASEADDR(out_act_addr),
        .OUT_FMAP_DIM_H(out_act_dim1),
        .OUT_FMAP_DIM_W(out_act_dim2),
        .OUT_FMAP_DIM_C(out_act_dim3),

        .STRIDE(conv_stride),

        .BRAM_act_ENA(conv_act_ena),
        .BRAM_act_WEA(conv_act_wea),
        .BRAM_act_ADDRA(conv_act_addra),
        .BRAM_act_DINA(conv_act_dina),

        .BRAM_act_ENB(conv_act_enb),
        .BRAM_act_ADDRB(conv_act_addrb),
        .BRAM_act_DOUTB(act_doutb),

        .BRAM_wgt_ENA(conv_wgt_ena),
        .BRAM_wgt_WEA(conv_wgt_wea),
        .BRAM_wgt_ADDRA(conv_wgt_addra),
        .BRAM_wgt_DINA(conv_wgt_dina),
        .BRAM_wgt_DOUTA(wgt_douta)
    );

    bram_activations_wrapper uut_bram_act (
        .CLK(CLK),
        .ena(act_ena),
        .wea(act_wea),
        .addra(act_addra),
        .dina(act_dina),
        .enb(act_enb),
        .addrb(act_addrb),
        .doutb(act_doutb)
    );

    bram_weights_wrapper uut_bram_wgt (
        .CLK(CLK),
        .ENA(wgt_ena),
        .WEA(wgt_wea),
        .ADDRA(wgt_addra),
        .DINA(wgt_dina),
        .DOUTA(wgt_douta)
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
    integer c, h, w, k, kh_i, kw_i;
    integer addr;
    integer val;
    integer expected_val;
    integer write_errors;
    integer wgt_errors;
    integer conv_errors;
    integer expected_sum;

    initial begin
        $display("==================================================");
        $display("   STARTING CONVRELU SYSTEM INTEGRATION TEST      ");
        $display("==================================================");
        $display("   Config: 5x5x1 input, 3x3 kernel (all 1.0),");
        $display("           stride 1, 1 filter -> 3x3x1 output");
        $display("==================================================");

        // Initialize Signals
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
        @(posedge CLK);
        RST = 0;
        #20;

        // ---------------------------------------------------------
        // PHASE 1: LOAD INSTRUCTIONS
        // ---------------------------------------------------------
        $display("\n[PHASE 1] Loading Instructions into Controller BRAM...");

        // Instruction 1: Conv+ReLU
        // Word 0: Opcode=CONV(0x01), In_Addr=0, Wgt_Addr=0, Out_Addr=5
        @(posedge CLK);
        tb_inst_ena = 1; tb_inst_wea = 1;
        tb_inst_addra = 0;
        tb_inst_dina = {8'h01, 14'd0, 14'd0, 14'd5, 14'd0};

        // Word 1: In_H=5, In_W=5, In_C=1, Wgt_H=3, Wgt_W=3, Wgt_C=1
        @(posedge CLK);
        tb_inst_addra = 1;
        tb_inst_dina = {10'd5, 10'd5, 10'd1, 10'd3, 10'd3, 10'd1, 4'd0};

        // Word 2: Out_H=3, Out_W=3, Out_C=1, Pool=0, Stride=1, NumFilt=1
        @(posedge CLK);
        tb_inst_addra = 2;
        tb_inst_dina = {10'd3, 10'd3, 10'd1, 8'd0, 8'd1, 4'd1, 14'd0};

        // Instruction 2: HALT
        @(posedge CLK); tb_inst_addra = 3; tb_inst_dina = {8'hFF, 56'd0};
        @(posedge CLK); tb_inst_addra = 4; tb_inst_dina = 64'd0;
        @(posedge CLK); tb_inst_addra = 5; tb_inst_dina = 64'd0;

        @(posedge CLK);
        tb_inst_ena = 0; tb_inst_wea = 0;
        $display("          Instruction Load Complete.");

        // ---------------------------------------------------------
        // PHASE 2: LOAD ACTIVATIONS
        // ---------------------------------------------------------
        $display("\n[PHASE 2] Loading 5x5x1 Input FMAP to Activations BRAM...");
        $display("          Values: act[h][w] = h*5 + w + 1 (raw Q1.5.10)");
        addr = 0;

        for (c = 0; c < IN_C; c = c + 1) begin
            for (h = 0; h < IN_H; h = h + 1) begin
                for (w = 0; w < IN_W; w = w + 8) begin
                    @(posedge CLK);
                    tb_act_ena = 1;
                    tb_act_wea = 1;
                    tb_act_addra = addr;
                    tb_act_dina = 128'd0;

                    for (k = 0; k < 8; k = k + 1) begin
                        if (w + k < IN_W) begin
                            val = (c * IN_H * IN_W) + (h * IN_W) + (w + k) + 1;
                            tb_act_dina[k*16 +: 16] = val;
                        end
                    end

                    addr = addr + 1;
                end
            end
        end
        @(posedge CLK);
        tb_act_ena = 0; tb_act_wea = 0;
        $display("          Wrote %0d activation words.", addr);

        // ---------------------------------------------------------
        // PHASE 3: LOAD WEIGHTS
        // ---------------------------------------------------------
        $display("\n[PHASE 3] Loading 3x3x1 Kernel to Weights BRAM...");
        $display("          All weights = 1024 (1.0 in Q1.5.10)");
        addr = 0;

        for (c = 0; c < IN_C; c = c + 1) begin
            for (h = 0; h < KH; h = h + 1) begin
                for (w = 0; w < KW; w = w + 1) begin
                    @(posedge CLK);
                    tb_wgt_ena = 1;
                    tb_wgt_wea = 1;
                    tb_wgt_addra = addr;
                    tb_wgt_dina = WGT_VAL;
                    addr = addr + 1;
                end
            end
        end
        @(posedge CLK);
        tb_wgt_ena = 0; tb_wgt_wea = 0;
        $display("          Wrote %0d weight values.", addr);

        // ---------------------------------------------------------
        // PHASE 4: VERIFY LOADED ACTIVATIONS
        // ---------------------------------------------------------
        $display("\n[PHASE 4] Verifying Input Activations in BRAM...");
        addr = 0;

        for (c = 0; c < IN_C; c = c + 1) begin
            for (h = 0; h < IN_H; h = h + 1) begin
                for (w = 0; w < IN_W; w = w + 8) begin
                    @(posedge CLK); tb_act_enb = 1; tb_act_addrb = addr;
                    @(posedge CLK); @(posedge CLK); #1;

                    for (k = 0; k < 8; k = k + 1) begin
                        if (w + k < IN_W) begin
                            expected_val = (c * IN_H * IN_W) + (h * IN_W) + (w + k) + 1;
                            if (act_doutb[k*16 +: 16] !== expected_val) begin
                                $display("          WRITE ERR Addr %0d Pix %0d: Exp %0d Got %0d",
                                         addr, k, expected_val, act_doutb[k*16 +: 16]);
                                write_errors = write_errors + 1;
                            end
                        end
                    end
                    addr = addr + 1;
                end
            end
        end
        @(posedge CLK); tb_act_enb = 0;

        if (write_errors == 0)
            $display("          Activation Verification Passed!");
        else begin
            $display("          Activation Verification FAILED. Aborting.");
            $finish;
        end

        // ---------------------------------------------------------
        // PHASE 5: VERIFY LOADED WEIGHTS
        // ---------------------------------------------------------
        $display("\n[PHASE 5] Verifying Weights in BRAM...");
        addr = 0;

        for (c = 0; c < IN_C; c = c + 1) begin
            for (h = 0; h < KH; h = h + 1) begin
                for (w = 0; w < KW; w = w + 1) begin
                    @(posedge CLK); tb_wgt_ena = 1; tb_wgt_wea = 0; tb_wgt_addra = addr;
                    @(posedge CLK); @(posedge CLK); #1;

                    if (wgt_douta !== WGT_VAL) begin
                        $display("          WGT ERR Addr %0d: Exp %0d Got %0d",
                                 addr, WGT_VAL, wgt_douta);
                        wgt_errors = wgt_errors + 1;
                    end
                    addr = addr + 1;
                end
            end
        end
        @(posedge CLK); tb_wgt_ena = 0;

        if (wgt_errors == 0)
            $display("          Weight Verification Passed!");
        else begin
            $display("          Weight Verification FAILED. Aborting.");
            $finish;
        end

        // ---------------------------------------------------------
        // PHASE 6: START CONTROLLER
        // ---------------------------------------------------------
        $display("\n[PHASE 6] Handing over BRAM control and Starting Controller...");
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
                    #500000;
                    $display("          TIMEOUT: Controller did not halt in 500us.");
                    $finish;
                end
            join
        end

        $display("          Controller Reached HALT State!");

        // ---------------------------------------------------------
        // PHASE 7: VERIFY CONVRELU OUTPUT
        // ---------------------------------------------------------
        //
        // Expected output at (oh, ow):
        //   raw = sum over kh=0..2, kw=0..2 of act_raw[oh+kh][ow+kw]
        //       = sum of ( (oh+kh)*5 + (ow+kw) + 1 )
        //
        // Math: with wgt=1024 (=2^10), product = act_raw * 2^10.
        //       sum_products = (sum_act_raw) * 2^10.
        //       trunc bits[25:10] = sum_act_raw.
        //       relu: all positive, no clamping.
        //
        $display("\n[PHASE 7] Verifying ConvReLU Output (Addr %0d)...", OUT_BASE);
        tb_active = 1;
        addr = OUT_BASE;

        for (h = 0; h < OUT_H; h = h + 1) begin
            for (w = 0; w < OUT_W; w = w + 8) begin

                @(posedge CLK); tb_act_enb = 1; tb_act_addrb = addr;
                @(posedge CLK); @(posedge CLK); #1;

                for (k = 0; k < 8; k = k + 1) begin
                    if (w + k < OUT_W) begin
                        // compute expected: sum of 3x3 window of raw activations
                        expected_sum = 0;
                        for (kh_i = 0; kh_i < KH; kh_i = kh_i + 1)
                            for (kw_i = 0; kw_i < KW; kw_i = kw_i + 1)
                                expected_sum = expected_sum
                                    + ((h + kh_i) * IN_W + (w + k + kw_i) + 1);

                        if (act_doutb[k*16 +: 16] !== expected_sum[15:0]) begin
                            $display("          CONV ERR out[%0d][%0d] Addr %0d Pix %0d: Exp %0d Got %0d",
                                     h, w+k, addr, k, expected_sum, act_doutb[k*16 +: 16]);
                            conv_errors = conv_errors + 1;
                        end else begin
                            $display("          PASS out[%0d][%0d]: %0d", h, w+k, act_doutb[k*16 +: 16]);
                        end
                    end
                end
                addr = addr + 1;
            end
        end
        @(posedge CLK); tb_act_enb = 0;

        // ---------------------------------------------------------
        // PRINT EXPECTED OUTPUT GRID
        // ---------------------------------------------------------
        $display("\n          Expected Output Grid:");
        for (h = 0; h < OUT_H; h = h + 1) begin
            for (w = 0; w < OUT_W; w = w + 1) begin
                expected_sum = 0;
                for (kh_i = 0; kh_i < KH; kh_i = kh_i + 1)
                    for (kw_i = 0; kw_i < KW; kw_i = kw_i + 1)
                        expected_sum = expected_sum
                            + ((h + kh_i) * IN_W + (w + kw_i) + 1);
                $write("          %4d", expected_sum);
            end
            $write("\n");
        end

        // ---------------------------------------------------------
        // FINAL RESULTS
        // ---------------------------------------------------------
        $display("\n==================================================");
        if (conv_errors == 0)
            $display("   CONVRELU VERIFICATION PASSED! 0 ERRORS.");
        else
            $display("   CONVRELU VERIFICATION FAILED WITH %0d ERRORS.", conv_errors);
        $display("==================================================");
        $finish;
    end

endmodule