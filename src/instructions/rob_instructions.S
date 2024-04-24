// R type instructions
// breakdown: 31:25 = funct7, 24:20 = rs2, 19:15 = rs1, 14:12 = funct3, 11:7 = rd, 6:0 = opcode
// add instruction: funct7 = instr_in[31:25] == 7'b0000000, funct3 = instr_in[14:12] == 3'b000, opcode = instr_in[6:0] == 7'b0110011
// mul instruction: funct7 = instr_in[31:25] == 7'b0000001, funct3 = instr_in[14:12] == 3'b000, opcode = instr_in[6:0] == 7'b0110011 - not using for this project

// SB type instructions
// breakdown: 31:25 = imm1, 24:20 = rs2, 19:15 = rs1, 14:12 = funct3, 11:7 = imm2, 6:0 = opcode
// bne instruction: {imm1, imm2} = 12-bit address, funct3 = 001, opcode = 7'b1100011
// beq instruction: {imm1, imm2} = 12-bit address, funct3 = 000, opcode = 7'b1100011

// instructions to test
add r2, r3, r1      // 
mul r6, r5, r4      // test if we can load both in at the same time - also check if only 1 instruction is running

add r16, r15, r12   // test add result
beq r3, r3, 6       // throw exception

mul r8, r7, r6      // skip (flush)
add r10, r6, r9     // skip (flush)

add r16, r15, r12   // test add result
mul r18, r17, r16   // check for RAW hazard

// expected numbers:
add r2, r3, r1      // R2 = R3 + R1 = 3 + 1 = 4
mul r6, r5, r4      // R6 = R5 * R4 = 5 * 4 = 20

add r16, r15, r12   // R16 = R15 + R12 = 15 + 12 = 27
beq r3, r3, 6       // throw exception

mul r8, r7, r6      // --- R8 = R7 * R6 = 7 * 20 = 140 -- skipped (flush)
add r10, r6, r9     // --- R10 = R6 + R9 = 20 * 9 = 180 -- skipped (flush)

add r16, r15, r12   // --- R16 = R15 + R12 = 15 + 12 = 27
mul r18, r17, r16   // --- R18 = R17 * R16 = 17 * 27 = 459

// final: R2 = 4, R6 = 20, R8 = 8,
//        R10 = 10, R16 = 27, R18 = 459

add example binary instruction: 
add rd, rs1, rs2
add r2, r3, r1
// funct7  rs2   rs1   f3  rd    opcode
   0000000_00001_00011_000_00010_0110011 = 00000000000100011000000100110011

mul example binary instruction: 
mul rd, rs1, rs2
mul r6, r5, r4 
// funct7  rs2   rs1   f3  rd    opcode
   0000001_00100_00101_000_00110_0110011 = 00000010010000101000001100110011

full binary instructions:
                      funct7  rs2   rs1   f3  rd    opcode
add r2, r3, r1      = 0000000_00001_00011_000_00010_0110011 = 00000000000100011000000100110011
mul r6, r5, r4      = 0000001_00100_00101_000_00110_0110011 = 00000010010000101000001100110011

add r16, r15, r12   = 0000000_01100_01111_000_10000_0110011 = 00000000110001111000100000110011
                      imm1    rs2   rs1   f3  imm2  opcode
beq r3, r3, 6       = 0000000_00011_00011_000_00110_1100011 = 00000000001100011000001101100011


                      funct7  rs2   rs1   f3  rd    opcode
mul r8, r7, r6      = 0000001_00110_00111_000_01000_0110011 = 00000010011000111000010000110011
add r10, r6, r9     = 0000000_01001_00110_000_01010_0110011 = 00000000100100110000010100110011

                      funct7  rs2   rs1   f3  rd    opcode
add r16, r15, r12   = 0000000_01100_01111_000_10000_0110011 = 00000000110001111000100000110011
mul r18, r17, r16   = 0000001_10000_10001_000_10010_0110011 = 00000011000010001000100100110011

final binary instructions:
00000000000100011000000100110011
00000010010000101000001100110011
00000000110001111000100000110011
00000000001100011000001101100011
00000010011000111000010000110011
00000000100100110000010100110011
00000000110001111000100000110011
00000011000010001000100100110011

