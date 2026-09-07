module instructionMemory (
    input clk,
    input reset,
    input write_enable,
    input read_enable,
    input [3:0] address,
    input [31:0] data_in,
    output reg [31:0] data_out
);

reg [7:0] memory [0:63];
integer i;

always @(*)
begin
memory[i] = data_in[7:0] 
memory[i] = data_in[15:8]
memory[i] = data_in[23:16]
memory[i] = data_in[31:24]
end

always @(*)
begin
data_out[7:0] = memory[i] 
data_out[15:8] = memory[i] 
data_out[23:16] = memory[i] 
data_out[31:24] = memory[i] 
end

always @(posedge clk) begin
    if (reset) begin
        for (i = 0; i < 16; i = i + 1)
            memory[i] <= 32'b0;
        data_out <= 32'b0;
    end

        if (write_enable)
            memory[address] <= data_in;

        if (read_enable)
            data_out <= memory[address];
    end
end

endmodule


