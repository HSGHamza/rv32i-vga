module instructionMemory (
    input             clk,
    input             reset,
    input      [31:0] address,
    output reg [31:0] data_out
);
    reg [31:0] memory [0:63];
    initial begin
        $readmemh("test_instr64.hex", memory);
    end
    always @(*) begin
        if (address[31:8] != 0)
            data_out = 32'h0000_0013;
        else
            data_out = memory[address[7:2]];
    end
endmodule
