`timescale 1ns / 1ps

module accelerator_TOP(
    input  wire        CLK_IN,
    input  wire        RESET_IN,
    
    // UART
    input  wire        UART_RX_ASYNC,
    output wire        UART_TX,

    // 7-segment display
    //output wire [6:0] SEG7_SEG,
    //output wire [3:0] SEG7_ANODE,
    
    // LED indicators
    output wire LED_OPS_BUSY,
    output wire LED_OPS_DONE,
    output wire LED_OPS_DATARX,
    output wire LED_IDLE,
    
    // DISCRETE LED DISPLAY FOR DIGIT
    output wire [3:0] CNN_DETECTED_DIGIT,
    
    // BAUD RATE SELECT
    input wire [1:0] BAUD_SELECT
);

// =========================================================
    // 0. CLOCK & RESET GENERATION
    // =========================================================
    wire CLK;
    wire RESET;
    wire locked_status; 

    clk_wiz_0 mmcm_100_to_70MHz (
        .clk_in1(CLK_IN),
        .clk_out1(CLK),
        .reset(RESET_IN),      
        .locked(locked_status)  
    );

    // This stays exactly the same! 
    // You still need to invert locked_status for your internal modules.
    assign RESET = ~locked_status;
    
    wire [15:0] CNN_RESULT_wire;
    assign CNN_DETECTED_DIGIT = CNN_RESULT_wire[3:0] ;

    // =========================================================
    // 0. SYNCHRONIZER FOR ASYNC UART
    // =========================================================
    
    wire UART_RX_SYNC;

    synchronizer_2stage uart_synch (
        .clk(CLK), 
        .rst(RESET),                     
        .async_sig_in(UART_RX_ASYNC), 
        .sync_sig_out(UART_RX_SYNC)
    );
    
    // =========================================================
    // 1. SYSTEM CONTROL WIRES
    // =========================================================
    wire start_cnn;       
    wire cnn_busy;        
    wire halt;            
    wire latch_data_en;
    wire is_receiving; // Tracks UART to BRAM writing state   

    // Tie off unused TX line to UART Idle state (High)
    assign UART_TX = 1'b1;

    // =========================================================
    // NEW LED LOGIC
    // =========================================================
    assign LED_OPS_BUSY   = cnn_busy;
    assign LED_OPS_DONE   = halt;
    assign LED_OPS_DATARX = is_receiving;
    assign LED_IDLE       = ~(LED_OPS_BUSY | LED_OPS_DONE | LED_OPS_DATARX);

    // =========================================================
    // 2. CONTROLLER CONFIGURATION BUS
    // =========================================================
    wire en_conv, en_maxp, en_class;
    wire sop_conv, sop_maxp, sop_class;
    wire eop_conv, eop_maxp, eop_class;

    wire [13:0] inp_act_addr, inp_wgt_addr, out_act_addr;
    wire [9:0]  inp_act_dim1, inp_act_dim2, inp_act_dim3;
    wire [9:0]  wgt_dim1, wgt_dim2, wgt_dim3;
    wire [9:0]  out_act_dim1, out_act_dim2, out_act_dim3;
    wire [7:0]  pool_dim, conv_stride;
    wire [3:0]  no_of_filter;
    wire        relu_en;

    // =========================================================
    // 3. INTERNAL BRAM BUSES
    // =========================================================
    
    // Instructions (Controller Only)
    wire        ctrl_inst_ena, ctrl_inst_wea;
    wire [9:0]  ctrl_inst_addra;
    wire [63:0] ctrl_inst_dina, inst_douta;

    // Weights (Conv Only)
    wire        conv_wgt_ena, conv_wgt_wea;
    wire [13:0] conv_wgt_addra;
    wire [15:0] conv_wgt_dina, wgt_douta;

    // Activations - Port A (Write Port)
    wire        host_act_ena, host_act_wea;
    wire [13:0] host_act_addra;
    wire [127:0] host_act_dina;

    wire        conv_act_ena, conv_act_wea;
    wire [13:0] conv_act_addra;
    wire [127:0] conv_act_dina;

    wire        mp_act_ena, mp_act_wea;
    wire [13:0] mp_act_addra;
    wire [127:0] mp_act_dina;

    wire        cls_act_ena, cls_act_wea;
    wire [13:0] cls_act_addra;
    wire [127:0] cls_act_dina;

    // Activations - Port B (Read Port)
    wire [127:0] act_doutb;
    wire        conv_act_enb;
    wire [13:0] conv_act_addrb;
    
    wire        mp_act_enb;
    wire [13:0] mp_act_addrb;
    
    wire        cls_act_enb;
    wire [13:0] cls_act_addrb;

    wire        seg7_act_enb, seg7_busy;
    wire [13:0] seg7_act_addrb;

    // =========================================================
    // 4. BRAM MULTIPLEXERS (Arbitration)
    // =========================================================
    
    // Activations BRAM Port A (Write)
    // Priority: Conv -> MaxPool -> Classifier -> Default to UART Host
    wire        act_ena   = en_conv  ? conv_act_ena   : 
                            en_maxp  ? mp_act_ena     : 
                            en_class ? cls_act_ena    : host_act_ena;

    wire        act_wea   = en_conv  ? conv_act_wea   : 
                            en_maxp  ? mp_act_wea     : 
                            en_class ? cls_act_wea    : host_act_wea;

    wire [13:0] act_addra = en_conv  ? conv_act_addra : 
                            en_maxp  ? mp_act_addra   : 
                            en_class ? cls_act_addra  : host_act_addra;

    wire [127:0] act_dina = en_conv  ? conv_act_dina  : 
                            en_maxp  ? mp_act_dina    : 
                            en_class ? cls_act_dina   : host_act_dina;

    // Activations BRAM Port B (Read)
    // Priority: Seg7 Display -> Conv -> MaxPool -> Classifier
    wire        act_enb   = seg7_busy ? seg7_act_enb   : 
                            en_conv   ? conv_act_enb   : 
                            en_maxp   ? mp_act_enb     : 
                            en_class  ? cls_act_enb    : 1'b0;

    wire [13:0] act_addrb = seg7_busy ? seg7_act_addrb : 
                            en_conv   ? conv_act_addrb : 
                            en_maxp   ? mp_act_addrb   : 
                            en_class  ? cls_act_addrb  : 14'd0;

    // =========================================================
    // 5. MODULE INSTANTIATIONS
    // =========================================================

    // UART Image Loader
    serial_to_bram u_host_if (
        .CLK(CLK), 
        .RESET(RESET),
        .UART_RX(UART_RX_SYNC),
        .CNN_BUSY(cnn_busy),
        .BAUD_SELECT(BAUD_SELECT),
        
        .START_CNN(start_cnn),
        .IS_RECEIVING(is_receiving), // Wired to LED_OPS_DATARX
        
        .BRAM_act_ENA(host_act_ena),   
        .BRAM_act_WEA(host_act_wea),   
        .BRAM_act_ADDRA(host_act_addra),   
        .BRAM_act_DINA(host_act_dina)
    );

    // Neural Network Controller
    controller u_ctrl (
        .CLK(CLK), 
        .RST(RESET), 
        .START_CONTROLLER(start_cnn),
        
        .ENA(ctrl_inst_ena), 
        .WEA(ctrl_inst_wea), 
        .ADDRA(ctrl_inst_addra), 
        .DINA(ctrl_inst_dina), 
        .DOUTA(inst_douta),
        
        .EN_CONV(en_conv),     .EN_MAXP(en_maxp),     .EN_CLASS(en_class),
        .SOP_CONV(sop_conv),   .SOP_MAXP(sop_maxp),   .SOP_CLASS(sop_class),
        .EOP_CONV(eop_conv),   .EOP_MAXP(eop_maxp),   .EOP_CLASS(eop_class),
        
        .INP_ACT_ADDR(inp_act_addr), .INP_WGT_ADDR(inp_wgt_addr), .OUT_ACT_ADDR(out_act_addr),
        .INP_ACT_DIM1(inp_act_dim1), .INP_ACT_DIM2(inp_act_dim2), .INP_ACT_DIM3(inp_act_dim3),
        .WGT_DIM1(wgt_dim1),         .WGT_DIM2(wgt_dim2),         .WGT_DIM3(wgt_dim3),
        .OUT_ACT_DIM1(out_act_dim1), .OUT_ACT_DIM2(out_act_dim2), .OUT_ACT_DIM3(out_act_dim3),
        
        .POOL_DIM(pool_dim), 
        .CONV_STRIDE(conv_stride), 
        .NO_OF_FILTER(no_of_filter), 
        .RELU_EN(relu_en), 
        
        .LATCH_DATA_EN(latch_data_en),
        .halt(halt),
        .CNN_BUSY(cnn_busy)
    );

    // Compute Engine: Convolution + ReLU
    ops_convrelu #(
        .MAX_FMAP_DIM(28), 
        .MAX_KERNEL_WIDTH(5), 
        .MAX_OUT_WIDTH(24)
    ) u_conv (
        .CLK_IN(CLK), 
        .RESET(RESET), 
        .MODULE_EN(en_conv), 
        .EXT_START_OF_COMPUTE(sop_conv), 
        .EXT_END_OF_COMPUTE(eop_conv),
        
        .IN_FMAP_BASEADDR(inp_act_addr), .IN_FMAP_DIM_H(inp_act_dim1), .IN_FMAP_DIM_W(inp_act_dim2), .IN_FMAP_DIM_C(inp_act_dim3),
        .WEIGHT_BASEADDR(inp_wgt_addr),  .WEIGHT_DIM_H(wgt_dim1),      .WEIGHT_DIM_W(wgt_dim2),      .WEIGHT_DIM_C(wgt_dim3), .NUM_FILTERS(no_of_filter),
        .OUT_FMAP_BASEADDR(out_act_addr),.OUT_FMAP_DIM_H(out_act_dim1),.OUT_FMAP_DIM_W(out_act_dim2),.OUT_FMAP_DIM_C(out_act_dim3),
        .STRIDE(conv_stride), 
        .RELU_EN(relu_en),
        
        .BRAM_act_ENA(conv_act_ena),   .BRAM_act_WEA(conv_act_wea), .BRAM_act_ADDRA(conv_act_addra), .BRAM_act_DINA(conv_act_dina),
        .BRAM_act_ENB(conv_act_enb),   .BRAM_act_ADDRB(conv_act_addrb), .BRAM_act_DOUTB(act_doutb),
        .BRAM_wgt_ENA(conv_wgt_ena),   .BRAM_wgt_WEA(conv_wgt_wea), .BRAM_wgt_ADDRA(conv_wgt_addra), .BRAM_wgt_DINA(conv_wgt_dina), .BRAM_wgt_DOUTA(wgt_douta)
    );

    // Compute Engine: Max Pooling
    ops_maxpool u_pool (
        .CLK_IN(CLK), 
        .RESET(RESET), 
        .MODULE_EN(en_maxp), 
        .EXT_START_OF_COMPUTE(sop_maxp), 
        .EXT_END_OF_COMPUTE(eop_maxp),
        
        .IN_FMAP_BASEADDR(inp_act_addr), .IN_FMAP_DIM_W(inp_act_dim2), .IN_FMAP_DIM_H(inp_act_dim1), .IN_FMAP_DIM_C(inp_act_dim3),
        .OUT_FMAP_BASEADDR(out_act_addr),.OUT_FMAP_DIM_W(out_act_dim2),.OUT_FMAP_DIM_H(out_act_dim1),.OUT_FMAP_DIM_C(out_act_dim3),
        .POOL_KERNEL_SIZE(pool_dim), 
        
        .BRAM_ena(mp_act_ena), .BRAM_wea(mp_act_wea), .BRAM_addra(mp_act_addra), .BRAM_dina(mp_act_dina),
        .BRAM_enb(mp_act_enb), .BRAM_addrb(mp_act_addrb), .BRAM_doutb(act_doutb)
    );

    // Compute Engine: Classifier (ArgMax)
    ops_classifier u_cls (
        .CLK_IN(CLK), 
        .RESET(RESET), 
        .MODULE_EN(en_class), 
        .EXT_START_OF_COMPUTE(sop_class), 
        .EXT_END_OF_COMPUTE(eop_class),
        
        .INPUT_BASE_ADDR(inp_act_addr), 
        .INPUT_SIZE(inp_act_dim1), 
        .OUT_ACT_ADDR(out_act_addr),
        
        .BRAM_act_ENA(cls_act_ena), .BRAM_act_WEA(cls_act_wea), .BRAM_act_ADDRA(cls_act_addra), .BRAM_act_DINA(cls_act_dina),
        .BRAM_act_ENB(cls_act_enb), .BRAM_act_ADDRB(cls_act_addrb), .BRAM_act_DOUTB(act_doutb)
    );

    // Output Interface: 7-Segment Display Driver
    seg7_driver u_seg7 (
        .CLK(CLK), 
        .RESET(RESET),
        .LATCH_DATA_EN(latch_data_en),
        
        .BRAM_act_ENB(seg7_act_enb),
        .BRAM_act_ADDRB(seg7_act_addrb),
        .BRAM_act_DOUTB(act_doutb),
        
        .SEG7_SEG(),        // was .SEG7_SEG(SEG7_SEG)
        .SEG7_ANODE(),      // was .SEG7_ANODE(SEG7_ANODE)
        
        .CNN_RESULT(CNN_RESULT_wire), // Ignored at top level (visualized via 7-seg physical pins)
        .BUSY(seg7_busy)
    );

    // =========================================================
    // 6. BRAM WRAPPERS
    // =========================================================
    
    // Instruction Memory (Read/Write by Controller)
    bram_instructions_wrapper u_inst_mem (
        .CLK(CLK), 
        .ENA(ctrl_inst_ena), 
        .WEA(ctrl_inst_wea), 
        .ADDRA(ctrl_inst_addra), 
        .DINA(ctrl_inst_dina), 
        .DOUTA(inst_douta)
    );

    // Weights Memory (Read Only by Conv Layer)
    bram_weights_wrapper u_wgt_mem (
        .CLK(CLK), 
        .ENA(conv_wgt_ena), 
        .WEA(conv_wgt_wea), 
        .ADDRA(conv_wgt_addra), 
        .DINA(conv_wgt_dina), 
        .DOUTA(wgt_douta)
    );

    // Activations Memory (Multiplexed Read/Write)
    bram_activations_wrapper u_act_mem (
        .CLK(CLK), 
        
        // Port A (Write Path)
        .ena(act_ena), 
        .wea(act_wea), 
        .addra(act_addra), 
        .dina(act_dina), 
        
        // Port B (Read Path)
        .enb(act_enb), 
        .addrb(act_addrb), 
        .doutb(act_doutb)
    );

endmodule