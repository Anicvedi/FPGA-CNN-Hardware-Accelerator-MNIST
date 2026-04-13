
`timescale 1ns / 1ps

module ops_maxpool(
    // clk, reset, module_en:
    input   CLK_IN,
    input   RESET,  // active HIGH reset
    input MODULE_EN,    // gates clk, active HIGH
    
    // control signals:

    input EXT_START_OF_COMPUTE,
    output reg EXT_END_OF_COMPUTE,

    // input activation:
    input [13:0] IN_FMAP_BASEADDR,
    input [9:0] IN_FMAP_DIM_W,
    input [9:0] IN_FMAP_DIM_H,
    input [9:0] IN_FMAP_DIM_C,

    // output activation:
    input [13:0] OUT_FMAP_BASEADDR,
    input [9:0] OUT_FMAP_DIM_W,
    input [9:0] OUT_FMAP_DIM_H,
    input [9:0] OUT_FMAP_DIM_C,

    // pooling parameters:
    input [7:0] POOL_KERNEL_SIZE,

    // activations BRAM interface:
    // port a:
    output reg BRAM_ena,
    output reg BRAM_wea,
    output reg [13:0] BRAM_addra,
    output reg [127:0] BRAM_dina,
    // port b:
    output reg BRAM_enb,
    output reg [13:0] BRAM_addrb,
    input [127:0] BRAM_doutb
    );
    
    /*
        MODULE DESCRIPTION:

        - Max Pooling operation for 3D feature maps.
        - Supports variable kernel sizes (e.g., 2x2, 3x3).
        - Stride is equal to kernel size (non-overlapping pooling).
        - A window is [POOL_KERNEL_SIZE x POOL_KERNEL_SIZE].
        - 128-bit Memory Interface: Fetches and writes 8 pixels per clock cycle.

        - The module contains a Pipelined Control and an Address Generation Unit (AGU). 
        -- The pipeline stages are as follows:
        ---- Stage 1 (AGU): Generates continuous read addresses for Word 0 and Word 1.
        ---- Stage 2 (WAIT): Internal BRAM routing delay.
        ---- Stage 3 (LATCH): Word 0 arrives and is latched into a register.
        ---- Stage 4 (COMPUTE & WRITE): Word 1 arrives. Combinational Vector Max Tree runs. 
                                        Outputs are packed into a 128-bit buffer and 
                                        written to BRAM when full or row ends.
    */

    // clock gating:

    wire CLK;

    // Using a Xilinx BUFGCE primitive for clock gating
    BUFGCE u_clock_gating_buffer (
        .O(CLK),   // Gated clock output
        .CE(MODULE_EN | RESET),    // Clock enable input (synchronous to clk), enable clk during reset
        .I(CLK_IN)     // Primary clock input
    );

    //////////////// FSM CODE BEGIN ////////////////

    // registers:
    
    // state and iterators:
    reg running;
    reg agu_fetch_w1; 
    reg [9:0] x_out, y_out, c, pool_y;
    
    // pipeline shift registers (metadata propagation):
    reg p1_valid, p2_valid, p3_valid, p4_valid;
    reg [9:0] p1_x_in, p2_x_in, p3_x_in, p4_x_in;
    reg p1_is_first_pool, p2_is_first_pool, p3_is_first_pool, p4_is_first_pool;
    reg p1_is_last_pool,  p2_is_last_pool,  p3_is_last_pool,  p4_is_last_pool;
    reg p1_is_last_x,     p2_is_last_x,     p3_is_last_x,     p4_is_last_x;
    reg p1_is_abs_last,   p2_is_abs_last,   p3_is_abs_last,   p4_is_abs_last;
    
    // local storage registers:
    reg [127:0] word0_reg;
    reg [15:0]  win_max;
    reg [127:0] out_buf;
    reg [3:0]   out_cnt;
    reg [13:0]  out_addr;

    // wires for AGU math (declared here, assigned in AGU section)
    wire [13:0] in_words_per_row;
    wire [13:0] in_words_per_chan;
    wire [9:0]  cur_x_in;
    wire [9:0]  cur_y_in;
    wire [13:0] base_offset;
    wire [13:0] word0_addr;
    wire [13:0] word1_addr;
    wire [15:0] updated_win_max;
    reg [127:0] next_out_buf;

    // state transition and clocked output assignment:
    always @(posedge CLK) begin
        if (RESET) begin
            running <= 0;
            agu_fetch_w1 <= 0;
            p1_valid <= 0;
            p2_valid <= 0;
            p3_valid <= 0;
            p4_valid <= 0;
            BRAM_enb <= 0;
            BRAM_ena <= 0;
            BRAM_wea <= 0;
            EXT_END_OF_COMPUTE <= 0;
        end else if (EXT_START_OF_COMPUTE) begin
            running <= 1;
            agu_fetch_w1 <= 0;
            EXT_END_OF_COMPUTE <= 0;
            x_out <= 0; y_out <= 0; c <= 0; pool_y <= 0;
            
            out_addr <= OUT_FMAP_BASEADDR;
            out_cnt <= 0;
            out_buf <= 0;
            
            p1_valid <= 0;
            BRAM_enb <= 1;
        end else begin
            // STAGE 1: AGU INSTRUCTION FETCH
            if (running) begin
                if (!agu_fetch_w1) begin
                    // Fetch Word 0
                    BRAM_addrb <= word0_addr;
                    p1_x_in <= cur_x_in;
                    p1_is_first_pool <= (pool_y == 0);
                    p1_is_last_pool <= (pool_y == POOL_KERNEL_SIZE - 1);
                    p1_is_last_x <= (x_out == OUT_FMAP_DIM_W - 1);
                    p1_is_abs_last <= (x_out == OUT_FMAP_DIM_W - 1) && 
                                      (y_out == OUT_FMAP_DIM_H - 1) && 
                                      (c == IN_FMAP_DIM_C - 1) && 
                                      (pool_y == POOL_KERNEL_SIZE - 1);
                    p1_valid <= 1;
                    agu_fetch_w1 <= 1;
                end else begin
                    // Fetch Word 1
                    BRAM_addrb <= word1_addr;
                    p1_valid <= 0; 
                    
                    // Advance iterators
                    if (pool_y == POOL_KERNEL_SIZE - 1) begin
                        pool_y <= 0;
                        if (x_out == OUT_FMAP_DIM_W - 1) begin
                            x_out <= 0;
                            if (y_out == OUT_FMAP_DIM_H - 1) begin
                                y_out <= 0;
                                if (c == IN_FMAP_DIM_C - 1) begin
                                    running <= 0; 
                                end else begin
                                    c <= c + 1;
                                end
                            end else begin
                                y_out <= y_out + 1;
                            end
                        end else begin
                            x_out <= x_out + 1;
                        end
                    end else begin
                        pool_y <= pool_y + 1;
                    end
                    
                    agu_fetch_w1 <= 0;
                end
            end else begin
                p1_valid <= 0;
            end
            
            if (!EXT_START_OF_COMPUTE) begin
                BRAM_enb <= running | p1_valid | p2_valid | p3_valid;
            end
            
            // STAGE 2: PIPELINE WAIT
            p2_valid         <= p1_valid;
            p2_x_in          <= p1_x_in;
            p2_is_first_pool <= p1_is_first_pool;
            p2_is_last_pool  <= p1_is_last_pool;
            p2_is_last_x     <= p1_is_last_x;
            p2_is_abs_last   <= p1_is_abs_last;
            
            // STAGE 3: BRAM LATCH W0
            p3_valid         <= p2_valid;
            p3_x_in          <= p2_x_in;
            p3_is_first_pool <= p2_is_first_pool;
            p3_is_last_pool  <= p2_is_last_pool;
            p3_is_last_x     <= p2_is_last_x;
            p3_is_abs_last   <= p2_is_abs_last;
            
            if (p3_valid) begin
                word0_reg <= BRAM_doutb;
            end
            
            // STAGE 4: WRITEBACK PIPELINE
            p4_valid         <= p3_valid;
            p4_x_in          <= p3_x_in;
            p4_is_first_pool <= p3_is_first_pool;
            p4_is_last_pool  <= p3_is_last_pool;
            p4_is_last_x     <= p3_is_last_x;
            p4_is_abs_last   <= p3_is_abs_last;
            
            if (p4_valid) begin
                win_max <= updated_win_max;
                
                if (p4_is_last_pool) begin
                    out_buf <= next_out_buf;
                    
                    if (out_cnt == 7 || p4_is_last_x) begin
                        BRAM_wea <= 1;
                        BRAM_ena <= 1;
                        BRAM_addra <= out_addr;
                        BRAM_dina <= next_out_buf; 
                        
                        out_addr <= out_addr + 1;
                        out_cnt <= 0;
                    end else begin
                        BRAM_wea <= 0;
                        BRAM_ena <= 0;
                        out_cnt <= out_cnt + 1;
                    end
                end else begin
                    BRAM_wea <= 0;
                    BRAM_ena <= 0;
                end
                
                if (p4_is_abs_last) begin
                    EXT_END_OF_COMPUTE <= 1;
                end
                
            end else begin
                BRAM_wea <= 0;
                BRAM_ena <= 0;
                if (EXT_END_OF_COMPUTE) EXT_END_OF_COMPUTE <= 0;
            end
        end
    end

    //////////////// FSM CODE END   ////////////////

    /*
    //////////////// DEBUG / PRINT STATE ///////////

    always @(posedge CLK) begin
        // Debug pipeline flow if needed
    end
    
    ////////////////////////////////////////////////
    */

    //////////////// AGU CODE BEGIN ////////////////

    // memory stride math:
    assign in_words_per_row = (IN_FMAP_DIM_W[2:0] == 0) ? (IN_FMAP_DIM_W >> 3) : ((IN_FMAP_DIM_W >> 3) + 1);
    assign in_words_per_chan = in_words_per_row * IN_FMAP_DIM_H;

    // input address generation:
    assign cur_x_in = x_out * POOL_KERNEL_SIZE;
    assign cur_y_in = y_out * POOL_KERNEL_SIZE + pool_y;
    assign base_offset = (c * in_words_per_chan) + (cur_y_in * in_words_per_row);
    
    assign word0_addr = IN_FMAP_BASEADDR + base_offset + (cur_x_in >> 3);
    assign word1_addr = word0_addr + 1;

    // combinational 256-bit sliding window logic:
    wire [255:0] concat_row = {BRAM_doutb, word0_reg}; 
    wire [4:0] pixel_offset = p4_x_in[2:0];
    wire [255:0] shifted_row = concat_row >> (pixel_offset * 16);

    // parallel max tree inputs:
    wire [15:0] p0 = shifted_row[15:0];
    wire [15:0] p1 = (POOL_KERNEL_SIZE > 1) ? shifted_row[31:16] : 16'h0000;
    wire [15:0] p2 = (POOL_KERNEL_SIZE > 2) ? shifted_row[47:32] : 16'h0000;
    wire [15:0] p3 = (POOL_KERNEL_SIZE > 3) ? shifted_row[63:48] : 16'h0000;
    wire [15:0] p4 = (POOL_KERNEL_SIZE > 4) ? shifted_row[79:64] : 16'h0000;
    wire [15:0] p5 = (POOL_KERNEL_SIZE > 5) ? shifted_row[95:80] : 16'h0000;
    wire [15:0] p6 = (POOL_KERNEL_SIZE > 6) ? shifted_row[111:96] : 16'h0000;
    wire [15:0] p7 = (POOL_KERNEL_SIZE > 7) ? shifted_row[127:112]: 16'h0000;

    // parallel max tree comparators:
    wire [15:0] m01 = (p0 > p1) ? p0 : p1;
    wire [15:0] m23 = (p2 > p3) ? p2 : p3;
    wire [15:0] m45 = (p4 > p5) ? p4 : p5;
    wire [15:0] m67 = (p6 > p7) ? p6 : p7;
    wire [15:0] m0123 = (m01 > m23) ? m01 : m23;
    wire [15:0] m4567 = (m45 > m67) ? m45 : m67;
    wire [15:0] row_max = (m0123 > m4567) ? m0123 : m4567;

    // vertical accumulation:
    assign updated_win_max = (p4_is_first_pool) ? row_max : ((row_max > win_max) ? row_max : win_max);

    // combinational output buffer builder:
    always @(*) begin
        next_out_buf = out_buf;
        if (out_cnt == 0) next_out_buf = 128'd0; 
        next_out_buf[out_cnt * 16 +: 16] = updated_win_max;
    end

    //////////////// AGU CODE END   ////////////////

endmodule
