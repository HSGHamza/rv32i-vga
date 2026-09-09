module test_readmem(input [4:0] addr, output [31:0] data);
  reg [31:0] mem [0:19];
  initial begin
    $readmemh("instructions.hex", mem);
  end
  assign data = mem[addr];
endmodule
