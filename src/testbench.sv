// Paul-John Clet
// Advanced Computer Architecture - Project 3
// Superscalar Out of Order RISC-V Execution - With Reorder Buffer

`timescale 1ns / 1ps

module testbench;

	logic clk;
	int cycle;

	// instantiate device to be tested
	reorder_buffer dut (.clk(clk));
	
	initial begin
		$display("[Testbench] Initialized.");
		cycle = 0;
		clk = 1'b0;
	end

	// generate clock to sequence testss
	always begin
		#10; 
		clk = ~clk; 
	end

	// check results
	always @(negedge clk) begin
		cycle = cycle + 1;
		$display("------------------------- [CLK] Cycle #%0d -------------------------", cycle);
		
	end
	
endmodule
