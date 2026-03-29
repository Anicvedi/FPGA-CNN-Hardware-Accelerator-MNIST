`timescale 1ns / 1ps

module ops_maxpool(
	// clk, reset:
	input 	CLK,
	input 	RESET	// active HIGH reset
	
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
    output reg [15:0] BRAM_dina,
	// port b:
    output reg BRAM_enb,
    output reg [13:0] BRAM_addrb,
    input [15:0] BRAM_doutb
    );
    
	/*
		MODULE DESCRIPTION:

		- Max Pooling operation for 3D feature maps.
		- Supports variable kernel sizes (e.g., 2x2, 3x3).
		- Stride is equal to kernel size (non-overlapping pooling).
		- A window is [POOL_KERNEL_SIZE x POOL_KERNEL_SIZE].

		- The module contains an FSM and an Address Generation Unit (AGU). 
		-- The states of the FSM are as follows:
		---- IDLE: 	Initializes variables, including win_max. Stays in this state until EXT_START_OF_COMPUTE is asserted.
		---- FILL: 	Fills pipeline (BRAM has 2 cycle latency: CLK1: set BRAM_en, BRAM_addrb, CLK2: read BRAM_doutb )
		---- COMPUTE: 	Reads BRAM data line, updates BRAM's address line (for next clock)
						Keeps on comparing currently read pixel with win_max. 
						At the end of the window, writes win_max to output activation address.
						The address for the current pixel is updated by the combinational AGU.
						The FSM stays in this state until the entire fmap is iterated over (IN_FMAP_DIM_W x IN_FMAP_DIM_H x IN_FMAP_DIM_C)
		---- FLUSH:	Reads the final pixel without setting a new address onto BRAM's address lines. Flushes the pipeline.
		---- DONE:	Asserts EXT_END_OF_COMPUTE signal to the controller

	*/

	//////////////// FSM CODE BEGIN ////////////////

	// registers:
	//state:
	reg [2:0] state_curr;
	reg [2:0] state_next;
	// pointers (_next: assigned by AGU using normal ones and used by FSM, normal ones: modified and assigned by FSM):
	reg [9:0] h_in, h_in_next;
	reg [9:0] w_in, w_in_next;
	reg [9:0] c_in, c_in_next;
	reg [9:0] h_out, h_out_next;
	reg [9:0] w_out, w_out_next;
	reg [9:0] c_out, c_out_next;
	reg [13:0] win_start_addr, win_start_addr_next;
	reg [13:0] win_row_start_addr, win_row_start_addr_next;
	// pipeline counters (max 3 wait states):
	reg [1:0] pipe_fill_ctr, pipe_flush_ctr;
	parameter NUM_WAIT_STATES_BRAM = 2;
	// local storage registers:
	reg [15:0] win_max;
	// control signals:
	reg fmap_compute_almost_done;

	// define states:
	localparam IDLE = 0;
	localparam FILL = 1;
	localparam COMPUTE = 2;
	localparam FLUSH = 3;
	localparam DONE = 4;

	// state transition logic:
	always @(*) begin
		
		// Default
		state_next = state_curr;

		case(state_curr)
			IDLE: begin

				if (EXT_START_OF_COMPUTE)
					state_next = FILL;
				else
					state_next = IDLE;
			end

			FILL: begin
				
				if (pipe_fill_ctr == 0)
					state_next = COMPUTE;
				else begin
					state_next = FILL;
				end
			end

			COMPUTE: begin
				
				if (fmap_compute_almost_done)
					state_next = FLUSH;
				else
					state_next = COMPUTE;
			end

			FLUSH: begin
				
				if (pipe_flush_ctr == 0)
					state_next = DONE;
				else
					state_next = FLUSH;
			end

			DONE: begin
				state_next = IDLE;
			end

			default: state_next = IDLE;
		endcase
	end	

	// state transition:
	always @(posedge CLK) begin
		if (RESET) begin
			state_curr <= IDLE;
			EXT_END_OF_COMPUTE <= 0;
            BRAM_enb <= 0;
            BRAM_wea <= 0;
			win_max <= 0;
		end	else begin
			state_curr <= state_next;
			case(state_curr)
				IDLE: begin
					// initialize pointers:
                	h_in <= 0; w_in <= 0; c_in <= 0; h_out <= 0; w_out <= 0; c_out <= 0;
                	win_start_addr <= IN_FMAP_BASEADDR; win_row_start_addr <= IN_FMAP_BASEADDR;

                	// initialize pipeline ctrs:
                	pipe_fill_ctr <= NUM_WAIT_STATES_BRAM; pipe_flush_ctr <= NUM_WAIT_STATES_BRAM;

					// Reset control signals
                    EXT_END_OF_COMPUTE <= 0;
                    BRAM_enb <= 0;
                    BRAM_wea <= 0;

					win_max <= 0;
				end

				FILL: begin
					h_in               <= h_in_next;
					w_in               <= w_in_next;
					win_start_addr     <= win_start_addr_next;
					win_row_start_addr <= win_row_start_addr_next;
					pipe_fill_ctr      <= pipe_fill_ctr - 1;

					BRAM_enb   <= 1;
					BRAM_addrb <= win_start_addr_next;
				end

				COMPUTE: begin
					h_in               <= h_in_next;
					w_in               <= w_in_next;
					h_out              <= h_out_next;
					w_out              <= w_out_next;
					c_in               <= c_in_next;
					win_start_addr     <= win_start_addr_next;
					win_row_start_addr <= win_row_start_addr_next;

					BRAM_enb   <= 1;
					BRAM_addrb <= win_start_addr_next;
					
					win_max <= BRAM_doutb > win_max ? BRAM_doutb : win_max ;
				end

				FLUSH: begin
					BRAM_enb <= 0;
                    pipe_flush_ctr <= pipe_flush_ctr - 1;

                    win_max <= BRAM_doutb > win_max ? BRAM_doutb : win_max ;
				end

				DONE: begin
					EXT_END_OF_COMPUTE <= 1;
				end

			endcase
		end
	end

	//////////////// FSM CODE END   ////////////////


	//////////////// AGU CODE BEGIN ////////////////

	always @(*) begin

	end

	//////////////// AGU CODE END   ////////////////

endmodule