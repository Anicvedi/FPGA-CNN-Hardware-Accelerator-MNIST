`timescale 1ns / 1ps

module tb_ops_maxpool();

    // Clock and Reset
    reg CLK;
    reg RESET;

    // Control Signals
    reg EXT_START_OF_COMPUTE;
    wire EXT_END_OF_COMPUTE;

    // Module Parameters (Updated for 3x3 Pooling)
    reg [13:0] IN_FMAP_BASEADDR  = 14'h0000;
    reg [9:0]  IN_FMAP_DIM_W     = 10;
    reg [9:0]  IN_FMAP_DIM_H     = 6;
    reg [9:0]  IN_FMAP_DIM_C     = 3;

    reg [13:0] OUT_FMAP_BASEADDR = 14'h012C; // 300 in decimal (Input takes 180, so 300 is safe)
    reg [9:0]  OUT_FMAP_DIM_W    = 3; // <-- 10 / 3 = 3 windows across
    reg [9:0]  OUT_FMAP_DIM_H    = 2; // <-- 6 / 3 = 2 windows down
    reg [9:0]  OUT_FMAP_DIM_C    = 3;

    reg [7:0]  POOL_KERNEL_SIZE  = 3; // <-- Changed to 3

    // MaxPool BRAM Interface (Wires coming from the Maxpool Module)
    wire mp_BRAM_ena, mp_BRAM_wea;
    wire [13:0] mp_BRAM_addra;
    wire [15:0] mp_BRAM_dina;
    wire mp_BRAM_enb;
    wire [13:0] mp_BRAM_addrb;
    
    // Testbench BRAM Interface (Registers driven by the Testbench)
    reg tb_BRAM_ena, tb_BRAM_wea;
    reg [13:0] tb_BRAM_addra;
    reg [15:0] tb_BRAM_dina;
    reg tb_BRAM_enb;
    reg [13:0] tb_BRAM_addrb;

    // BRAM Wrapper Signals
    wire wrapper_ena;
    wire [0:0] wrapper_wea; // Wrapper expects 1-bit vector for WEA
    wire wrapper_enb;
    wire [13:0] wrapper_addra, wrapper_addrb;
    wire [15:0] wrapper_dina;
    wire [15:0] wrapper_doutb;

    // TB Control Flag
    reg tb_active;

    // Multiplexer: Switches BRAM control between Testbench and Maxpool module
    assign wrapper_ena   = tb_active ? tb_BRAM_ena   : mp_BRAM_ena;
    assign wrapper_wea   = tb_active ? tb_BRAM_wea   : mp_BRAM_wea;
    assign wrapper_addra = tb_active ? tb_BRAM_addra : mp_BRAM_addra;
    assign wrapper_dina  = tb_active ? tb_BRAM_dina  : mp_BRAM_dina;
    assign wrapper_enb   = tb_active ? tb_BRAM_enb   : mp_BRAM_enb;
    assign wrapper_addrb = tb_active ? tb_BRAM_addrb : mp_BRAM_addrb;

    // Instantiate Maxpool Module
    ops_maxpool uut_maxpool (
        .CLK(CLK),
        .RESET(RESET),
        .EXT_START_OF_COMPUTE(EXT_START_OF_COMPUTE),
        .EXT_END_OF_COMPUTE(EXT_END_OF_COMPUTE),
        
        .IN_FMAP_BASEADDR(IN_FMAP_BASEADDR),
        .IN_FMAP_DIM_W(IN_FMAP_DIM_W),
        .IN_FMAP_DIM_H(IN_FMAP_DIM_H),
        .IN_FMAP_DIM_C(IN_FMAP_DIM_C),
        
        .OUT_FMAP_BASEADDR(OUT_FMAP_BASEADDR),
        .OUT_FMAP_DIM_W(OUT_FMAP_DIM_W),
        .OUT_FMAP_DIM_H(OUT_FMAP_DIM_H),
        .OUT_FMAP_DIM_C(OUT_FMAP_DIM_C),
        
        .POOL_KERNEL_SIZE(POOL_KERNEL_SIZE),
        
        .BRAM_ena(mp_BRAM_ena),
        .BRAM_wea(mp_BRAM_wea),
        .BRAM_addra(mp_BRAM_addra),
        .BRAM_dina(mp_BRAM_dina),
        .BRAM_enb(mp_BRAM_enb),
        .BRAM_addrb(mp_BRAM_addrb),
        .BRAM_doutb(wrapper_doutb)
    );

    // Instantiate BRAM Wrapper
    bram_activations_wrapper uut_bram (
        .CLK(CLK),
        .ena(wrapper_ena),
        .wea(wrapper_wea),
        .addra(wrapper_addra),
        .dina(wrapper_dina),
        .enb(wrapper_enb),
        .addrb(wrapper_addrb),
        .doutb(wrapper_doutb)
    );

    // Clock Generation (10ns period)
    initial begin
        CLK = 0;
        forever #5 CLK = ~CLK;
    end

    // Test Sequence variables
    integer c, h, w;
    integer addr;
    integer val;
    integer expected_val;
    integer write_errors = 0;
    integer pool_errors = 0;

    initial begin
        $display("==================================================");
        $display("   STARTING MAXPOOL TESTBENCH (3x3 POOLING) ");
        $display("==================================================");

        // 1. Initialize Signals
        RESET = 1;
        EXT_START_OF_COMPUTE = 0;
        tb_active = 1; // TB controls BRAM
        
        // Zero all TB signals to prevent floating 'X' states during reset
        tb_BRAM_ena = 0; tb_BRAM_wea = 0; tb_BRAM_enb = 0;
        tb_BRAM_addra = 0; tb_BRAM_addrb = 0; tb_BRAM_dina = 0;
        
        #100;
        @(posedge CLK);
        RESET = 0;
        #20;

        // ---------------------------------------------------------
        // PHASE 1: WRITE TEST VECTOR TO BRAM
        // ---------------------------------------------------------
        $display("\n[PHASE 1] Writing 6x10x3 Input FMAP to BRAM (Base Addr: 0x0000)...");
        addr = IN_FMAP_BASEADDR;
        
        for (c = 0; c < IN_FMAP_DIM_C; c = c + 1) begin
            for (h = 0; h < IN_FMAP_DIM_H; h = h + 1) begin
                for (w = 0; w < IN_FMAP_DIM_W; w = w + 1) begin
                    // Logic to generate 1-60, 101-160, 201-260
                    val = (c * 100) + (h * 10) + w + 1;
                    
                    @(posedge CLK);
                    tb_BRAM_ena = 1;
                    tb_BRAM_wea = 1;
                    tb_BRAM_addra = addr;
                    tb_BRAM_dina = val;
                    addr = addr + 1;
                end
            end
        end
        @(posedge CLK);
        tb_BRAM_ena = 0; tb_BRAM_wea = 0;
        $display("          Write Phase Complete.");


        // ---------------------------------------------------------
        // PHASE 2: VERIFY WRITTEN DATA IN BRAM
        // ---------------------------------------------------------
        $display("\n[PHASE 2] Verifying Input FMAP Data in BRAM...");
        addr = IN_FMAP_BASEADDR;
        write_errors = 0;

        for (c = 0; c < IN_FMAP_DIM_C; c = c + 1) begin
            for (h = 0; h < IN_FMAP_DIM_H; h = h + 1) begin
                for (w = 0; w < IN_FMAP_DIM_W; w = w + 1) begin
                    expected_val = (c * 100) + (h * 10) + w + 1;
                    
                    // Request read
                    @(posedge CLK);
                    tb_BRAM_enb = 1;
                    tb_BRAM_addrb = addr;
                    
                    // Wait 2 clock cycles for BRAM read latency
                    @(posedge CLK); 
                    @(posedge CLK); 
                    #1; // Delay to sample post-edge
                    
                    if (wrapper_doutb !== expected_val) begin
                        $display("          ❌ WRITE ERROR at Addr %0d: Expected %0d, Got %0d", addr, expected_val, wrapper_doutb);
                        write_errors = write_errors + 1;
                    end
                    
                    addr = addr + 1;
                end
            end
        end
        @(posedge CLK);
        tb_BRAM_enb = 0;

        if (write_errors == 0)
            $display("          ✅ Input Verification Passed! BRAM contains correct test vectors.");
        else begin
            $display("          🚨 Input Verification FAILED with %0d errors. Aborting.", write_errors);
            $finish;
        end


        // ---------------------------------------------------------
        // PHASE 3: RUN MAXPOOL MODULE
        // ---------------------------------------------------------
        $display("\n[PHASE 3] Handing over BRAM control and Starting Maxpool Compute...");
        tb_active = 0; // Hand over control to Maxpool
        
        @(posedge CLK);
        EXT_START_OF_COMPUTE = 1;
        @(posedge CLK);
        EXT_START_OF_COMPUTE = 0;

        // Wait for computation to finish
        wait(EXT_END_OF_COMPUTE == 1);
        $display("          Compute Finished! EXT_END_OF_COMPUTE asserted.");


        // ---------------------------------------------------------
        // PHASE 4: VERIFY OUTPUT FMAP (2x3x3)
        // ---------------------------------------------------------
        $display("\n[PHASE 4] Verifying Output FMAP Data (Base Addr: 0x012C)...");
        tb_active = 1; // Take control back to Testbench
        addr = OUT_FMAP_BASEADDR;
        pool_errors = 0;

        for (c = 0; c < OUT_FMAP_DIM_C; c = c + 1) begin
            $display("          --- Checking Channel %0d ---", c);
            for (h = 0; h < OUT_FMAP_DIM_H; h = h + 1) begin
                for (w = 0; w < OUT_FMAP_DIM_W; w = w + 1) begin
                    
                    // Request read
                    @(posedge CLK);
                    tb_BRAM_enb = 1;
                    tb_BRAM_addrb = addr;
                    
                    // Wait 2 clock cycles for BRAM read latency
                    @(posedge CLK); 
                    @(posedge CLK); 
                    #1; 

                    // Expected Max Value Logic for 3x3 Window:
                    // Bottom-right H = (h * 3) + 2, Bottom-right W = (w * 3) + 2
                    expected_val = (c * 100) + (((h * 3) + 2) * 10) + ((w * 3) + 2) + 1;

                    if (wrapper_doutb !== expected_val) begin
                        $display("          ❌ POOL ERROR at Addr %0d: Expected %0d, Got %0d", addr, expected_val, wrapper_doutb);
                        pool_errors = pool_errors + 1;
                    end else begin
                        $display("          ✅ PASS at Addr %0d: Max = %0d", addr, wrapper_doutb);
                    end
                    
                    addr = addr + 1;
                end
            end
        end
        @(posedge CLK);
        tb_BRAM_enb = 0;

        // ---------------------------------------------------------
        // FINAL RESULTS
        // ---------------------------------------------------------
        $display("==================================================");
        if (pool_errors == 0)
            $display("   🚀 HARDWARE VERIFICATION PASSED! 0 ERRORS.");
        else
            $display("   💥 HARDWARE VERIFICATION FAILED WITH %0d ERRORS.", pool_errors);
        $display("==================================================");
        $finish;
    end

endmodule