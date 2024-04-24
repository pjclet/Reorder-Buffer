// Paul-John Clet
// Advanced Computer Architecture - Project 3
// Superscalar Out of Order RISC-V Execution - With Reorder Buffer

`timescale 1ns / 1ps

// check branch instructions, output the exception if the beq data are equal
module branch_check (input logic clk,
					 input logic branch_valid_instruction,
					 input logic [31:0] beq_rs1_data, beq_rs2_data,
					 input logic [2:0] tag,  
					
					 // output to ROB
					 output logic branch_valid_output,
					 output logic [2:0] branch_broadcasted_tag);
	
	// assume no clock delay for checking branch instruction
	always @(posedge branch_valid_instruction) begin
		
		#3;
		if (beq_rs1_data == beq_rs2_data) begin
			$display("[EXCEPTION] [BRANCH CHECK] Determined a misprediction, need to flush the pipeline!");
			branch_broadcasted_tag = tag;
			branch_valid_output = 1'b1; #1; branch_valid_output = 1'b0;
		end
		
	end
	
endmodule
