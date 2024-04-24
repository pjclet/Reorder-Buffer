// Paul-John Clet
// Advanced Computer Architecture - Project 2
// Superscalar Out of Order RISC-V Execution

`timescale 1ns / 1ps

// instruction queue - hold all the instructions
module instr_queue(input logic clk, flush, dispatch_1_ready, dispatch_2_ready,
					input logic [31:0] new_PC_from_flush,
						 output logic [31:0] instr1, instr2,
						 output logic instr_queue_empty);
						 
	localparam int len_instr_ram = 32;
							
	logic [len_instr_ram-1:0] InstrRAM [10:0];
	
	int instr_pointer = 0; // basically the PC here
	
	// read instructions to RAM
	initial begin
		$display("[INSTR QUEUE] Initialized.");
		$readmemb("reorder_buffer.txt", InstrRAM);
		instr_queue_empty <= 1'b0;
		instr1 <= 32'b0; instr2 <= 32'b0;
	end
	
	always @(posedge clk) begin

		if (flush) begin
			$display("[INSTR QUEUE] Flushing IQ, setting the PC to correct address.");
			instr_pointer = new_PC_from_flush;
		end

		if (instr_pointer > len_instr_ram) begin
			$display("[INSTR QUEUE] No more instructions left.");
			instr_queue_empty <= 1'b1;
		end
	
		// Ensure in-order instruction dispatch, with stalling of the second dispatch unit if the first stalls. - goal
		// check if both units are ready, otherwise stall
		// also make sure there are other instructions left still
		if (dispatch_1_ready && dispatch_2_ready && instr_pointer < len_instr_ram) begin
			
//			$display("[INSTR QUEUE] Sending instruction to dispatch 1");
			instr1 = InstrRAM[instr_pointer];
			instr_pointer = instr_pointer + 1;
			
			if (instr_pointer < len_instr_ram) begin // check if there are no instructions left
			
				instr2 = InstrRAM[instr_pointer];
				instr_pointer = instr_pointer + 1;
				
			end
		end
	end
	

endmodule
