module Datapath;
input clk;
input reset;
output reg [31:0] pcRegister;


reg write_enable;
reg read_enable;
reg [31:0] instruction;
reg [6:0] opcodout;
reg [4:0] rd;
reg [4:0] rs1;
reg [4:0] rs2;
reg [2:0] func3;
reg [6:0] func7;
reg [31:0] imm;
reg [31:0] rs1out;
reg [31:0] rs2out;
reg [31:0] rw;

//assembly code with "for loop"


ProgramCounter pc(
.clk(clk),
.reset(reset),
.pcRegister(pcRegister)
);

instructionMemory instr_mem(
.clk(clk),
.reset(reset),
.write_enable(),
.read_enable(read_enable),
.address(pcRegister),
.data_in(//assembly code),
.data_out(instruction)
);

decoder decoded(
.instr(instruction),
.opcodout(opcodout),
.rd(rd),
.rs1(rs1),
.rs2(rs2),
.func3(func3),
.func7(func7),
.imm(imm)
);

RegFile registerFile(
clk(clk),
rd(rd),
rs1(rs1),
rs2(rs2),
rw(rw),
rs1out(rs1out),
rs2out(rs2out)
);

alu alu(
    .opcode(),
    .clk(clk),
    .op1(rs1), 
    .op2(rs2),
    .func3(func3),
    .doesB(jump),
    .rw(rw)
);


