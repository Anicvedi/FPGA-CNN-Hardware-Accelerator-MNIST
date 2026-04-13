`timescale 1ns / 1ps

module tb_system_integration_onlymaxpool();

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
    // CONTROLLER -> MAXPOOL INTERFACE
    // ---------------------------------------------------------
    wire en_conv; 
    wire en_maxp;
    wire sop_conv; 
    wire sop_maxp;
    wire eop_conv = 1'b0; // Tied to 0 for this test
    wire eop_maxp;
    wire halt;

    // Decoded Parameter Wires
    wire [13:0] inp_act_addr, inp_wgt_addr, out_act_addr;
    wire [9:0]  inp_act_dim1, inp_act_dim2, inp_act_dim3;
    wire [9:0]  wgt_dim1, wgt_dim2, wgt_dim3;
    wire [9:0]  out_act_dim1, out_act_dim2, out_act_dim3;
    wire [7:0]  pool_dim, conv_stride;

    // ---------------------------------------------------------
    // MAXPOOL -> BRAM ACTIVATIONS INTERFACE (128-BIT)
    // ---------------------------------------------------------
    wire mp_bram_ena, mp_bram_wea;
    wire [13:0] mp_bram_addra;
    wire [127:0] mp_bram_dina;
    wire mp_bram_enb;
    wire [13:0] mp_bram_addrb;
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

    // Instruction BRAM Mux
    wire inst_ena         = tb_active ? tb_inst_ena   : ctrl_inst_ena;
    wire inst_wea         = tb_active ? tb_inst_wea   : ctrl_inst_wea;
    wire [9:0] inst_addra = tb_active ? tb_inst_addra : ctrl_inst_addra;
    wire [63:0] inst_dina = tb_active ? tb_inst_dina  : ctrl_inst_dina;

    // Activations BRAM Mux
    wire act_ena          = tb_active ? tb_act_ena   : mp_bram_ena;
    wire act_wea          = tb_active ? tb_act_wea   : mp_bram_wea;
    wire [13:0] act_addra = tb_active ? tb_act_addra : mp_bram_addra;
    wire [127:0] act_dina = tb_active ? tb_act_dina  : mp_bram_dina;
    wire act_enb          = tb_active ? tb_act_enb   : mp_bram_enb;
    wire [13:0] act_addrb = tb_active ? tb_act_addrb : mp_bram_addrb;

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

    ops_maxpool uut_maxpool (
        .CLK_IN(CLK),
        .RESET(RST),
        .MODULE_EN(en_maxp),
        .EXT_START_OF_COMPUTE(sop_maxp),
        .EXT_END_OF_COMPUTE(eop_maxp),
        
        // Mapped: DIM1=H, DIM2=W, DIM3=C
        .IN_FMAP_BASEADDR(inp_act_addr),
        .IN_FMAP_DIM_H(inp_act_dim1), 
        .IN_FMAP_DIM_W(inp_act_dim2),
        .IN_FMAP_DIM_C(inp_act_dim3),
        
        .OUT_FMAP_BASEADDR(out_act_addr),
        .OUT_FMAP_DIM_H(out_act_dim1),
        .OUT_FMAP_DIM_W(out_act_dim2),
        .OUT_FMAP_DIM_C(out_act_dim3),
        
        .POOL_KERNEL_SIZE(pool_dim),
        
        .BRAM_ena(mp_bram_ena),
        .BRAM_wea(mp_bram_wea),
        .BRAM_addra(mp_bram_addra),
        .BRAM_dina(mp_bram_dina),
        .BRAM_enb(mp_bram_enb),
        .BRAM_addrb(mp_bram_addrb),
        .BRAM_doutb(act_doutb)
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

    // ---------------------------------------------------------
    // CLOCK & TEST SEQUENCE
    // ---------------------------------------------------------
    initial begin
        CLK = 0;
        forever #5 CLK = ~CLK;
    end

    integer c, h, w, k;
    integer addr;
    integer val;
    integer expected_val;
    integer write_errors = 0;
    integer pool_errors = 0;

    initial begin
        $display("==================================================");
        $display("   STARTING 128-BIT SYSTEM INTEGRATION TEST ");
        $display("==================================================");

        // Initialize Signals
        RST = 1;
        START_CONTROLLER = 0;
        tb_active = 1; 
        
        tb_inst_ena = 0; tb_inst_wea = 0; tb_inst_addra = 0; tb_inst_dina = 0;
        tb_act_ena = 0; tb_act_wea = 0; tb_act_enb = 0; tb_act_addra = 0; tb_act_addrb = 0; tb_act_dina = 0;
        
        #100;
        @(posedge CLK);
        RST = 0;
        #20;

        // ---------------------------------------------------------
        // PHASE 1: LOAD INSTRUCTIONS
        // ---------------------------------------------------------
        $display("\n[PHASE 1] Loading Instructions into Controller BRAM...");
        
        // Memory Map for 128-bit words (8 pixels per word):
        // Input: 12x20x3 -> Width 20 = 3 addrs/row. Total = 3 * 12 * 3 = 108 addrs.
        // MP1 Out: 6x10x3 -> Width 10 = 2 addrs/row. Total = 2 * 6 * 3 = 36 addrs.
        
        // Instruction 1: MaxPool 1 (Input 12x20x3 -> Output 6x10x3)
        // Word 1: Opcode(8), In_Addr(14), Wgt_Addr(14), Out_Addr(14), Pad(14)
        @(posedge CLK); tb_inst_ena=1; tb_inst_wea=1; tb_inst_addra=0; tb_inst_dina={8'h02, 14'd0, 14'd0, 14'd108, 14'd0}; 
        // Word 2: In_H(10), In_W(10), In_C(10), Wgt_H(10), Wgt_W(10), Wgt_C(10), Pad(4)
        @(posedge CLK); tb_inst_addra=1; tb_inst_dina={10'd12, 10'd20, 10'd3, 10'd0, 10'd0, 10'd0, 4'd0};
        // Word 3: Out_H(10), Out_W(10), Out_C(10), Pool(8), Stride(8), Pad(18)
        @(posedge CLK); tb_inst_addra=2; tb_inst_dina={10'd6, 10'd10, 10'd3, 8'd2, 8'd2, 18'd0};
        
        // Instruction 2: MaxPool 2 (Input 6x10x3 -> Output 3x5x3)
        @(posedge CLK); tb_inst_addra=3; tb_inst_dina={8'h02, 14'd108, 14'd0, 14'd144, 14'd0}; 
        @(posedge CLK); tb_inst_addra=4; tb_inst_dina={10'd6, 10'd10, 10'd3, 10'd0, 10'd0, 10'd0, 4'd0};
        @(posedge CLK); tb_inst_addra=5; tb_inst_dina={10'd3, 10'd5, 10'd3, 8'd2, 8'd2, 18'd0};
        
        // Instruction 3: HALT
        @(posedge CLK); tb_inst_addra=6; tb_inst_dina={8'hFF, 56'd0};
        @(posedge CLK); tb_inst_addra=7; tb_inst_dina=64'd0;
        @(posedge CLK); tb_inst_addra=8; tb_inst_dina=64'd0;
        
        @(posedge CLK);
        tb_inst_ena = 0; tb_inst_wea = 0;
        $display("          Instruction Load Complete.");

        // ---------------------------------------------------------
        // PHASE 2: LOAD ACTIVATIONS (128-bit packed)
        // ---------------------------------------------------------
        $display("\n[PHASE 2] Loading 12x20x3 Input FMAP to Activations BRAM...");
        addr = 0;
        
        for (c = 0; c < 3; c = c + 1) begin
            for (h = 0; h < 12; h = h + 1) begin
                for (w = 0; w < 20; w = w + 8) begin // Step by 8 pixels
                    
                    // FIX: Execute data generation AFTER the posedge to align with memory write clock
                    @(posedge CLK);
                    tb_act_ena = 1;
                    tb_act_wea = 1;
                    tb_act_addra = addr;
                    tb_act_dina = 128'd0; // Clear the 128-bit word
                    
                    // Pack up to 8 pixels into the word
                    for (k = 0; k < 8; k = k + 1) begin
                        if (w + k < 20) begin
                            val = (c * 1000) + (h * 20) + (w + k) + 1; 
                            tb_act_dina[k*16 +: 16] = val; // Insert 16-bit segment
                        end
                    end
                    
                    addr = addr + 1;
                end
            end
        end
        @(posedge CLK);
        tb_act_ena = 0; tb_act_wea = 0;
        $display("          Activations Load Complete. Wrote %0d Addresses.", addr);

        // ---------------------------------------------------------
        // PHASE 3: VERIFY LOADED ACTIVATIONS (128-bit unpack)
        // ---------------------------------------------------------
        $display("\n[PHASE 3] Verifying Initial Activations in BRAM...");
        addr = 0;
        write_errors = 0;

        for (c = 0; c < 3; c = c + 1) begin
            for (h = 0; h < 12; h = h + 1) begin
                for (w = 0; w < 20; w = w + 8) begin
                    
                    @(posedge CLK); tb_act_enb = 1; tb_act_addrb = addr;
                    @(posedge CLK); @(posedge CLK); #1; 
                    
                    for (k = 0; k < 8; k = k + 1) begin
                        if (w + k < 20) begin
                            expected_val = (c * 1000) + (h * 20) + (w + k) + 1;
                            if (act_doutb[k*16 +: 16] !== expected_val) begin
                                $display("          ❌ WRITE ERROR at Addr %0d Pixel %0d: Expected %0d, Got %0d", addr, k, expected_val, act_doutb[k*16 +: 16]);
                                write_errors = write_errors + 1;
                            end
                        end
                    end
                    addr = addr + 1;
                end
            end
        end
        @(posedge CLK); tb_act_enb = 0;

        if (write_errors == 0) $display("          ✅ Input Verification Passed!");
        else begin $display("          🚨 Input Verification FAILED. Aborting."); $finish; end

        // ---------------------------------------------------------
        // PHASE 4: START CONTROLLER
        // ---------------------------------------------------------
        $display("\n[PHASE 4] Handing over BRAM control and Starting Controller...");
        tb_active = 0; 
        
        @(posedge CLK);
        START_CONTROLLER = 1;
        @(posedge CLK);
        START_CONTROLLER = 0;

        // Wait for HALT instruction to be executed
        wait(halt == 1);
        $display("          Controller Reached HALT State!");

        // ---------------------------------------------------------
        // PHASE 5: VERIFY FINAL MAXPOOL 2 OUTPUT
        // ---------------------------------------------------------
        $display("\n[PHASE 5] Verifying Final Output FMAP Data (Addr 144)...");
        tb_active = 1; 
        addr = 144; // Output of second maxpool
        pool_errors = 0;

        for (c = 0; c < 3; c = c + 1) begin
            $display("          --- Checking Channel %0d ---", c);
            for (h = 0; h < 3; h = h + 1) begin
                for (w = 0; w < 5; w = w + 8) begin // Output width is 5, so this loops once per row
                    
                    @(posedge CLK); tb_act_enb = 1; tb_act_addrb = addr;
                    @(posedge CLK); @(posedge CLK); #1; 

                    for (k = 0; k < 8; k = k + 1) begin
                        if (w + k < 5) begin
                            // A double 2x2 maxpool equals finding the max of a 4x4 block!
                            // Bottom-Right pixel of a 4x4 block logic:
                            expected_val = (c * 1000) + (((h * 4) + 3) * 20) + (((w + k) * 4) + 3) + 1;

                            if (act_doutb[k*16 +: 16] !== expected_val) begin
                                $display("          ❌ POOL ERROR at Addr %0d Pixel %0d: Expected %0d, Got %0d", addr, k, expected_val, act_doutb[k*16 +: 16]);
                                pool_errors = pool_errors + 1;
                            end else begin
                                $display("          ✅ PASS at Addr %0d Pixel %0d: Max = %0d", addr, k, act_doutb[k*16 +: 16]);
                            end
                        end
                    end
                    addr = addr + 1;
                end
            end
        end
        @(posedge CLK); tb_act_enb = 0;

        // ---------------------------------------------------------
        // FINAL RESULTS
        // ---------------------------------------------------------
        $display("==================================================");
        if (pool_errors == 0)
            $display("   🚀 FULL SYSTEM VERIFICATION PASSED! 0 ERRORS.");
        else
            $display("   💥 FULL SYSTEM VERIFICATION FAILED WITH %0d ERRORS.", pool_errors);
        $display("==================================================");
        $finish;
    end

endmodule