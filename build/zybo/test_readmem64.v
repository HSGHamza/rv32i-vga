module test_readmem64(input [5:0] addr, output [31:0] data);
  reg [31:0] mem [0:63];
  initial begin
    $readmemh("instructions.hex", mem);
  end
  assign data = mem[addr];
endmodule
