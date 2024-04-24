// Paul-John Clet
// Advanced Computer Architecture - Project 3
// Superscalar Out of Order RISC-V Execution - With Reorder Buffer

`timescale 1ns / 1ps

// send data to the ROB and the reservation stations, hold the final values
module register_file(input logic clk, flush,		
					// input from ROB
					input logic [4:0] dest_reg,
					input logic valid_commit_to_RF,
					input logic [31:0] commit_data,
					input logic [2:0] current_available_tag,
					
					// betw. disp unit 1
					input logic [4:0] du1_rs1, du1_rs2, du1_rd,
					input logic [2:0] du1_tag,
					input logic du1_received_instruction, du1_is_branch,
					
					// betw. disp unit 2
					input logic [4:0] du2_rs1, du2_rs2, du2_rd,
					input logic [2:0] du2_tag,
					input logic du2_received_instruction, du2_is_branch,
					
					// betw. add reservation station
					output logic [31:0] add_rs1_data, add_rs2_data, 
					output logic [2:0] add_index, 
					output logic add_valid_instruction, 
					output logic [4:0] add_rd,
					
					// betw. mul reservation station
					output logic [31:0] mul_rs1_data, mul_rs2_data,
					output logic [2:0] mul_index,
					output logic mul_valid_instruction,
					output logic [4:0] mul_rd,
					
					// go to the branch checker
					output logic branch_valid_instruction,
					output logic [2:0] branch_tag,
					output logic [31:0] beq_rs1_data, beq_rs2_data
					);
	
	// adder address will have a 0 in the beginning of the ID to make a unique tag that is 3 bits
	// multiplier will have a 1 in the beginning of the ID
	
	// 32 registers
	// bits for each entry - 0 for index or register number + 1 for valid bit + 3 for tag + 32 for each integer = 36 bits
	// breakdown: 35 = valid, 34:32 = tag, 31:0 = value
	logic [35:0] RF [31:0];
	
	logic [31:0] [3:0] RAT;
	
	initial begin
		// initialize data to simplify load and store operations
		// registers are valid, and each register has its respective value
		for (int i = 0; i < 32; i++) begin
			RF[i][35] = 1'b1; // set the valid bit
			// leave [34:32] to nothing
			RF[i][31:0] = i;
			$display("[RF] Set register %0d to value %0d", i, RF[i][31:0]);
		end
		
		// initialize the RAT
		for (int i = 0; i < 4; i++) begin
			RAT[i] = 4'b0;
		end
		
		add_valid_instruction = 1'b0; mul_valid_instruction = 1'b0;
		add_rs1_data = 32'b0; add_rs2_data = 32'b0;
		mul_rs1_data = 32'b0; mul_rs2_data = 32'b0;
		add_index = 2'b0; mul_index = 2'b0;
	end
	
	logic instr1_success, instr2_success;
	
	// dispatch units 1 and 2 check
	always @(du1_received_instruction || du2_received_instruction || valid_commit_to_RF) begin
		if (~flush) begin 

			// if you hear a change on the bus, then check for matches and update the value
			if (valid_commit_to_RF) begin
				RF[dest_reg][31:0] = commit_data;
				$display("[RF] Received valid update to the RF from the ROB!");
				$display("\tr%0d = %d",dest_reg, commit_data);
			end 
			
			// check for instruction from the du1
			else if (du1_received_instruction && ~du2_received_instruction) begin

				// update the destination register
				RF[du1_rd] = {1'b0, current_available_tag, 32'b0};
				
				// send the data from rs1 and rs2 to the respective functional unit
				if (du1_is_branch) begin
					$display("[RF] Sending beq instruction from dispatch unit 1.");
					beq_rs1_data = RF[du1_rs1];
					beq_rs2_data = RF[du1_rs2];
					branch_tag = current_available_tag;
					branch_valid_instruction = 1'b1; #1; branch_valid_instruction = 1'b0;
				end
				
				// send to add reservation station
				else if (~du1_tag[2]) begin
					$display("[RF] Sending add instruction from dispatch unit 1.");
					add_rs1_data = RF[du1_rs1];
					add_rs2_data = RF[du1_rs2];
					add_index = current_available_tag;
					add_rd = du1_rd;
					add_valid_instruction = 1'b1;  #1; add_valid_instruction = 1'b0;
					
				end
				// send to mul reservation station
				else begin
					$display("[RF] Sending mul instruction from dispatch unit 1.");
					mul_rs1_data = RF[du1_rs1];
					mul_rs2_data = RF[du1_rs2];
					mul_index = current_available_tag;
					mul_rd = du1_rd;
					mul_valid_instruction = 1'b1; #1; mul_valid_instruction = 1'b0;
				end

			end
			
			else if (du2_received_instruction && ~du1_received_instruction) begin

				// update the destination register
				RF[du2_rd] = {1'b0, current_available_tag + 3'b1, 32'b0};
				
				// send the data from rs1 and rs2 to the respective functional unit
				if (du2_is_branch) begin
					$display("[RF] Sending beq instruction from dispatch unit 2.");
					beq_rs1_data = RF[du2_rs1];
					beq_rs2_data = RF[du2_rs2];
					branch_tag = current_available_tag + 3'b1; // offset by 1
					branch_valid_instruction = 1'b1; #1; branch_valid_instruction = 1'b0;
				end
				
				// send to add reservation station
				else if (~du2_tag[2]) begin
					$display("[RF] Sending add instruction from dispatch unit 2.");
					add_rs1_data = RF[du2_rs1];
					add_rs2_data = RF[du2_rs2];
					add_index = current_available_tag + 3'b1; // offset by 1 // du2_tag[1:0];
					add_rd = du2_rd;
					add_valid_instruction = 1'b1;  #2; add_valid_instruction = 1'b0;
				end
				// send to mul reservation station
				else begin
					$display("[RF] Sending mul instruction from dispatch unit 2.");
					mul_rs1_data = RF[du2_rs1];
					mul_rs2_data = RF[du2_rs2];
					mul_index = current_available_tag + 3'b1; // offset by 1 // du2_tag[1:0];
					mul_rd = du2_rd;
					mul_valid_instruction = 1'b1; #2; mul_valid_instruction = 1'b0;
				end
			end
		end else begin
			$display("[RF] Flushing.");
		end
	end
	
	// print the output of the commit bus
	always @(posedge valid_commit_to_RF) begin
		#5;
		// display the output of the reservation station
		for (int i=0; i<19; i++) begin
			$display("%d - %b - %b - %b",i, RF[i][35], RF[i][34:32], RF[i][31:0]);
		end
	end
	
endmodule


