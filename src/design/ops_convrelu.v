`timescale 1ns / 1ps

//////////////// PE ELEMENT (DSP MACRO) ////////////////

/*
    Single Processing Element mapped to a DSP48E1 slice.
    Performs: PRODUCT = ACT_IN * WGT_IN (registered output).
    Q1.5.10 x Q1.5.10 = Q2.10.20 (32-bit signed product, 20 fractional bits).
*/

(* use_dsp = "yes" *)
module pe_element (
    input  wire        CLK,
    input  wire signed [15:0] ACT_IN,
    input  wire signed [15:0] WGT_IN,
    input  wire        COMPUTE_EN,
    output reg  signed [31:0] PRODUCT
);
    always @(posedge CLK) begin
        if (COMPUTE_EN)
            PRODUCT <= ACT_IN * WGT_IN;
        // else: hold last value (critical for pipeline drain -
        // s1 stage captures one clock after compute_en falls)
    end
endmodule

//////////////// OPS_CONVRELU TOP MODULE ////////////////

module ops_convrelu #(
    parameter MAX_FMAP_DIM     = 32, 
    parameter MAX_KERNEL_WIDTH = 14, 
    parameter MIN_KERNEL_WIDTH = 2,  
    parameter MAX_OUT_WIDTH    = 28  
)(
    input  wire        CLK_IN,
    input  wire        RESET,
    input  wire        MODULE_EN,

    // Controller handshake
    input  wire        EXT_START_OF_COMPUTE,
    output reg         EXT_END_OF_COMPUTE,

    // Input feature map
    input  wire [13:0] IN_FMAP_BASEADDR,
    input  wire [9:0]  IN_FMAP_DIM_H,
    input  wire [9:0]  IN_FMAP_DIM_W,
    input  wire [9:0]  IN_FMAP_DIM_C,

    // Weights
    input  wire [13:0] WEIGHT_BASEADDR,
    input  wire [9:0]  WEIGHT_DIM_H,
    input  wire [9:0]  WEIGHT_DIM_W,
    input  wire [9:0]  WEIGHT_DIM_C,
    input  wire [3:0]  NUM_FILTERS,

    // Output feature map
    input  wire [13:0] OUT_FMAP_BASEADDR,
    input  wire [9:0]  OUT_FMAP_DIM_H,
    input  wire [9:0]  OUT_FMAP_DIM_W,
    input  wire [9:0]  OUT_FMAP_DIM_C,

    // Convolution parameters
    input  wire [7:0]  STRIDE,
    input  wire        RELU_EN,  // ADDED: Hardware ReLU Enable Flag

    // Activation BRAM - Port A (write)
    output reg         BRAM_act_ENA,
    output reg         BRAM_act_WEA,
    output reg  [13:0] BRAM_act_ADDRA,
    output reg  [127:0] BRAM_act_DINA,

    // Activation BRAM - Port B (read)
    output reg         BRAM_act_ENB,
    output reg  [13:0] BRAM_act_ADDRB,
    input  wire [127:0] BRAM_act_DOUTB,
    
    // Weights BRAM - Read Only Port
    output reg         BRAM_wgt_ENA,
    output wire        BRAM_wgt_WEA,      
    output reg  [13:0] BRAM_wgt_ADDRA,  
    output wire [15:0] BRAM_wgt_DINA,    
    input  wire [15:0] BRAM_wgt_DOUTA 
);

    //////////////// CLOCK GATING ////////////////

    wire CLK;

    BUFGCE u_clock_gating_buffer (
        .O(CLK),
        .CE(MODULE_EN | RESET),    // Clock enable input (synchronous to clk), enable clk during reset
        .I(CLK_IN)
    );

    //////////////// WEIGHT BRAM TIE-OFFS ////////////////

    assign BRAM_wgt_WEA  = 1'b0;
    assign BRAM_wgt_DINA = 16'd0;

    //////////////// PARAMETERS AND LOCALPARAMS ////////////////

    /*
        PE array sizing:
        - NUM_PE_ROWS = MAX_OUT_WIDTH * MAX_KERNEL_WIDTH
          Each output row needs MAX_KERNEL_WIDTH PE rows (one per kernel row).
          MAX_OUT_WIDTH output rows = worst-case output spatial dim.
        - Total DSPs = NUM_PE_ROWS * MAX_KERNEL_WIDTH.
    */

    localparam NUM_PE_ROWS = MAX_OUT_WIDTH * MAX_KERNEL_WIDTH;

    // BRAM interface
    localparam BRAM_LATENCY = 2;

    // FSM states
    localparam S_IDLE       = 4'd0,
               S_INIT_FILT  = 4'd1,
               S_LOAD       = 4'd2,
               S_COMPUTE    = 4'd3,
               S_PIPE_DRAIN = 4'd4,
               S_CHAN_INC   = 4'd5,
               S_WRITE_INIT = 4'd6,
               S_WRITE      = 4'd7,
               S_WRITE_FLUSH= 4'd8,
               S_FILT_INC   = 4'd9,
               S_DONE       = 4'd10;

    // Activation load sub-FSM states
    localparam AL_CLEAR   = 3'd0,
               AL_ADDR    = 3'd1,
               AL_WAIT    = 3'd2,
               AL_CAPTURE = 3'd3,
               AL_BCAST   = 3'd4,
               AL_DONE    = 3'd5;

    // Weight load sub-FSM states
    localparam WL_ADDR    = 3'd0,
               WL_WAIT    = 3'd1,
               WL_CAPTURE = 3'd2,
               WL_BCAST   = 3'd3,
               WL_DONE    = 3'd4;

    //////////////// RUNTIME ADDRESS MATH ////////////////

    wire [13:0] words_per_act_row;
    assign words_per_act_row = (IN_FMAP_DIM_W[2:0] == 0)
                                ? {4'd0, IN_FMAP_DIM_W[9:3]}
                                : ({4'd0, IN_FMAP_DIM_W[9:3]} + 14'd1);

    wire [13:0] words_per_act_chan;
    assign words_per_act_chan = words_per_act_row * IN_FMAP_DIM_H;

    wire [13:0] words_per_out_row;
    assign words_per_out_row = (OUT_FMAP_DIM_W[2:0] == 0)
                                ? {4'd0, OUT_FMAP_DIM_W[9:3]}
                                : ({4'd0, OUT_FMAP_DIM_W[9:3]} + 14'd1);

    wire [13:0] words_per_out_chan;
    assign words_per_out_chan = words_per_out_row * OUT_FMAP_DIM_H;

    wire [13:0] wgts_per_chan;
    assign wgts_per_chan = WEIGHT_DIM_H * WEIGHT_DIM_W;

    wire [13:0] wgts_per_filt;
    assign wgts_per_filt = wgts_per_chan * WEIGHT_DIM_C;

    //////////////// PE STORAGE (SPADS) BEGIN ////////////////

    /*
        Weight spad: NUM_PE_ROWS rows x MAX_KERNEL_WIDTH elements, 16-bit signed.
        Activation spad: NUM_PE_ROWS rows x MAX_FMAP_DIM elements, 16-bit signed.
                          Acts as a left-shift register during COMPUTE.
        Line buffers: shared buses for broadcast loading from BRAMs.
    */

    reg signed [15:0] wgt_spad  [0:NUM_PE_ROWS-1][0:MAX_KERNEL_WIDTH-1];
    reg signed [15:0] act_spad  [0:NUM_PE_ROWS-1][0:MAX_FMAP_DIM-1];

    reg signed [15:0] line_act_buf [0:MAX_FMAP_DIM-1];
    reg signed [15:0] line_wgt_buf [0:MAX_KERNEL_WIDTH-1];

    //////////////// PE STORAGE (SPADS) END   ////////////////

    //////////////// PARTIAL SUM STORAGE BEGIN ////////////////

    /*
        Accumulates results across input channels.
        32-bit signed, 20 fractional bits (inherited from Q1.5.10 x Q1.5.10 products).
        Dimensions: MAX_OUT_WIDTH rows x MAX_OUT_WIDTH columns.
    */

    reg signed [31:0] psum [0:MAX_OUT_WIDTH-1][0:MAX_OUT_WIDTH-1];

    //////////////// PARTIAL SUM STORAGE END   ////////////////

    //////////////// PE ARRAY INSTANTIATION BEGIN ////////////////

    wire signed [31:0] pe_product [0:NUM_PE_ROWS-1][0:MAX_KERNEL_WIDTH-1];
    reg compute_en;

    genvar gr, gk;
    generate
        for (gr = 0; gr < NUM_PE_ROWS; gr = gr + 1) begin : gen_pe_rows
            for (gk = 0; gk < MAX_KERNEL_WIDTH; gk = gk + 1) begin : gen_pe_cols
                pe_element u_pe (
                    .CLK        (CLK),
                    .ACT_IN     (act_spad[gr][gk]),
                    .WGT_IN     (wgt_spad[gr][gk]),
                    .COMPUTE_EN (compute_en),
                    .PRODUCT    (pe_product[gr][gk])
                );
            end
        end
    endgenerate

    //////////////// PE ARRAY INSTANTIATION END   ////////////////

    //////////////// HORIZONTAL REDUCTION BEGIN ////////////////

    /*
        For each PE row, sum all MAX_KERNEL_WIDTH products.
        Unused PEs have zero weights so contribute nothing.
        Synthesis will infer an adder tree.
    */

    wire signed [31:0] row_psum [0:NUM_PE_ROWS-1];

    generate
        for (gr = 0; gr < NUM_PE_ROWS; gr = gr + 1) begin : gen_hsum
            reg signed [31:0] hsum_comb;
            integer hi;
            always @(*) begin
                hsum_comb = 32'sd0;
                for (hi = 0; hi < MAX_KERNEL_WIDTH; hi = hi + 1)
                    hsum_comb = hsum_comb + pe_product[gr][hi];
            end
            assign row_psum[gr] = hsum_comb;
        end
    endgenerate

    //////////////// HORIZONTAL REDUCTION END   ////////////////

    //////////////// VERTICAL REDUCTION BEGIN ////////////////

    /*
        For each output row oh, sum MAX_KERNEL_WIDTH consecutive PE row results.
        PE row group for oh: indices [oh*MAX_KERNEL_WIDTH .. (oh+1)*MAX_KERNEL_WIDTH - 1].
        Unused rows (kh >= actual WEIGHT_DIM_H) produce zero.
    */

    wire signed [31:0] col_out [0:MAX_OUT_WIDTH-1];

    generate
        for (gr = 0; gr < MAX_OUT_WIDTH; gr = gr + 1) begin : gen_vsum
            reg signed [31:0] vsum_comb;
            integer vi;
            always @(*) begin
                vsum_comb = 32'sd0;
                for (vi = 0; vi < MAX_KERNEL_WIDTH; vi = vi + 1)
                    vsum_comb = vsum_comb + row_psum[gr * MAX_KERNEL_WIDTH + vi];
            end
            assign col_out[gr] = vsum_comb;
        end
    endgenerate

    //////////////// VERTICAL REDUCTION END   ////////////////

    //////////////// LOAD MASK GENERATION BEGIN ////////////////

    /*
        Combinational masks that select which PE rows latch from
        the shared line buffers during the LOAD phase.

        PE row index r maps to:
            OH_IDX = r / MAX_KERNEL_WIDTH   (output row)
            KH_IDX = r % MAX_KERNEL_WIDTH   (kernel row)

        Activation mask:  PE row r loads when input_row == OH_IDX*STRIDE + KH_IDX.
        Weight mask:      PE row r loads when kernel_row == KH_IDX.
    */

    // Registered runtime values used by the masks
    reg [9:0] al_row;       // current input row being loaded
    reg [9:0] wl_kh;        // current kernel row being loaded

    wire [NUM_PE_ROWS-1:0] load_act_mask;
    wire [NUM_PE_ROWS-1:0] load_wgt_mask;

    generate
        for (gr = 0; gr < NUM_PE_ROWS; gr = gr + 1) begin : gen_masks
            localparam [9:0] OH_IDX = gr / MAX_KERNEL_WIDTH;
            localparam [9:0] KH_IDX = gr % MAX_KERNEL_WIDTH;

            assign load_act_mask[gr] = (OH_IDX * STRIDE + KH_IDX == al_row) &&
                                        (KH_IDX < WEIGHT_DIM_H) &&
                                        (OH_IDX < OUT_FMAP_DIM_H);

            assign load_wgt_mask[gr] = (KH_IDX == wl_kh) &&
                                        (OH_IDX < OUT_FMAP_DIM_H);
        end
    endgenerate

    //////////////// LOAD MASK GENERATION END   ////////////////

    //////////////// FSM REGISTERS ////////////////

    reg [3:0]  state;

    // filter / channel iterators
    reg [3:0]  cur_filt;
    reg [9:0]  cur_chan;
    reg        first_chan;     // high when cur_chan == 0

    // activation load sub-FSM
    reg [2:0]  al_state;
    reg [3:0]  al_word;        // word index within current row
    reg [1:0]  al_wait;
    reg [13:0] al_addr;        // running BRAM read address

    // weight load sub-FSM
    reg [2:0]  wl_state;
    reg [9:0]  wl_kw;          // column within current kernel row
    reg [1:0]  wl_wait;
    reg [13:0] wl_addr;        // running BRAM read address

    // compute pipeline
    reg [9:0]  shift_count;
    reg [9:0]  max_shift;      // = IN_FMAP_DIM_W - WEIGHT_DIM_W
    reg        s0_valid;
    reg [7:0]  s0_stride_cnt;
    reg        s0_capture;    // stride-aligned flag

    // s1 pipeline stage (1 clock behind s0)
    reg        s1_valid;
    reg        s1_capture;
    reg [9:0]  s1_ow;          // output column counter

    // s2 pipeline stage (1 clock behind s1) - registered reduction tree output
    reg        s2_valid;
    reg        s2_capture;
    reg [9:0]  s2_ow;          // delayed output column counter
    reg signed [31:0] col_out_reg [0:MAX_OUT_WIDTH-1];

    // pipe drain counter
    reg [1:0]  drain_cnt;

    // write-out phase
    reg [9:0]  wr_oh;
    reg [9:0]  wr_ow;
    reg [3:0]  wr_pack_cnt;
    reg [127:0] wr_buf;
    reg [13:0] wr_addr;

    // registered dimension products (latched once at layer start, breaks DSP chains)
    reg [13:0] reg_words_per_act_chan;
    reg [13:0] reg_wgts_per_chan;
    reg [13:0] reg_wgts_per_filt;
    reg [13:0] reg_words_per_out_chan;

    // base address accumulators (replace multiply-from-scratch with additions)
    reg [13:0] al_chan_base;   // IN_FMAP_BASEADDR + cur_chan * reg_words_per_act_chan
    reg [13:0] wl_chan_base;   // wl_filt_base + cur_chan * reg_wgts_per_chan
    reg [13:0] wl_filt_base;   // WEIGHT_BASEADDR + cur_filt * reg_wgts_per_filt
    reg [13:0] wr_filt_base;   // OUT_FMAP_BASEADDR + cur_filt * reg_words_per_out_chan

    //////////////// OUTPUT TRUNCATION + CONDITIONAL RELU ////////////////

    /*
        Fixed-point math:
          Activations and weights are Q1.5.10 (1 sign, 5 integer, 10 fractional = 16-bit).
          Product: Q1.5.10 x Q1.5.10 = 32-bit signed, 20 fractional bits.
          After accumulation (horizontal + vertical + channels), fractional
          point stays at bit 20.  No shift needed - just slice:
              output[15:0] = accumulator[25:10]
                  bit 25     -> sign (Q1)
                  bits 24:20 -> integer (Q.5.)
                  bits 19:10 -> fractional (Q..10)
        ReLU: clamp negative to zero (check sign bit) ONLY IF RELU_EN is active.
    */

    wire signed [15:0] trunc_val;
    assign trunc_val = psum[wr_oh][wr_ow][25:10];

    wire [15:0] relu_val;
    // MODIFIED: Conditionally apply ReLU based on RELU_EN parameter
    assign relu_val = (RELU_EN && trunc_val[15]) ? 16'd0 : trunc_val;

    //////////////// MAIN FSM BEGIN ////////////////

    integer ri, ki, wi, oi, oj;

    always @(posedge CLK) begin
        if (RESET) begin
            state            <= S_IDLE;
            EXT_END_OF_COMPUTE <= 0;
            compute_en       <= 0;
            BRAM_act_ENA     <= 0;
            BRAM_act_WEA     <= 0;
            BRAM_act_ENB     <= 0;
            BRAM_wgt_ENA     <= 0;
            s0_valid         <= 0;
            s1_valid         <= 0;
            s2_valid         <= 0;
        end else begin

            // defaults (active-low pulse signals)
            BRAM_act_ENA <= 0;
            BRAM_act_WEA <= 0;
            BRAM_act_ENB <= 0;
            BRAM_wgt_ENA <= 0;

            case (state)

            //////////////// IDLE ////////////////

            S_IDLE: begin
                EXT_END_OF_COMPUTE <= 0;
                if (EXT_START_OF_COMPUTE) begin
                    cur_filt <= 0;

                    // Latch combinational dimension products (breaks DSP chains)
                    reg_words_per_act_chan <= words_per_act_chan;
                    reg_wgts_per_chan      <= wgts_per_chan;
                    reg_wgts_per_filt     <= wgts_per_filt;
                    reg_words_per_out_chan <= words_per_out_chan;

                    // Initialize filter base accumulators
                    wl_filt_base <= WEIGHT_BASEADDR;
                    wr_filt_base <= OUT_FMAP_BASEADDR;

                    state    <= S_INIT_FILT;
                end
            end

            //////////////// INIT FILTER: clear spads + psum ////////////////

            S_INIT_FILT: begin
                cur_chan   <= 0;
                first_chan <= 1;

                // clear all weight spads
                for (ri = 0; ri < NUM_PE_ROWS; ri = ri + 1)
                    for (ki = 0; ki < MAX_KERNEL_WIDTH; ki = ki + 1)
                        wgt_spad[ri][ki] <= 16'sd0;

                // clear all activation spads
                for (ri = 0; ri < NUM_PE_ROWS; ri = ri + 1)
                    for (wi = 0; wi < MAX_FMAP_DIM; wi = wi + 1)
                        act_spad[ri][wi] <= 16'sd0;

                // clear partial sum buffer
                for (oi = 0; oi < MAX_OUT_WIDTH; oi = oi + 1)
                    for (oj = 0; oj < MAX_OUT_WIDTH; oj = oj + 1)
                        psum[oi][oj] <= 32'sd0;

                // prepare load sub-FSM starting addresses (using accumulators)
                al_addr      <= IN_FMAP_BASEADDR;
                al_chan_base  <= IN_FMAP_BASEADDR;
                wl_addr      <= wl_filt_base;
                wl_chan_base  <= wl_filt_base;

                // kick off both load sub-FSMs
                al_state <= AL_CLEAR;
                al_row   <= 0;
                al_word  <= 0;

                wl_state <= WL_ADDR;
                wl_kh    <= 0;
                wl_kw    <= 0;

                state <= S_LOAD;
            end

            //////////////// PARALLEL LOAD (ACT + WGT) ////////////////

            S_LOAD: begin

                // ----- ACTIVATION LOAD SUB-FSM (BRAM port B) -----

                case (al_state)

                AL_CLEAR: begin
                    // zero the line buffer before each row
                    for (wi = 0; wi < MAX_FMAP_DIM; wi = wi + 1)
                        line_act_buf[wi] <= 16'sd0;
                    al_state <= AL_ADDR;
                end

                AL_ADDR: begin
                    BRAM_act_ENB   <= 1;
                    BRAM_act_ADDRB <= al_addr;
                    al_addr  <= al_addr + 1;
                    al_wait  <= BRAM_LATENCY - 1;
                    al_state <= AL_WAIT;
                end

                AL_WAIT: begin
                    BRAM_act_ENB <= 1;
                    if (al_wait == 0)
                        al_state <= AL_CAPTURE;
                    else
                        al_wait <= al_wait - 1;
                end

                AL_CAPTURE: begin
                    // unpack 128-bit word into line buffer (8 x 16-bit pixels)
                    for (wi = 0; wi < 8; wi = wi + 1)
                        line_act_buf[al_word * 8 + wi] <= BRAM_act_DOUTB[wi*16 +: 16];

                    if (al_word == words_per_act_row - 1) begin
                        al_word  <= 0;
                        al_state <= AL_BCAST;
                    end else begin
                        al_word  <= al_word + 1;
                        al_state <= AL_ADDR;
                    end
                end

                AL_BCAST: begin
                    // broadcast line buffer to all PE rows whose mask bit is set
                    for (ri = 0; ri < NUM_PE_ROWS; ri = ri + 1)
                        if (load_act_mask[ri])
                            for (wi = 0; wi < MAX_FMAP_DIM; wi = wi + 1)
                                act_spad[ri][wi] <= line_act_buf[wi];

                    if (al_row == IN_FMAP_DIM_H - 1)
                        al_state <= AL_DONE;
                    else begin
                        al_row   <= al_row + 1;
                        al_state <= AL_CLEAR;
                    end
                end

                AL_DONE: begin
                    // sit here until weight load also finishes
                end

                default: al_state <= AL_DONE;
                endcase

                // ----- WEIGHT LOAD SUB-FSM (BRAM weight port) -----

                case (wl_state)

                WL_ADDR: begin
                    BRAM_wgt_ENA   <= 1;
                    BRAM_wgt_ADDRA <= wl_addr;
                    wl_addr  <= wl_addr + 1;
                    wl_wait  <= BRAM_LATENCY - 1;
                    wl_state <= WL_WAIT;
                end

                WL_WAIT: begin
                    BRAM_wgt_ENA <= 1;
                    if (wl_wait == 0)
                        wl_state <= WL_CAPTURE;
                    else
                        wl_wait <= wl_wait - 1;
                end

                WL_CAPTURE: begin
                    line_wgt_buf[wl_kw] <= BRAM_wgt_DOUTA;

                    if (wl_kw == WEIGHT_DIM_W - 1) begin
                        wl_kw    <= 0;
                        wl_state <= WL_BCAST;
                    end else begin
                        wl_kw    <= wl_kw + 1;
                        wl_state <= WL_ADDR;
                    end
                end

                WL_BCAST: begin
                    // broadcast line_wgt_buf to matching PE rows
                    for (ri = 0; ri < NUM_PE_ROWS; ri = ri + 1) begin
                        if (load_wgt_mask[ri]) begin
                            for (ki = 0; ki < MAX_KERNEL_WIDTH; ki = ki + 1) begin
                                if (ki < WEIGHT_DIM_W)
                                    wgt_spad[ri][ki] <= line_wgt_buf[ki];
                                else
                                    wgt_spad[ri][ki] <= 16'sd0; // Force unused weights to 0
                            end
                        end
                    end

                    if (wl_kh == WEIGHT_DIM_H - 1)
                        wl_state <= WL_DONE;
                    else begin
                        wl_kh    <= wl_kh + 1;
                        wl_state <= WL_ADDR;
                    end
                end

                WL_DONE: begin
                    // sit here until activation load also finishes
                end

                default: wl_state <= WL_DONE;
                endcase

                // ----- transition when BOTH sub-FSMs are done -----

                if (al_state == AL_DONE && wl_state == WL_DONE) begin
                    compute_en    <= 1;
                    shift_count   <= 0;
                    max_shift     <= IN_FMAP_DIM_W - WEIGHT_DIM_W;
                    s0_valid      <= 1;
                    s0_stride_cnt <= 0;
                    s0_capture    <= 1;  // position 0 is always stride-aligned
                    s1_valid      <= 0;
                    s1_ow         <= 0;
                    s2_valid      <= 0;
                    s2_ow         <= 0;
                    state         <= S_COMPUTE;
                end
            end // S_LOAD

            //////////////// COMPUTE: SHIFT + MULTIPLY + REDUCE + ACCUMULATE ////////////////

            S_COMPUTE: begin
                /*
                    Pipeline stage 0 (this clock):
                      - PEs read act_spad[0..KW-1] and multiply (registered in pe_element).
                      - Activation spad shifts left by 1 (preparing for next clock).
                      - s0_capture marks stride-aligned positions.

                    Pipeline stage 1 (next clock):
                      - PE products are valid. Adder trees produce col_out.
                      - col_out is registered into col_out_reg (breaks timing path).

                    Pipeline stage 2 (2 clocks behind s0):
                      - col_out_reg is valid. Accumulate into psum.
                */

                // S0: shift all activation spads left by 1
                if (s0_valid) begin
                    for (ri = 0; ri < NUM_PE_ROWS; ri = ri + 1) begin
                        for (wi = 0; wi < MAX_FMAP_DIM - 1; wi = wi + 1)
                            act_spad[ri][wi] <= act_spad[ri][wi + 1];
                        act_spad[ri][MAX_FMAP_DIM - 1] <= 16'sd0;
                    end
                end

                // S0: advance shift counter and stride tracking
                if (s0_valid) begin
                    if (shift_count == max_shift) begin
                        s0_valid   <= 0;
                        compute_en <= 0;
                    end else begin
                        shift_count <= shift_count + 1;
                        if (s0_stride_cnt == STRIDE - 1) begin
                            s0_stride_cnt <= 0;
                            s0_capture    <= 1;
                        end else begin
                            s0_stride_cnt <= s0_stride_cnt + 1;
                            s0_capture    <= 0;
                        end
                    end
                end

                // S1: pipeline propagation
                s1_valid   <= s0_valid;
                s1_capture <= s0_valid & s0_capture;

                // S1: register reduction tree output (breaks critical path)
                for (oi = 0; oi < MAX_OUT_WIDTH; oi = oi + 1)
                    col_out_reg[oi] <= col_out[oi];

                // S1: advance output column counter (same as before)
                if (s1_capture)
                    s1_ow <= s1_ow + 1;

                // S2: pipeline propagation
                s2_valid   <= s1_valid;
                s2_capture <= s1_capture;
                if (s1_capture)
                    s2_ow <= s1_ow;  // capture pre-increment s1_ow value

                // S2: accumulate registered col_out into partial sums
                if (s2_capture) begin
                    for (oi = 0; oi < MAX_OUT_WIDTH; oi = oi + 1) begin
                        if (first_chan)
                            psum[oi][s2_ow] <= col_out_reg[oi];
                        else
                            psum[oi][s2_ow] <= psum[oi][s2_ow] + col_out_reg[oi];
                    end
                end

                // detect end of compute pipeline (wait for s2 to drain)
                if (!s0_valid && !s1_valid && !s2_valid) begin
                    drain_cnt <= 1;
                    state     <= S_PIPE_DRAIN;
                end
            end // S_COMPUTE

            //////////////// PIPELINE DRAIN ////////////////

            S_PIPE_DRAIN: begin
                // allow one extra clock for final pipeline drain
                if (drain_cnt == 0)
                    state <= S_CHAN_INC;
                else
                    drain_cnt <= drain_cnt - 1;
            end

            //////////////// CHANNEL INCREMENT ////////////////

            S_CHAN_INC: begin
                if (cur_chan == IN_FMAP_DIM_C - 1) begin
                    // all channels done for this filter -> write output
                    wr_oh       <= 0;
                    wr_ow       <= 0;
                    wr_pack_cnt <= 0;
                    wr_buf      <= 128'd0;
                    wr_addr     <= wr_filt_base;  // uses accumulated filter base
                    state       <= S_WRITE_INIT;
                end else begin
                    // next channel: reload weights and activations
                    cur_chan   <= cur_chan + 1;
                    first_chan <= 0;

                    // Accumulate channel bases (addition only, no DSP multiply)
                    al_chan_base <= al_chan_base + reg_words_per_act_chan;
                    wl_chan_base <= wl_chan_base + reg_wgts_per_chan;

                    // set BRAM addresses for next channel using accumulated bases
                    al_addr <= al_chan_base + reg_words_per_act_chan;
                    wl_addr <= wl_chan_base + reg_wgts_per_chan;

                    al_state <= AL_CLEAR;
                    al_row   <= 0;
                    al_word  <= 0;

                    wl_state <= WL_ADDR;
                    wl_kh    <= 0;
                    wl_kw    <= 0;

                    state <= S_LOAD;
                end
            end

            //////////////// WRITE INIT: one-cycle setup ////////////////

            S_WRITE_INIT: begin
                state <= S_WRITE;
            end

            //////////////// WRITE OUTPUT: TRUNC + RELU + PACK + BRAM WRITE ////////////////

            S_WRITE: begin
                // pack current relu_val into write buffer
                wr_buf[wr_pack_cnt * 16 +: 16] <= relu_val;

                if (wr_pack_cnt == 4'd7 || wr_ow == OUT_FMAP_DIM_W - 1) begin
                    // flush buffer to BRAM
                    state <= S_WRITE_FLUSH;
                end else begin
                    wr_pack_cnt <= wr_pack_cnt + 1;
                    // advance column
                    wr_ow <= wr_ow + 1;
                end
            end

            S_WRITE_FLUSH: begin
                // write the packed buffer to activation BRAM
                BRAM_act_ENA  <= 1;
                BRAM_act_WEA  <= 1;
                BRAM_act_ADDRA <= wr_addr;

                // build final word: overwrite the last element into wr_buf
                // (it was registered in S_WRITE, now we emit the full word)
                BRAM_act_DINA <= wr_buf;

                wr_addr     <= wr_addr + 1;
                wr_pack_cnt <= 0;
                wr_buf      <= 128'd0;

                // advance to next column / row
                if (wr_ow == OUT_FMAP_DIM_W - 1) begin
                    wr_ow <= 0;
                    if (wr_oh == OUT_FMAP_DIM_H - 1)
                        state <= S_FILT_INC;
                    else begin
                        wr_oh <= wr_oh + 1;
                        state <= S_WRITE;
                    end
                end else begin
                    wr_ow <= wr_ow + 1;
                    state  <= S_WRITE;
                end
            end

            //////////////// FILTER INCREMENT ////////////////

            S_FILT_INC: begin
                if (cur_filt == NUM_FILTERS - 1)
                    state <= S_DONE;
                else begin
                    cur_filt <= cur_filt + 1;
                    // Accumulate filter bases (addition, no multiply)
                    wl_filt_base <= wl_filt_base + reg_wgts_per_filt;
                    wr_filt_base <= wr_filt_base + reg_words_per_out_chan;
                    state    <= S_INIT_FILT;
                end
            end

            //////////////// DONE ////////////////

            S_DONE: begin
                EXT_END_OF_COMPUTE <= 1;
                state <= S_IDLE;
            end

            default: state <= S_IDLE;

            endcase
        end
    end

    //////////////// MAIN FSM END ////////////////

endmodule