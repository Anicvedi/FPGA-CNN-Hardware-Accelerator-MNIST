`timescale 1ns / 1ps

module accelerator_TOP(
	input 	CLK,
	input 	RESET,
	
	// UART
	input 	UART_RX,
	output 	UART_TX,

	// 7-segment display
	output wire [6:0] SEG7_SEG,
	output wire [3:0] SEG7_ANODE,
	
	// LED indicators
	output wire [3:0] LED
    );