module ProgramCounter (
    input             clk,
    input             reset,
    input      [6:0]  opcode,
    input      [31:0] imm,
    input             jump,        // Branch condition from bAlu / alu (doesB)
    output reg [31:0] pcRegister
);

    // RISC-V Branch Opcode: 7'b1100011 = 7'd99 (0x63)
    localparam OPCODE_BRANCH = 7'd99;

    always @(posedge clk) begin
        if (reset) begin
            pcRegister <= 32'd0;
        end else begin
            // If branch instruction and branch condition is met
            if (opcode == OPCODE_BRANCH && jump) begin
                pcRegister <= pcRegister + imm;       // Branch target = PC + imm
            end else begin
                pcRegister <= pcRegister + 32'd4;     // Default: next instruction
            end
        end
    end

endmodule
