`timescale 1ns / 1ps

module tb_system_integration();

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
    wire en_conv, en_maxp;
    wire sop_conv, sop_maxp;
    wire eop_conv, eop_maxp;
    wire halt;

    wire [13:0] inp_act_addr, inp_wgt_addr, out_act_addr;
    wire [9:0]  inp_act_dim1, inp_act_dim2, inp_act_dim3;
    wire [9:0]  wgt_dim1, wgt_dim2, wgt_dim3;
    wire [9:0]  out_act_dim1, out_act_dim2, out_act_dim3;
    wire [7:0]  pool_dim, conv_stride;
    wire [3:0]  no_of_filter;

    // ---------------------------------------------------------
    // BRAM ARBITRATION (TB vs CONV vs MAXP)
    // ---------------------------------------------------------
    reg tb_active; 
    
    // TB Instruction Registers
    reg tb_inst_ena, tb_inst_wea;
    reg [9:0] tb_inst_addra;
    reg [63:0] tb_inst_dina;

    // TB Activation Registers
    reg tb_act_ena, tb_act_wea, tb_act_enb;
    reg [13:0] tb_act_addra, tb_act_addrb;
    reg [127:0] tb_act_dina;

    // TB Weight Registers
    reg tb_wgt_ena, tb_wgt_wea;
    reg [13:0] tb_wgt_addra;
    reg [15:0] tb_wgt_dina;

    // Module Weight BRAM Wires
    wire conv_wgt_ena, conv_wgt_wea;
    wire [13:0] conv_wgt_addra;
    wire [15:0] conv_wgt_dina;
    wire [15:0] wgt_douta;

    // Module Activation BRAM Wires
    wire conv_act_ena, conv_act_wea, conv_act_enb;
    wire [13:0] conv_act_addra, conv_act_addrb;
    wire [127:0] conv_act_dina;

    wire mp_act_ena, mp_act_wea, mp_act_enb;
    wire [13:0] mp_act_addra, mp_act_addrb;
    wire [127:0] mp_act_dina;
    wire [127:0] act_doutb;

    // Instruction BRAM Mux
    wire inst_ena         = tb_active ? tb_inst_ena   : ctrl_inst_ena;
    wire inst_wea         = tb_active ? tb_inst_wea   : ctrl_inst_wea;
    wire [9:0] inst_addra = tb_active ? tb_inst_addra : ctrl_inst_addra;
    wire [63:0] inst_dina = tb_active ? tb_inst_dina  : ctrl_inst_dina;

    // Weights BRAM Mux (Single Port)
    wire wgt_ena          = tb_active ? tb_wgt_ena    : (en_conv ? conv_wgt_ena   : 1'b0);
    wire wgt_wea          = tb_active ? tb_wgt_wea    : (en_conv ? conv_wgt_wea   : 1'b0);
    wire [13:0] wgt_addra = tb_active ? tb_wgt_addra  : (en_conv ? conv_wgt_addra : 14'd0);
    wire [15:0] wgt_dina  = tb_active ? tb_wgt_dina   : (en_conv ? conv_wgt_dina  : 16'd0);

    // Activations BRAM Port A Mux (Write Port)
    wire act_ena = tb_active ? tb_act_ena : (en_conv ? conv_act_ena : mp_act_ena);
    wire act_wea = tb_active ? tb_act_wea : (en_conv ? conv_act_wea : mp_act_wea);
    wire [13:0] act_addra = tb_active ? tb_act_addra : (en_conv ? conv_act_addra : mp_act_addra);
    wire [127:0] act_dina = tb_active ? tb_act_dina : (en_conv ? conv_act_dina : mp_act_dina);
    
    // Activations BRAM Port B Mux (Read Port)
    wire act_enb = tb_active ? tb_act_enb : (en_conv ? conv_act_enb : mp_act_enb);
    wire [13:0] act_addrb = tb_active ? tb_act_addrb : (en_conv ? conv_act_addrb : mp_act_addrb);

    // ---------------------------------------------------------
    // INSTANTIATIONS
    // ---------------------------------------------------------
    controller uut_controller (
        .CLK(CLK), .RST(RST), .START_CONTROLLER(START_CONTROLLER),
        .ENA(ctrl_inst_ena), .WEA(ctrl_inst_wea), .ADDRA(ctrl_inst_addra), .DINA(ctrl_inst_dina), .DOUTA(inst_douta),
        .EN_CONV(en_conv), .EN_MAXP(en_maxp), .SOP_CONV(sop_conv), .SOP_MAXP(sop_maxp),
        .EOP_CONV(eop_conv), .EOP_MAXP(eop_maxp),
        .INP_ACT_ADDR(inp_act_addr), .INP_WGT_ADDR(inp_wgt_addr), .OUT_ACT_ADDR(out_act_addr),
        .INP_ACT_DIM1(inp_act_dim1), .INP_ACT_DIM2(inp_act_dim2), .INP_ACT_DIM3(inp_act_dim3),
        .WGT_DIM1(wgt_dim1), .WGT_DIM2(wgt_dim2), .WGT_DIM3(wgt_dim3),
        .OUT_ACT_DIM1(out_act_dim1), .OUT_ACT_DIM2(out_act_dim2), .OUT_ACT_DIM3(out_act_dim3),
        .POOL_DIM(pool_dim), .CONV_STRIDE(conv_stride), .NO_OF_FILTER(no_of_filter), .halt(halt)
    );

    ops_convrelu uut_convrelu (
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
        .BRAM_ena(mp_act_ena), .BRAM_wea(mp_act_wea), .BRAM_addra(mp_act_addra), .BRAM_dina(mp_act_dina),
        .BRAM_enb(mp_act_enb), .BRAM_addrb(mp_act_addrb), .BRAM_doutb(act_doutb)
    );

    bram_instructions_wrapper uut_bram_inst (
        .CLK(CLK), .ENA(inst_ena), .WEA(inst_wea), .ADDRA(inst_addra), .DINA(inst_dina), .DOUTA(inst_douta)
    );

    bram_activations_wrapper uut_bram_act (
        .CLK(CLK), .ena(act_ena), .wea(act_wea), .addra(act_addra), .dina(act_dina),
        .enb(act_enb), .addrb(act_addrb), .doutb(act_doutb)
    );

    bram_weights_wrapper uut_bram_wgt (
        .CLK(CLK), .ENA(wgt_ena), .WEA(wgt_wea), .ADDRA(wgt_addra), .DINA(wgt_dina), .DOUTA(wgt_douta)
    );

    // ---------------------------------------------------------
    // HELPER FUNCTIONS & CLOCK
    // ---------------------------------------------------------
    initial begin CLK = 0; forever #5 CLK = ~CLK; end

    function [15:0] max4(input [15:0] a, b, c, d);
        reg [15:0] m1, m2;
        begin
            m1 = (a > b) ? a : b;
            m2 = (c > d) ? c : d;
            max4 = (m1 > m2) ? m1 : m2;
        end
    endfunction

    // ---------------------------------------------------------
    // REAL-TIME SPAD HARDWARE MONITOR
    // ---------------------------------------------------------
    always @(posedge CLK) begin
        if (en_conv && uut_convrelu.state == 4'd6 && uut_convrelu.compute_cycles == 10'd0) begin
            if (uut_convrelu.filter == 0 && uut_convrelu.out_wb_row == 0) begin
                $display("   [SPAD MONITOR] Time: %0t | Kernel Row: %0d", $time, uut_convrelu.krow);
                $display("      WGT_SPAD[0:4] = [%6d, %6d, %6d, %6d, %6d]", 
                    $signed(uut_convrelu.ARRAY_Y[0].u_row.wgt_spad[0]),
                    $signed(uut_convrelu.ARRAY_Y[0].u_row.wgt_spad[1]),
                    $signed(uut_convrelu.ARRAY_Y[0].u_row.wgt_spad[2]),
                    $signed(uut_convrelu.ARRAY_Y[0].u_row.wgt_spad[3]),
                    $signed(uut_convrelu.ARRAY_Y[0].u_row.wgt_spad[4])
                );
                $display("      ACT_SPAD[0:7] = [%6d, %6d, %6d, %6d, %6d, %6d, %6d, %6d]", 
                    $signed(uut_convrelu.ARRAY_Y[0].u_row.act_spad[0]),
                    $signed(uut_convrelu.ARRAY_Y[0].u_row.act_spad[1]),
                    $signed(uut_convrelu.ARRAY_Y[0].u_row.act_spad[2]),
                    $signed(uut_convrelu.ARRAY_Y[0].u_row.act_spad[3]),
                    $signed(uut_convrelu.ARRAY_Y[0].u_row.act_spad[4]),
                    $signed(uut_convrelu.ARRAY_Y[0].u_row.act_spad[5]),
                    $signed(uut_convrelu.ARRAY_Y[0].u_row.act_spad[6]),
                    $signed(uut_convrelu.ARRAY_Y[0].u_row.act_spad[7])
                );
            end
        end
    end

    integer c, h, w, k, i, f, col_idx;
    integer addr, in_r, in_c, base_idx;
    integer expected_val;
    integer val0, val1, val2, val3;
    integer err_load=0, err_conv=0, err_pool=0;
    
    // Arrays for Verification Math
    reg [15:0] flat_weights [0:149]; // True 16-bit addressing: 6 filters * 25 weights = 150
    reg [15:0] mnist_img [0:783]; // 28x28 Input Image
    
    // Intermediate Capture Memory for Decoupled MaxPool Verification
    reg [15:0] conv_out_mem [0:3455]; // 24x24x6 = 3456 pixels

    initial begin
        $display("=======================================================");
        $display("   STARTING END-TO-END DECOUPLED NETWORK TEST ");
        $display("=======================================================");

        RST = 1; START_CONTROLLER = 0; tb_active = 1; 
        tb_inst_ena = 0; tb_inst_wea = 0; 
        tb_act_ena  = 0; tb_act_wea  = 0; tb_act_enb = 0; 
        tb_wgt_ena  = 0; tb_wgt_wea  = 0;
        
        #100; @(posedge CLK); RST = 0; #20;

        // ---------------------------------------------------------
        // PHASE 1: LOAD INSTRUCTIONS
        // ---------------------------------------------------------
        $display("\n[PHASE 1] Loading Instructions into Controller BRAM...");
        
        // Inst 1: CONV2D (Input 28x28x1 -> Output 24x24x6)
        @(posedge CLK); tb_inst_ena=1; tb_inst_wea=1; tb_inst_addra=0; 
        tb_inst_dina={8'h01, 14'd30, 14'd0, 14'd140, 14'd0}; 
        @(posedge CLK); tb_inst_addra=1; 
        tb_inst_dina={10'd28, 10'd28, 10'd1, 10'd5, 10'd5, 10'd1, 4'd0};
        @(posedge CLK); tb_inst_addra=2; 
        tb_inst_dina={10'd24, 10'd24, 10'd6, 8'd0, 8'd1, 4'd6, 14'd0}; 
        
        // Inst 2: MAXPOOL2D (Input 24x24x6 -> Output 12x12x6)
        @(posedge CLK); tb_inst_addra=3; 
        tb_inst_dina={8'h02, 14'd140, 14'd0, 14'd600, 14'd0}; 
        @(posedge CLK); tb_inst_addra=4; 
        tb_inst_dina={10'd24, 10'd24, 10'd6, 10'd0, 10'd0, 10'd0, 4'd0};
        @(posedge CLK); tb_inst_addra=5; 
        tb_inst_dina={10'd12, 10'd12, 10'd6, 8'd2, 8'd2, 4'd0, 14'd0};
        
        // Inst 3: HALT
        @(posedge CLK); tb_inst_addra=6; tb_inst_dina={8'hFF, 56'd0};
        @(posedge CLK); tb_inst_addra=7; tb_inst_dina=64'd0;
        @(posedge CLK); tb_inst_addra=8; tb_inst_dina=64'd0;
        @(posedge CLK); tb_inst_ena = 0; tb_inst_wea = 0;

// ---------------------------------------------------------
        // PHASE 2A: LOAD IDENTITY WEIGHTS & PATTERN DATA (Q1.5.10)
        // ---------------------------------------------------------
        $display("\n[PHASE 2A] Initializing BRAMs with Identity Weights & Debug Pattern in Q1.5.10...");
        
        // 1. Setup Weights: 0 except for Center Pixel (1024 * filter_id)
        for(i = 0; i < 150; i = i + 1) flat_weights[i] = 0;
        // Center pixel is at Row 2, Col 2. Index = 2*5 + 2 = 12.
        for(f = 0; f < 6; f = f + 1) flat_weights[f * 25 + 12] = 1024 * (f + 1);
        
        // Write Weights to 16-bit BRAM
        addr = 0;
        for(i = 0; i < 150; i = i + 1) begin
            @(posedge CLK); tb_wgt_ena = 1; tb_wgt_wea = 1; 
            tb_wgt_addra = addr; tb_wgt_dina = flat_weights[i];
            addr = addr + 1;
        end
        @(posedge CLK); tb_wgt_ena = 0; tb_wgt_wea = 0;
        
        // 2. Setup Debug Pattern Image
        // Format: (Row+1)*1024 + (Col+1). 
        // Max value is 28*1024 + 28 = 28700 (Safely inside 16-bit signed max of 32767)
        for (h = 0; h < 28; h = h + 1) begin
            for (w = 0; w < 28; w = w + 1) begin
                mnist_img[h * 28 + w] = (h + 1) * 1024 + (w + 1);
            end
        end

        // Write Activations to 128-bit BRAM
        addr = 30; 
        for (h = 0; h < 28; h = h + 1) begin
            for (w = 0; w < 28; w = w + 8) begin 
                @(posedge CLK); tb_act_ena = 1; tb_act_wea = 1; tb_act_addra = addr; tb_act_dina = 128'd0; 
                for (k = 0; k < 8; k = k + 1) begin
                    if (w + k < 28) tb_act_dina[k*16 +: 16] = mnist_img[h * 28 + (w + k)]; 
                end
                addr = addr + 1;
            end
        end
        @(posedge CLK); tb_act_ena = 0; tb_act_wea = 0;

        // ---------------------------------------------------------
        // PHASE 2B: VERIFY BRAM DATA READBACK
        // ---------------------------------------------------------
        $display("\n[PHASE 2B] Verifying BRAM Loads via Readback...");
        
        // 1. Verify Weights (16-bit Port A Readback)
        addr = 0;
        for(i = 0; i < 150; i = i + 1) begin
            @(posedge CLK); tb_wgt_ena = 1; tb_wgt_wea = 0; tb_wgt_addra = addr;
            @(posedge CLK); @(posedge CLK); #1; // Wait 2 cycles for BRAM latency
            
            expected_val = flat_weights[i];
            if (wgt_douta !== expected_val) begin
                $display("          ❌ WGT LOAD ERROR at Addr %0d: Expected %0d, Got %0d", addr, expected_val, wgt_douta);
                err_load = err_load + 1;
            end
            addr = addr + 1;
        end
        @(posedge CLK); tb_wgt_ena = 0;
        
        // 2. Verify Activations (128-bit Port B Readback)
        addr = 30;
        for (h = 0; h < 28; h = h + 1) begin
            for (w = 0; w < 28; w = w + 8) begin 
                @(posedge CLK); tb_act_enb = 1; tb_act_addrb = addr;
                @(posedge CLK); @(posedge CLK); #1;
                for (k = 0; k < 8; k = k + 1) begin
                    if (w + k < 28) begin
                        expected_val = mnist_img[h * 28 + (w + k)];
                        if (act_doutb[k*16 +: 16] !== expected_val) begin
                            $display("          ❌ ACT LOAD ERROR at Addr %0d Pixel %0d: Expected %0d, Got %0d", addr, k, expected_val, act_doutb[k*16 +: 16]);
                            err_load = err_load + 1;
                        end
                    end
                end
                addr = addr + 1;
            end
        end
        @(posedge CLK); tb_act_enb = 0;
        
        if (err_load == 0) $display("          ✅ BRAM Load Verification Passed!");

        // ---------------------------------------------------------
        // PHASE 3: START HARDWARE EXECUTION
        // ---------------------------------------------------------
        $display("\n[PHASE 3] Handing control to RTL and waiting for execution...");
        tb_active = 0; 
        @(posedge CLK); START_CONTROLLER = 1;
        @(posedge CLK); START_CONTROLLER = 0;

        wait(halt == 1);
        $display("          ✅ Controller Reached HALT State!");

        // ---------------------------------------------------------
        // PHASE 4: VERIFY CONV & CAPTURE INTERMEDIATE OUTPUT
        // ---------------------------------------------------------
        $display("\n[PHASE 4] Verifying Conv Layer & Saving Actual Output...");
        tb_active = 1; addr = 140; 
        for (c = 0; c < 6; c = c + 1) begin
            for (h = 0; h < 24; h = h + 1) begin
                for (w = 0; w < 24; w = w + 8) begin 
                    @(posedge CLK); tb_act_enb = 1; tb_act_addrb = addr;
                    @(posedge CLK); @(posedge CLK); #1; 
                    for (k = 0; k < 8; k = k + 1) begin
                        if (w + k < 24) begin
                            in_r = h + 2;
                            in_c = (w + k) + 2;
                            expected_val = mnist_img[in_r * 28 + in_c] * (c + 1);    
                            // Add saturation clamp to match the RTL's Q1.5.10 limits!
                            if (expected_val > 32767) expected_val = 32767;
                            else if (expected_val < -32768) expected_val = -32768;
                            
                            conv_out_mem[(c * 24 * 24) + (h * 24) + (w + k)] = act_doutb[k*16 +: 16];
                            
                            if (act_doutb[k*16 +: 16] !== expected_val) begin
                                $display("          ❌ CONV ERROR at Addr %0d Pixel %0d: Expected %0d, Got %0d", addr, k, expected_val, act_doutb[k*16 +: 16]);
                                err_conv = err_conv + 1;
                            end
                        end
                    end
                    addr = addr + 1;
                end
            end
        end
        @(posedge CLK); tb_act_enb = 0;
        if (err_conv == 0) $display("          ✅ Convolution Verification Passed!");

        // ---------------------------------------------------------
        // PHASE 5: VERIFY MAXPOOL (DECOUPLED GOLDEN MATH)
        // ---------------------------------------------------------
        $display("\n[PHASE 5] Verifying MaxPool against ACTUAL captured Conv data...");
        addr = 600; 
        for (c = 0; c < 6; c = c + 1) begin
            for (h = 0; h < 12; h = h + 1) begin
                for (w = 0; w < 12; w = w + 8) begin 
                    @(posedge CLK); tb_act_enb = 1; tb_act_addrb = addr;
                    @(posedge CLK); @(posedge CLK); #1; 
                    for (k = 0; k < 8; k = k + 1) begin
                        if (w + k < 12) begin
                            base_idx = (c * 24 * 24) + ((h * 2) * 24) + ((w + k) * 2);
                            val0 = conv_out_mem[base_idx];
                            val1 = conv_out_mem[base_idx + 1];
                            val2 = conv_out_mem[base_idx + 24];
                            val3 = conv_out_mem[base_idx + 25];
                            
                            expected_val = max4(val0, val1, val2, val3);
                            
                            if (act_doutb[k*16 +: 16] !== expected_val) begin
                                $display("          ❌ POOL ERROR at Addr %0d Pixel %0d: Expected %0d, Got %0d", addr, k, expected_val, act_doutb[k*16 +: 16]);
                                err_pool = err_pool + 1;
                            end
                        end
                    end
                    addr = addr + 1;
                end
            end
        end
        @(posedge CLK); tb_act_enb = 0;
        if (err_pool == 0) $display("          ✅ MaxPool Decoupled Verification Passed!");

        // ---------------------------------------------------------
        // FINAL RESULTS
        // ---------------------------------------------------------
        $display("\n=======================================================");
        if (err_load == 0 && err_conv == 0 && err_pool == 0)
            $display("   🚀 FULL NETWORK VERIFICATION PASSED! 0 ERRORS.");
        else
            $display("   💥 NETWORK VERIFICATION FAILED.");
        $display("=======================================================");
        $finish;
    end
endmodule