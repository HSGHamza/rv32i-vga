module ProgramCounter(

input clk,reset,
output reg [31:0] pcRegister

);

reg [31:0] pcCounter; 

always @(posedge clk)
if(reset)
begin
pcCounter = 32'd0;
end
begin
pcCounter = pcCounter + 32'd4;
end

endmodule
