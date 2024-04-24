// Paul-John Clet
// Advanced Computer Architecture - Project 2
// Superscalar Out of Order RISC-V Execution

`timescale 1ns / 1ps

// functional unit - perform an add or multiply instruction
module functional_unit #(parameter logic add_or_mul, parameter int clock_period)
			 // betw. reservation station
			 (input logic clk, flush, new_instruction,
			  input logic [31:0] a, b,
			  input logic [2:0] instruction_tag,
			  output logic ready, 
			  
			  // bus
			  output logic [2:0] broadcasted_tag,
			  output logic [31:0] broadcasted_value,
			  output logic bus_valid_output
			  ); 
	
	logic temp_output_signal;
	assign bus_valid_output = temp_output_signal;
	
	logic [31:0] sum, product;
	
	assign sum = a + b; // assume no overflow
	assign product = a * b; // assume no overflow
	
	localparam unit_delay = add_or_mul ? 6 : 4;
	
	initial begin
		temp_output_signal <= 1'b0;
		ready = 1'b1;
	end
	
	always @(posedge new_instruction) begin
		if (new_instruction && ready && ~flush) begin
			$display("[%s] Started executing a new instruction (%d %s %d)", (add_or_mul ? "MUL" : "ADD"), a, (add_or_mul ? "*" : "+"), b);
			ready = 1'b0; // disable adder
			for (int i=0; i < unit_delay; i++) begin
				#(clock_period * 2);
				if (flush) begin
					$display("[%s] Flushing the execution of this unit.", (add_or_mul ? "MUL" : "ADD"));
					break;
				end
			end
			#6;

			if (~flush) begin
				$display("[%s] Finished executing a new instruction (%d %s %d)", (add_or_mul ? "MUL" : "ADD"), a, (add_or_mul ? "*" : "+"), b);
			
				// once a module is finished, broadcast the value on the bus 
				broadcasted_value = add_or_mul ? product : sum;
				broadcasted_tag = instruction_tag;
				temp_output_signal = 1'b1; #2; temp_output_signal = 1'b0;
				ready = 1'b1;
			end
			
		end
	end
  
endmodule
