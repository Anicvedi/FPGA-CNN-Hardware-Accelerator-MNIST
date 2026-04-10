`timescale 1ns / 1ps

module controller (
    input CLK,
    input RST,
    input START_CONTROLLER,

    output reg ENA,
    output reg WEA,
    output reg [9:0] ADDRA,
    output reg [63:0] DINA,
    input [63:0] DOUTA,

    output reg EN_CONV,
    output reg EN_MAXP,
    output reg SOP_CONV,
    output reg SOP_MAXP,
    input  EOP_CONV,
    input  EOP_MAXP,

    output reg [13:0] INP_ACT_ADDR,
    output reg [13:0] INP_WGT_ADDR,
    output reg [13:0] OUT_ACT_ADDR,
    output reg [9:0] INP_ACT_DIM1,
    output reg [9:0] INP_ACT_DIM2,
    output reg [9:0] INP_ACT_DIM3,
    output reg [9:0] WGT_DIM1,
    output reg [9:0] WGT_DIM2,
    output reg [9:0] WGT_DIM3,
    output reg [9:0] OUT_ACT_DIM1,
    output reg [9:0] OUT_ACT_DIM2,
    output reg [9:0] OUT_ACT_DIM3,
    output reg [7:0] POOL_DIM,
    output reg [7:0] CONV_STRIDE,
    output reg halt
);

    localparam OP_CONV = 8'h01;
    localparam OP_MAXPOOL = 8'h02;
    localparam OP_HALT = 8'hFF;

    localparam IDLE=0, FETCH0=1, WAIT0=2, DECODE0=3,
               FETCH1=4, WAIT1=5, DECODE1=6,
               FETCH2=7, WAIT2=8, DECODE2=9,
               WAIT_OP=10, NEXT=11, ASSERT_EN = 12;

    reg [3:0] state;
    reg [9:0] pc;
    reg [1:0] m;
    reg [7:0] opcode;

    parameter BRAM_INSTR_NUM_WAIT_STATES = 2;
    
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            state <= IDLE;
            pc <= 0;
            halt <= 0;
            SOP_CONV <= 0;
            SOP_MAXP <= 0;
            EN_CONV <= 0;
            EN_MAXP <= 0;
        end else begin

            // defaults
            ENA <= 0;
            WEA <= 0;
 

            case(state)

                IDLE: begin
                    ENA <= 0;
                    if (START_CONTROLLER) begin
                        pc <= 0;
                        state <= FETCH0;
                    end
                end
                FETCH0: begin
                    EN_CONV <= 0;
                    EN_MAXP <= 0;
                    ENA <= 1;
                    ADDRA <= pc;
                    m <= BRAM_INSTR_NUM_WAIT_STATES;
                    state <= WAIT0;
                end

                WAIT0: begin
                    ENA <= 1;
                    if (m==0) state <= DECODE0;
                    else m <= m-1;
                end
                DECODE0: begin
                    ENA <= 1;
                     // Only enable here
                    if (opcode == OP_CONV)
                    EN_CONV <= 1;
                    else
                    EN_MAXP <= 1;
                    opcode <= DOUTA[63:56];
                    INP_ACT_ADDR <= DOUTA[55:42];
                    INP_WGT_ADDR <= DOUTA[41:28];
                    OUT_ACT_ADDR <= DOUTA[27:14];
                    state <= FETCH1;
                end

                FETCH1: begin
                    ENA <= 1;
                    ADDRA <= pc+1;
                    m <= BRAM_INSTR_NUM_WAIT_STATES;
                    state <= WAIT1;
                end

                WAIT1: begin
                    ENA <= 1;
                    if (m==0) state <= DECODE1;
                    else m <= m-1;
                end
                DECODE1: begin
                    ENA <= 1;
                    INP_ACT_DIM1 <= DOUTA[63:54];
                    INP_ACT_DIM2 <= DOUTA[53:44];
                    INP_ACT_DIM3 <= DOUTA[43:34];
                    WGT_DIM1 <= DOUTA[33:24];
                    WGT_DIM2 <= DOUTA[23:14];
                    WGT_DIM3 <= DOUTA[13:4];
                    state <= FETCH2;
                end

                FETCH2: begin
                    ENA <= 1;
                    ADDRA <= pc+2;
                    m <= BRAM_INSTR_NUM_WAIT_STATES;
                    state <= WAIT2;
                end

                WAIT2: begin
                    ENA <= 1;
                    if (m==0) state <= DECODE2;
                    else m <= m-1;
                end
                DECODE2: begin
                    ENA <= 1;
                    OUT_ACT_DIM1 <= DOUTA[63:54];
                    OUT_ACT_DIM2 <= DOUTA[53:44];
                    OUT_ACT_DIM3 <= DOUTA[43:34];
                    POOL_DIM     <= DOUTA[33:26];   
                    CONV_STRIDE  <= DOUTA[25:18];  
                    if (opcode == OP_HALT) begin
                    halt <= 1;
                    state <= IDLE;
                    end else begin
                    state <= ASSERT_EN;
                    end
                end


               ASSERT_EN: begin
                    ENA <= 1;
                    if (opcode == OP_CONV)
                    SOP_CONV <= 1;
                    else
                    SOP_MAXP <= 1;
                   state <= WAIT_OP;
	       end

                WAIT_OP: begin
                    ENA <= 1;
                    SOP_CONV <= 0;
                    SOP_MAXP <= 0;
                    if (EOP_CONV || EOP_MAXP) begin
                        EN_CONV <= 0;
                        EN_MAXP <= 0;
                        state <= NEXT;
                    end
                end
                NEXT: begin
                    ENA <= 1;
                    pc <= pc + 3;
                    state <= FETCH0;
                end
            endcase
        end
    end
endmodule