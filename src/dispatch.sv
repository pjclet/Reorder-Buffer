// Paul-John Clet
// Advanced Computer Architecture - Project 3
// Superscalar Out of Order RISC-V Execution - With Reorder Buffer

`timescale 1ns / 1ps

// dispatch the instructions to the RF
module dispatch #(parameter logic dispatch_has_priority) 
				  (input logic clk, flush,
				   input logic [31:0] instr_in,
					output logic dispatch_ready,
					
					// betw adder fu rs
					input logic [3:0] adder_rs,
					input logic [1:0] adder_count_free,
					output logic add_valid_overwrite,
					output logic [5:0] add_overwrite,
					
					// betw multiplier fu rs
					input logic [3:0] mul_rs,
					input logic [1:0] mul_count_free,
					output logic mul_valid_overwrite,
					output logic [5:0] mul_overwrite,
					
					// between dispatch units
					input logic [2:0] received_tag,
					input logic other_dispatch_ready, received_final_check,
					input logic [4:0] received_rs1, received_rs2, received_rd,
					output logic [2:0] tag,
					output logic dispatch_processed, final_check, // essentially a ready flag for each dispatch unit
					output logic [4:0] output_rs1, output_rs2, output_rd,
					
					// final output to the RAT
					output logic [4:0] final_rs1, final_rs2, final_rd,
					output logic [2:0] final_tag,
					output logic valid_RAT_instruction,
					
					// new output for ROB
					output logic is_branch,
					
					// kill the program
					input instr_queue_empty);
	
	logic has_stored_instruction;
	logic [31:0] stored_instruction;
	
	logic add_or_mul_instr, output_add_or_mul_instr; // 0 for add instruction, 1 for mul instruction
	logic is_nop;
	
	// for level 2 check
	logic case1, case2, case3, case4;
	logic can_run_instruction;
	logic disp_proc;
	
	assign dispatch_processed = disp_proc; 
	assign add_or_mul_instr = received_tag[2];
	
	// assign destination registers
	logic [4:0] rs1, rs2, rd;
	
	assign rs1 = instr_in[19:15];
	assign rs2 = instr_in[24:20];
	assign rd = instr_in[11:7];
	
	logic is_rs2; // for output
	logic [1:0] selected_spot;
	logic found_first_value;
	
	initial begin
		$display("[DISPATCH UNIT %d] Initialized.", (dispatch_has_priority ? 1 : 2));
		dispatch_ready <= 1'b1;
		is_nop <= 1'b0;
		case1 <= 1'b0; case2 <= 1'b0; case3 <= 1'b0; case4 <= 1'b0;
		add_valid_overwrite <= 1'b0; mul_valid_overwrite <= 1'b0;
		add_overwrite <= 6'b0; mul_overwrite <= 6'b0;
		valid_RAT_instruction <= 1'b0;
		final_tag <= 3'b0;
		
		is_branch = 1'b0;
	end
	
	// to check for read after write
	// if priority is == 0 then check for RAW hazard,
	// if it is true then update the tag in 
	
	always @(posedge clk) begin
		is_branch = 1'b0; output_add_or_mul_instr = 1'b0; is_nop <= 1'b0;
		
		if (instr_queue_empty && adder_count_free == 4 && mul_count_free == 4) begin
			$stop();
		end
	
		#1; // delay to wait for signal to send
		// process the received instruction
		
		if (flush) begin
			$display("[DISPATCH UNIT %d] Flushing the pipeline.", (dispatch_has_priority ? 1 : 2));
		end

		// check opcode, funct7, and then the funct3
		if (instr_in[6:0] == 7'b0110011 && instr_in[31:25] == 7'b0000000 && instr_in[14:12] == 3'b000) begin
			$display("[DISPATCH UNIT %d] Received add instruction.", (dispatch_has_priority ? 1 : 2));
			output_add_or_mul_instr = 1'b0;
		end 
		// branch instruction - BEQ
		else if (instr_in[6:0] == 7'b1100011 && instr_in[14:12] == 3'b000) begin
			$display("[DECODE] Received BEQ instruction.");
			is_branch = 1'b1;
		end
		
		else if (instr_in[6:0] == 7'b0110011 && instr_in[31:25] == 7'b0000001 && instr_in[14:12] == 3'b000) begin
			$display("[DISPATCH UNIT %d] Received mul instruction.", (dispatch_has_priority ? 1 : 2));
			output_add_or_mul_instr = 1'b1;
		end 
		else begin 
			$display("[DISPATCH UNIT %d] Received NOP/no instruction/invalid instruction, stalling.", (dispatch_has_priority ? 1 : 2));
			is_nop <= 1'b1;
		end
		
		if (~is_nop) begin
			output_rs1 = rs1;
			output_rs2 = rs2;
			output_rd = rd;
			
			// toggle the ready flag
			disp_proc = 1'b1; #1; disp_proc = 1'b0;
		end
	end
	
	// need to wait for both of them to be ready - wait for the other dispatch unit to finish processing the signals
	always @(posedge other_dispatch_ready) begin
		// reset the ready flag
		
		case1 = (~add_or_mul_instr && ~output_add_or_mul_instr && adder_count_free < 2);						// case 1: add, add
		case2 = (add_or_mul_instr && output_add_or_mul_instr && mul_count_free < 2);							// case 2: mul mul
		case3 = (add_or_mul_instr && ~output_add_or_mul_instr && adder_count_free < 1 && mul_count_free < 1); 	// case 3: add mul
		case4 = (~add_or_mul_instr && output_add_or_mul_instr && adder_count_free < 1 && mul_count_free < 1); 	// case 4: mul add
		
		// structural hazard - check if we can run the instruction - check the 4 cases and see if the instruction is possible
		
		if (case1 || case2 || case3 || case4) begin
			$display("[DISPATCH] Stalling the dispatch unit. Cases: (%b|%b|%b|%b)", case1, case2, case3, case4);
		end 

		else if (~instr_queue_empty) begin
			$display("[DISPATCH UNIT %d] Instruction is able to be executed.", (dispatch_has_priority ? 1 : 2));
			// send the tag
			selected_spot = 0;
			
			// make sure this only happens if case 3 or case 4 *****
			
			// if this dispatch unit has priority, get the first empty slot
			if (dispatch_has_priority || add_or_mul_instr && ~output_add_or_mul_instr || ~add_or_mul_instr && output_add_or_mul_instr) begin
				// check adder 
				if (~output_add_or_mul_instr) begin
					for (int i=3; i >= 0; i--) begin 
						if (adder_rs[i] == 1'b0) begin
							selected_spot = i;
						end
					end
				end
				// check mul
				else begin
					for (int i=3; i >= 0; i--) begin
						if (mul_rs[i] == 1'b0) begin
							selected_spot = i;
						end
					end
				end
			end
			// this dispatch does not have priority, get the second empty slot
			else begin
				found_first_value = 1'b0;
				
				// check adder 
				if (~output_add_or_mul_instr) begin
					// check adder reservation station
					for (int i=3; i >= 0; i--) begin
						if (adder_rs[i] == 1'b0 && found_first_value) begin
							selected_spot = i;
						end 
						
						else if (adder_rs[i] == 1'b0) begin
							found_first_value = 1'b1;
						end
					end
				end
				// check mul
				else begin
					for (int i=3; i >= 0; i--) begin
						if (adder_rs[i] == 1'b0 && found_first_value) begin
							selected_spot = i;
						end 
						
						else if (adder_rs[i] == 1'b0) begin
							found_first_value = 1'b1;
						end
					end
				end
			end
			
			// set the tag
			tag = {output_add_or_mul_instr, selected_spot};
			
			// passed all the cases, we can send the instruction
			final_check <= 1'b1; #2; final_check <= 1'b0;
			
		end
	end
	
	// need a third stage to check whether or not this can be sent - the tag has now arrived
	always @(posedge received_final_check) begin
		
		// check for read after write hazard if this is dispatch unit 2
		if (~dispatch_has_priority && (received_rd == rs2 || received_rd == rs1)) begin
			is_rs2 = (rs2 == received_rd);
			// ensure the tag is sent to the correct functional unit
			// adder unit res station
			if (~output_add_or_mul_instr) begin
				// encode an instruction for the reservation station to set its own id's conflicting $rs to the value {0,received_tag[1:0],32'b0} = {source(0 if rs1, 1 if rs2), rs_index, data}
				add_overwrite <= {is_rs2,received_tag[1:0], received_tag}; // also needs destination tag
				add_valid_overwrite <= 1'b1; #2; add_valid_overwrite <= 1'b1;
			end 
			// mul unit res station
			else begin
				mul_overwrite <= {is_rs2,received_tag[1:0], received_tag};
				mul_valid_overwrite <= 1'b1; #2; mul_valid_overwrite <= 1'b0;
			end
		end

		// tell the RF the tag, the rs1, the rs2
		// this will trigger the rat to update the rd with the final tag and send the data to each reservation station		
		if (~dispatch_has_priority) begin
			#3;
		end
		
		final_rs1 = rs1;
		final_rs2 = rs2;
		final_rd = rd;
		final_tag = tag;
		valid_RAT_instruction <= 1'b1; #1; valid_RAT_instruction <= 1'b0;
		
		// set valid flag
		dispatch_ready <= 1'b1;
	end
				
endmodule
