module pixel_addr_gen (
    input  wire [15:0] H_count,
    input  wire [15:0] V_count,
    input  wire        video_on,
    output wire [20:0] pixel_addr
);
    assign pixel_addr = video_on ? ((V_count << 11) + (V_count << 9) + (H_count << 2)) : 21'd0;

endmodule
