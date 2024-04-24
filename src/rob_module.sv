// Paul-John Clet
// Advanced Computer Architecture - Project 3
// Superscalar Out of Order RISC-V Execution - With Reorder Buffer

`timescale 1ns / 1ps

// functional unit
module rob_module	
						(input logic clk, // bus_valid_output,
						// bus
						input logic add_bus_valid_output, mul_bus_valid_output, branch_valid_output,
						input logic [2:0] add_broadcasted_tag, mul_broadcasted_tag, branch_broadcasted_tag,
						input logic [31:0] add_broadcasted_value, mul_broadcasted_value,
							
							// from RF
							input logic du1_is_branch, du2_is_branch,
							
							// from RF
							input logic [4:0] add_rd, mul_rd, 
							
						   // betw. add reservation station
							input logic [31:0] add_rs1_data, add_rs2_data, 
							input logic [2:0] add_index, 
							input logic add_valid_instruction,
							
							// betw. mul reservation station
							input logic [31:0] mul_rs1_data, mul_rs2_data,
							input logic [2:0] mul_index,
							input logic mul_valid_instruction,
							
							// commit here
							output logic [4:0] output_dest_reg,
							output logic valid_commit_to_RF,
							output logic [31:0] commit_data,
							
							// always output the head pointer (next available tag)
							output logic [2:0] next_available_tag,
							output logic flush
						 );
	
	
	
	// ROB = 1 busy bit 1 executed bit + 2 op code bits + 1 valid1 bit + 32 src1 bits 1 valid2 bit + 32 src2 bits + 5 destreg bits + 32 value bits + 1 exception bit = 108 bits
	logic [7:0] [107:0] ROB;
	
	// head and tail pointers
	logic [2:0] head_ptr, tail_ptr;
	
	assign next_available_tag = head_ptr;
	
	logic is_branch;
	assign is_branch = du1_is_branch | du2_is_branch;
	
	
	logic [2:0] tag1, tag2;
	logic src1_is_tag, src2_is_tag;
	
	assign src1_is_tag = 1'b0; assign src2_is_tag = 1'b0;  // set this to 0 for testing
	assign tag1 = add_valid_instruction ? add_index : mul_index; 
	assign tag2 = add_valid_instruction ? add_index : mul_index; 
	
	initial begin
		// initialize ROB
		for (int i = 0; i < 8; i++) begin
			ROB[i] = 108'b0;
		end
		
		head_ptr = 3'b0; tail_ptr = 3'b0; 
		output_dest_reg = 5'b0;
	end
	
	
	
	// update the ROB if there is data from the register file 
	always @(add_valid_instruction || mul_valid_instruction || add_bus_valid_output || mul_bus_valid_output || branch_valid_output) begin
//		#1; // *****
		if (add_valid_instruction || mul_valid_instruction) begin
			$display("[ROB] New instruction received.");
			
			if ({is_branch, mul_valid_instruction} == 2'b11) begin
				$display("[ERROR] [ROB] Check the instruction codes.");
			end
			
			// load the src1 and src2 with empty bits first
			//					  busy  valid  opcode									  v1    src1   v2    src2   destReg	  value  except
			ROB[head_ptr] = {1'b0, 1'b0, {is_branch, mul_valid_instruction}, 1'b1, 32'b0, 1'b1, 32'b0, 5'b0, 32'b0, 1'b0};
			
			// load data here
			// first thing we try is to load the value directly - can be incorrect at first if there is no value	
			if (add_valid_instruction) begin
				ROB[head_ptr][37:33] = add_rd;
				ROB[head_ptr][102:71] = add_rs1_data;
				ROB[head_ptr][69:38]  = add_rs2_data;
			end else if (mul_valid_instruction) begin
				ROB[head_ptr][37:33] = mul_rd;
				ROB[head_ptr][102:71] = mul_rs1_data;
				ROB[head_ptr][69:38]  = mul_rs2_data;
			end
			
			// load the tags if they are tags, check both source 1 and source 2
			if (src1_is_tag) begin
				ROB[head_ptr][103] = 1'b0; // set valid bit to 0
				ROB[head_ptr][102:71] = {29'b0, tag1};
			end 
			if (src2_is_tag) begin
				ROB[head_ptr][70] = 1'b0; // set valid bit to 0
				ROB[head_ptr][69:38]  = {29'b0, tag2};
			end
			
			$display("[ROB] New Entry: %0d -> rd = %b", head_ptr, ROB[head_ptr][37:33]);
			
			// move the head pointer
			head_ptr = head_ptr + 3'b1;
		end
		// ***** maybe else here?
		
		// need to update the entry here since a functional unit has finished
		if (add_bus_valid_output) begin
			ROB[add_broadcasted_tag][32:1] = add_broadcasted_value;
			
			ROB[add_broadcasted_tag][106] = 1'b1; // completed execution
			$display("[ROB] Add instruction completed. Set r%0d = %0d.", add_broadcasted_tag, add_broadcasted_value);
		end
		
		if (mul_bus_valid_output) begin
			ROB[mul_broadcasted_tag][32:1] = mul_broadcasted_value;
			ROB[mul_broadcasted_tag][106] = 1'b1; // completed execution
			$display("[ROB] Add instruction completed. Set r%0d = %0d.", mul_broadcasted_tag, mul_broadcasted_value);
		end
		
		if (branch_valid_output) begin
			ROB[branch_broadcasted_tag] = 1'b1;
		end
		
	end
	
	// every clock cycle try to commit the tail pointer value (check for exception)
	always @(posedge clk) begin
		// if the instruction is not busy and the execution has finished, we try to commit the value
		if (~ROB[tail_ptr][107]  && ROB[tail_ptr][106]) begin
			
			// check for an exception here
			if (ROB[tail_ptr][0]) begin
				// exception! flush the pipeline! start from the correct PC!
				$display("[EXCEPTION] [ROB] Flush the pipeline.");
				correct_PC = ROB[tail_ptr][32:1]; // go to the correct address

				// reset the ROB
				for (int i = 0; i < 8; i++) begin
					ROB[i] = 108'b0;
				end
				head_ptr = tail_ptr;

				flush  = 1'b1; @(posedge clk); flush = 1'b0;
				

				
			end else begin
				$display("[SUCCESS] [ROB] Finished instruction at ROB index %0d, committing data.", tail_ptr);
				// good to commit to the RF
				commit_data = ROB[tail_ptr][32:1];
				output_dest_reg = ROB[tail_ptr][37:33];
				
				valid_commit_to_RF = 1'b1; #1; valid_commit_to_RF = 1'b1; // toggle the bit to send a signal
				tail_ptr = tail_ptr + 3'b1;
			end
			
		end
	end
			  
endmodule
