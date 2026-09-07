module vga_timing (
    input  wire        clk,       // 25.175 MHz / 25 MHz pixel clock
    input  wire        rst,       // Active-high reset
    output reg  [15:0] H_count,
    output reg  [15:0] V_count,
    output wire        Hsync,
    output wire        Vsync,
    output wire        video_on   // Active high during visible area
);

// Horizontal timing parameters (640x480 @ 60Hz standard: 800 total pixels per line)
localparam H_VISIBLE = 640;
localparam H_FRONT   = 16;
localparam H_SYNC    = 96;
localparam H_BACK    = 48;
localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK; // 800

// Vertical timing parameters (640x480 @ 60Hz standard: 525 total lines per frame)
localparam V_VISIBLE = 480;
localparam V_FRONT   = 10;
localparam V_SYNC    = 2;
localparam V_BACK    = 33;
localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK; // 525

// Horizontal and Vertical counter logic
always @(posedge clk or posedge rst) begin
    if (rst) begin
        H_count <= 16'd0;
        V_count <= 16'd0;
    end else begin
        if (H_count == H_TOTAL - 1) begin
            H_count <= 16'd0;
            if (V_count == V_TOTAL - 1) begin
                V_count <= 16'd0;
            end else begin
                V_count <= V_count + 16'd1;
            end
        end else begin
            H_count <= H_count + 16'd1;
        end
    end
end

// VGA sync pulses are active-low for standard 640x480 @ 60Hz
assign Hsync = ~((H_count >= (H_VISIBLE + H_FRONT)) && (H_count < (H_VISIBLE + H_FRONT + H_SYNC)));
assign Vsync = ~((V_count >= (V_VISIBLE + V_FRONT)) && (V_count < (V_VISIBLE + V_FRONT + V_SYNC)));

// Video display enable signal (active only inside visible area)
assign video_on = (H_count < H_VISIBLE) && (V_count < V_VISIBLE);

endmodule
