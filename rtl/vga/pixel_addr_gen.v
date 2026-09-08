`timescale 1ns / 1ps

module pixel_addr_gen (
    input  wire [15:0] H_count,
    input  wire [15:0] V_count,
    input  wire        video_on,
    output wire [20:0] pixel_addr
);

    // 21-bit calculation: (V_count * 640 + H_count) * 4
    // Using 21-bit wide terms to prevent bit truncation during shift operations:
    // 640 = 512 + 128 = (1 << 9) + (1 << 7)
    // Multiply by 4 (<< 2): V_count * 640 * 4 = (V_count << 11) + (V_count << 9)
    //                       H_count * 4       = (H_count << 2)
    wire [20:0] v_term_11 = {V_count[9:0], 11'd0}; // V_count << 11 (V_count < 480 fits in 9 bits)
    wire [20:0] v_term_9  = {V_count[11:0], 9'd0}; // V_count << 9
    wire [20:0] h_term_2  = {3'd0, H_count[15:0], 2'd0}; // H_count << 2

    assign pixel_addr = video_on ? (v_term_11 + v_term_9 + h_term_2) : 21'd0;

endmodule
