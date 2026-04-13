`timescale 1ns / 1ps

module tb_system_integration_full_CNN_MNIST_Data();

    // Clock and Reset
    reg CLK;
    reg RST;
    reg START_CONTROLLER;

    // ---------------------------------------------------------
    // INTERFACES
    // ---------------------------------------------------------
    wire ctrl_inst_ena, ctrl_inst_wea, halt;
    wire [9:0]  ctrl_inst_addra;
    wire [63:0] ctrl_inst_dina, inst_douta;

    wire en_conv, en_maxp, en_class;
    wire sop_conv, sop_maxp, sop_class;
    wire eop_conv, eop_maxp, eop_class;

    wire [13:0] inp_act_addr, inp_wgt_addr, out_act_addr;
    wire [9:0]  inp_act_dim1, inp_act_dim2, inp_act_dim3;
    wire [9:0]  wgt_dim1, wgt_dim2, wgt_dim3;
    wire [9:0]  out_act_dim1, out_act_dim2, out_act_dim3;
    wire [7:0]  pool_dim, conv_stride;
    wire [3:0]  no_of_filter;
    wire        relu_en; // <--- ADDED: RELU Enable Wire

    // BRAM Multiplexers Control
    reg tb_active;
    reg tb_inst_ena, tb_inst_wea;
    reg [9:0] tb_inst_addra;
    reg [63:0] tb_inst_dina;
    reg tb_act_ena, tb_act_wea, tb_act_enb;
    reg [13:0] tb_act_addra, tb_act_addrb;
    reg [127:0] tb_act_dina;
    reg tb_wgt_ena, tb_wgt_wea;
    reg [13:0] tb_wgt_addra;
    reg [15:0] tb_wgt_dina;

    // Activation BRAM Wires
    wire conv_act_ena, conv_act_wea, conv_act_enb;
    wire [13:0] conv_act_addra, conv_act_addrb;
    wire [127:0] conv_act_dina;
    wire mp_bram_ena, mp_bram_wea, mp_bram_enb;
    wire [13:0] mp_bram_addra, mp_bram_addrb;
    wire [127:0] mp_bram_dina;
    wire cls_bram_ena, cls_bram_wea, cls_bram_enb;
    wire [13:0] cls_bram_addra, cls_bram_addrb;
    wire [127:0] cls_bram_dina;
    wire [127:0] act_doutb;

    // Weights BRAM Wires
    wire conv_wgt_ena, conv_wgt_wea;
    wire [13:0] conv_wgt_addra;
    wire [15:0] conv_wgt_dina, wgt_douta;

    // Bus Arbitration
    wire inst_ena = tb_active ? tb_inst_ena : ctrl_inst_ena;
    wire inst_wea = tb_active ? tb_inst_wea : ctrl_inst_wea;
    wire [9:0] inst_addra = tb_active ? tb_inst_addra : ctrl_inst_addra;
    wire [63:0] inst_dina = tb_active ? tb_inst_dina  : ctrl_inst_dina;

    wire act_ena = tb_active ? tb_act_ena : (en_conv ? conv_act_ena : (en_maxp ? mp_bram_ena : cls_bram_ena));
    wire act_wea = tb_active ? tb_act_wea : (en_conv ? conv_act_wea : (en_maxp ? mp_bram_wea : cls_bram_wea));
    wire [13:0] act_addra = tb_active ? tb_act_addra : (en_conv ? conv_act_addra : (en_maxp ? mp_bram_addra : cls_bram_addra));
    wire [127:0] act_dina = tb_active ? tb_act_dina : (en_conv ? conv_act_dina : (en_maxp ? mp_bram_dina : cls_bram_dina));
    wire act_enb = tb_active ? tb_act_enb : (en_conv ? conv_act_enb : (en_maxp ? mp_bram_enb : cls_bram_enb));
    wire [13:0] act_addrb = tb_active ? tb_act_addrb : (en_conv ? conv_act_addrb : (en_maxp ? mp_bram_addrb : cls_bram_addrb));

    wire wgt_ena = tb_active ? tb_wgt_ena : conv_wgt_ena;
    wire wgt_wea = tb_active ? tb_wgt_wea : conv_wgt_wea;
    wire [13:0] wgt_addra = tb_active ? tb_wgt_addra : conv_wgt_addra;
    wire [15:0] wgt_dina = tb_active ? tb_wgt_dina : conv_wgt_dina;

    // ---------------------------------------------------------
    // MEMORY MAP
    // ---------------------------------------------------------
    localparam IN_BASE         = 14'd0;    // 28x28 image 
    localparam WGT_BASE        = 14'd0;    // Conv1 Weights (0-149)
    localparam CONV_OUT_BASE   = 14'd112;  // 24x24 Output 
    localparam POOL_OUT_BASE   = 14'd544;  // 12x12 Output 
    localparam FC_WGT_BASE     = 14'd150;  // FC Weights (150-8789)
    localparam FC_OUT_BASE     = 14'd688;  // 1x1 Logits
    localparam FINAL_CLASS_LOC = 14'd800;  // Classified digit

    // ---------------------------------------------------------
    // INSTANTIATIONS
    // ---------------------------------------------------------
    controller uut_ctrl (
        .CLK(CLK), .RST(RST), .START_CONTROLLER(START_CONTROLLER),
        .ENA(ctrl_inst_ena), .WEA(ctrl_inst_wea), .ADDRA(ctrl_inst_addra), .DINA(ctrl_inst_dina), .DOUTA(inst_douta),
        .EN_CONV(en_conv), .EN_MAXP(en_maxp), .EN_CLASS(en_class),
        .SOP_CONV(sop_conv), .SOP_MAXP(sop_maxp), .SOP_CLASS(sop_class),
        .EOP_CONV(eop_conv), .EOP_MAXP(eop_maxp), .EOP_CLASS(eop_class),
        .INP_ACT_ADDR(inp_act_addr), .INP_WGT_ADDR(inp_wgt_addr), .OUT_ACT_ADDR(out_act_addr),
        .INP_ACT_DIM1(inp_act_dim1), .INP_ACT_DIM2(inp_act_dim2), .INP_ACT_DIM3(inp_act_dim3),
        .WGT_DIM1(wgt_dim1), .WGT_DIM2(wgt_dim2), .WGT_DIM3(wgt_dim3),
        .OUT_ACT_DIM1(out_act_dim1), .OUT_ACT_DIM2(out_act_dim2), .OUT_ACT_DIM3(out_act_dim3),
        .POOL_DIM(pool_dim), .CONV_STRIDE(conv_stride), .NO_OF_FILTER(no_of_filter), 
        .RELU_EN(relu_en), .halt(halt) // <--- ADDED: Mapped RELU_EN
    );

    ops_convrelu #(.MAX_FMAP_DIM(32), .MAX_KERNEL_WIDTH(12), .MAX_OUT_HEIGHT(24)) uut_conv (
        .CLK_IN(CLK), .RESET(RST), .MODULE_EN(en_conv), .EXT_START_OF_COMPUTE(sop_conv), .EXT_END_OF_COMPUTE(eop_conv),
        .IN_FMAP_BASEADDR(inp_act_addr), .IN_FMAP_DIM_H(inp_act_dim1), .IN_FMAP_DIM_W(inp_act_dim2), .IN_FMAP_DIM_C(inp_act_dim3),
        .WEIGHT_BASEADDR(inp_wgt_addr), .WEIGHT_DIM_H(wgt_dim1), .WEIGHT_DIM_W(wgt_dim2), .WEIGHT_DIM_C(wgt_dim3), .NUM_FILTERS(no_of_filter),
        .OUT_FMAP_BASEADDR(out_act_addr), .OUT_FMAP_DIM_H(out_act_dim1), .OUT_FMAP_DIM_W(out_act_dim2), .OUT_FMAP_DIM_C(out_act_dim3),
        .STRIDE(conv_stride), .RELU_EN(relu_en), // <--- ADDED: Mapped RELU_EN
        .BRAM_act_ENA(conv_act_ena), .BRAM_act_WEA(conv_act_wea), .BRAM_act_ADDRA(conv_act_addra), .BRAM_act_DINA(conv_act_dina),
        .BRAM_act_ENB(conv_act_enb), .BRAM_act_ADDRB(conv_act_addrb), .BRAM_act_DOUTB(act_doutb),
        .BRAM_wgt_ENA(conv_wgt_ena), .BRAM_wgt_WEA(conv_wgt_wea), .BRAM_wgt_ADDRA(conv_wgt_addra), .BRAM_wgt_DINA(conv_wgt_dina), .BRAM_wgt_DOUTA(wgt_douta)
    );

    ops_maxpool uut_pool (
        .CLK_IN(CLK), .RESET(RST), .MODULE_EN(en_maxp), .EXT_START_OF_COMPUTE(sop_maxp), .EXT_END_OF_COMPUTE(eop_maxp),
        .IN_FMAP_BASEADDR(inp_act_addr), .IN_FMAP_DIM_H(inp_act_dim1), .IN_FMAP_DIM_W(inp_act_dim2), .IN_FMAP_DIM_C(inp_act_dim3),
        .OUT_FMAP_BASEADDR(out_act_addr), .OUT_FMAP_DIM_H(out_act_dim1), .OUT_FMAP_DIM_W(out_act_dim2), .OUT_FMAP_DIM_C(out_act_dim3),
        .POOL_KERNEL_SIZE(pool_dim), .BRAM_ena(mp_bram_ena), .BRAM_wea(mp_bram_wea), .BRAM_addra(mp_bram_addra), .BRAM_dina(mp_bram_dina),
        .BRAM_enb(mp_bram_enb), .BRAM_addrb(mp_bram_addrb), .BRAM_doutb(act_doutb)
    );

    ops_classifier uut_cls (
        .CLK_IN(CLK), .RESET(RST), .MODULE_EN(en_class), .EXT_START_OF_COMPUTE(sop_class), .EXT_END_OF_COMPUTE(eop_class),
        .INPUT_BASE_ADDR(inp_act_addr), .INPUT_SIZE(inp_act_dim1), .OUT_ACT_ADDR(out_act_addr),
        .BRAM_act_ENA(cls_bram_ena), .BRAM_act_WEA(cls_bram_wea), .BRAM_act_ADDRA(cls_bram_addra), .BRAM_act_DINA(cls_bram_dina),
        .BRAM_act_ENB(cls_bram_enb), .BRAM_act_ADDRB(cls_bram_addrb), .BRAM_act_DOUTB(act_doutb)
    );

    bram_activations_wrapper uut_act_mem (.CLK(CLK), .ena(act_ena), .wea(act_wea), .addra(act_addra), .dina(act_dina), .enb(act_enb), .addrb(act_addrb), .doutb(act_doutb));
    bram_weights_wrapper uut_wgt_mem (.CLK(CLK), .ENA(wgt_ena), .WEA(wgt_wea), .ADDRA(wgt_addra), .DINA(wgt_dina), .DOUTA(wgt_douta));
    bram_instructions_wrapper uut_inst_mem (.CLK(CLK), .ENA(inst_ena), .WEA(inst_wea), .ADDRA(inst_addra), .DINA(inst_dina), .DOUTA(inst_douta));

    // ---------------------------------------------------------
    // CLOCK GENERATION
    // ---------------------------------------------------------
    initial begin
        CLK = 0; forever #5 CLK = ~CLK;
    end

    // ---------------------------------------------------------
    // TEST SEQUENCE
    // ---------------------------------------------------------
    integer img_idx, h, w, i, k, r, img_file, wgt_file;
    integer addr;
    reg [511:0] header_buf; 
    reg [255:0] filename; // String buffer for dynamic filenames
    
    integer ground_truth;
    integer predicted_class;
    integer correct_count;

    reg [15:0] test_image [0:783];      
    reg [15:0] test_kernel [0:149];     
    reg [15:0] test_fc_kernel[0:8639];  

    initial begin
        correct_count = 0;
        
        $display("==================================================");
        $display("   STARTING MULTI-IMAGE CNN BATCH TEST            ");
        $display("==================================================");

        // --- PHASE 1: LOAD WEIGHTS AND INSTRUCTIONS (ONCE) ---
        wgt_file = $fopen("model_weights.txt", "r");
        if (!wgt_file) begin
            $display("FATAL: Could not open model_weights.txt");
            $finish;
        end

        // Read Conv1 Weights
        for(i=0; i<5; i=i+1) r = $fgets(header_buf, wgt_file);
        for(i=0; i<150; i=i+1) r = $fscanf(wgt_file, "%h", test_kernel[i]);

        // Read FC Weights 
        for(i=0; i<4; i=i+1) r = $fgets(header_buf, wgt_file);
        for(i=0; i<8640; i=i+1) r = $fscanf(wgt_file, "%h", test_fc_kernel[i]);
        $fclose(wgt_file);

        // System Initialization
        RST = 1; START_CONTROLLER = 0; tb_active = 1;
        #100; @(posedge CLK); RST = 0; #20;

        // Write Weights to BRAM
        addr = WGT_BASE;
        for(i=0; i<150; i=i+1) begin
            @(negedge CLK); tb_wgt_ena = 1; tb_wgt_wea = 1; tb_wgt_addra = addr + i;
            tb_wgt_dina = test_kernel[i];
        end
        addr = FC_WGT_BASE;
        for(i=0; i<8640; i=i+1) begin
            @(negedge CLK); tb_wgt_ena = 1; tb_wgt_wea = 1; tb_wgt_addra = addr + i;
            tb_wgt_dina = test_fc_kernel[i];
        end
        @(negedge CLK); tb_wgt_ena = 0; tb_wgt_wea = 0;

        // Load Instructions
        @(posedge CLK); tb_inst_ena = 1; tb_inst_wea = 1; tb_inst_addra = 0;
        tb_inst_dina = {8'h01, IN_BASE, WGT_BASE, CONV_OUT_BASE, 14'd0}; // Conv1
        @(posedge CLK); tb_inst_addra = 1;
        tb_inst_dina = {10'd28, 10'd28, 10'd1, 10'd5, 10'd5, 10'd1, 4'd0};
        @(posedge CLK); tb_inst_addra = 2;
        // CHANGED: 14'h2000 sets bit 13 to High, enabling ReLU
        tb_inst_dina = {10'd24, 10'd24, 10'd6, 8'd0, 8'd1, 4'd6, 14'h2000}; 

        @(posedge CLK); tb_inst_addra = 3;
        tb_inst_dina = {8'h02, CONV_OUT_BASE, 14'd0, POOL_OUT_BASE, 14'd0}; // MaxPool
        @(posedge CLK); tb_inst_addra = 4;
        tb_inst_dina = {10'd24, 10'd24, 10'd6, 10'd0, 10'd0, 10'd0, 4'd0};
        @(posedge CLK); tb_inst_addra = 5;
        tb_inst_dina = {10'd12, 10'd12, 10'd6, 8'd2, 8'd2, 4'd0, 14'd0};

        @(posedge CLK); tb_inst_addra = 6;
        tb_inst_dina = {8'h01, POOL_OUT_BASE, FC_WGT_BASE, FC_OUT_BASE, 14'd0}; // FC
        @(posedge CLK); tb_inst_addra = 7;
        tb_inst_dina = {10'd12, 10'd12, 10'd6, 10'd12, 10'd12, 10'd6, 4'd0};
        @(posedge CLK); tb_inst_addra = 8;
        // LEAVE 14'd0: ReLU is disabled for FC layer (raw logits)
        tb_inst_dina = {10'd1, 10'd1, 10'd10, 8'd0, 8'd1, 4'd10, 14'd0};

        @(posedge CLK); tb_inst_addra = 9;
        tb_inst_dina = {8'h03, FC_OUT_BASE, 14'd0, FINAL_CLASS_LOC, 14'd0}; // ArgMax
        @(posedge CLK); tb_inst_addra = 10;
        tb_inst_dina = {10'd10, 54'd0};

        @(posedge CLK); tb_inst_addra = 12; tb_inst_dina = {8'hFF, 56'd0}; // HALT
        @(posedge CLK); tb_inst_ena = 0; tb_inst_wea = 0;

        $display("   [SETUP] Weights and Instructions loaded successfully.\n");


        // --- PHASE 2: BATCH EXECUTION LOOP ---
        for (img_idx = 0; img_idx < 100; img_idx = img_idx + 1) begin
            
            // Format dynamic filename targeting the new directory
            $sformat(filename, "test_images/mnist_image_%0d.txt", img_idx);
            img_file = $fopen(filename, "r");
            
            if (!img_file) begin
                $display("ERROR: Could not open %s. Skipping.", filename);
            end else begin
                
                tb_active = 1;
                
                // Read Headers & Extract Ground Truth
                r = $fgets(header_buf, img_file); // Name
                r = $fgets(header_buf, img_file); // Ground Truth line
                r = $sscanf(header_buf, "# Ground_truth_digit: %d", ground_truth);
                r = $fgets(header_buf, img_file); // Dimensions
                r = $fgets(header_buf, img_file); // Layout
                
                // Read Pixels
                for(i=0; i<784; i=i+1) r = $fscanf(img_file, "%h", test_image[i]);
                $fclose(img_file);

                // Load Image into Activations BRAM (Overwriting previous image)
                addr = IN_BASE;
                for (h = 0; h < 28; h = h + 1) begin
                    for (w = 0; w < 28; w = w + 8) begin
                        @(negedge CLK);
                        tb_act_ena = 1; tb_act_wea = 1; tb_act_addra = addr;
                        tb_act_dina = 128'd0;
                        for (k = 0; k < 8; k = k + 1) begin
                            if (w + k < 28) tb_act_dina[k*16 +: 16] = test_image[h*28 + (w+k)];
                        end
                        addr = addr + 1;
                    end
                end
                @(negedge CLK); tb_act_ena = 0; tb_act_wea = 0;

                // Execute Hardware Controller
                tb_active = 0;
                
                // Pulse RST to reset controller state machine (does not clear BRAM)
                RST = 1; #20; RST = 0; #20;
                
                @(posedge CLK); START_CONTROLLER = 1;
                @(posedge CLK); START_CONTROLLER = 0;

                // Wait for execution to finish
                begin : WAIT_FOR_HALT
                    fork
                        begin wait(halt == 1); disable WAIT_FOR_HALT; end
                        begin #10000000; $display("TIMEOUT on image %0d", img_idx); $finish; end
                    join
                end

                // Read Output
                tb_active = 1;
                @(negedge CLK); tb_act_enb = 1; tb_act_addrb = FINAL_CLASS_LOC;
                @(negedge CLK); @(negedge CLK); #1;
                predicted_class = act_doutb[15:0];
                @(negedge CLK); tb_act_enb = 0;

                // Log Result
                $display("   Image %0d -> Expected: %0d | Hardware Predicted: %0d", 
                         img_idx, ground_truth, predicted_class);
                         
                // Tally Accuracy
                if (predicted_class == ground_truth) begin
                    correct_count = correct_count + 1;
                end
            end
        end

        // --- PHASE 3: FINAL SUMMARY ---
        $display("\n==================================================");
        $display("   BATCH TEST COMPLETE ");
        $display("   Final Accuracy: %0d / 100", correct_count);
        $display("==================================================");
        $finish;
    end
endmodule