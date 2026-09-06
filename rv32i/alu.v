module alu(
    input [6:0] opcode,
    input clk,
    input [31:0] op1, op2,
    input [2:0] func3,
    output reg doesB,
    output reg [31:0] rw
);

wire [31:0] ri_result;
wire jump;

RI_alu ri_alu(
    .clk(clk),
    .opcode(opcode),
    .op1(op1),
    .op2(op2),
    .imm_ext(imm),
    .func3(func3),
    .func7(func7),
    .rd(ri_result)
);

bAlu bAlu(
    .clk(clk),
    .op1(op1), 
    .op2(op2),
    .func3(func3),
    .jump(jump)
);

always @(*) begin

    if (opcode == 7'd19 || opcode == 7'd51)
    begin
        rw = ri_result;
    end
    else if (opcode == 7'd63)
    begin
    	doesB = jump;
    end

end

endmodule
