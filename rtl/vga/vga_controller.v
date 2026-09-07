`timescale 1ns / 1ps

module vga_controller #(
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 32,
    parameter int FB_WIDTH       = 640,
    parameter int FB_HEIGHT      = 480,
    parameter logic [AXI_ADDR_WIDTH-1:0] FB_BASE_ADDR = 32'h5000_0000
)(
    input  wire        clk,
    input  wire        rst,       // Active-high reset

    // AXI4-Lite Slave Interface (CPU side)
    // Write Address Channel
    input  wire [AXI_ADDR_WIDTH-1:0]     awaddr,
    input  wire                          awvalid,
    output wire                          awready,

    // Write Data Channel
    input  wire [AXI_DATA_WIDTH-1:0]     wdata,
    input  wire [AXI_DATA_WIDTH/8-1:0]   wstrb,
    input  wire                          wvalid,
    output wire                          wready,

    // Write Response Channel
    output wire [1:0]                    bresp,
    output wire                          bvalid,
    input  wire                          bready,

    // Read Address Channel
    input  wire [AXI_ADDR_WIDTH-1:0]     araddr,
    input  wire                          arvalid,
    output wire                          arready,

    // Read Data Channel
    output wire [AXI_DATA_WIDTH-1:0]     rdata,
    output wire [1:0]                    rresp,
    output wire                          rvalid,
    input  wire                          rready,

    // VGA Outputs (Display side)
    output wire                          Hsync,
    output wire                          Vsync,
    output wire [7:0]                    red,
    output wire [7:0]                    green,
    output wire [7:0]                    blue
);

    // Active-low reset generation for AXI framebuffer
    wire resetn;
    assign resetn = ~rst;

    // Internal interconnect wires
    wire [15:0] H_count;
    wire [15:0] V_count;
    wire        video_on;
    wire [20:0] pixel_addr;
    wire [31:0] vga_data;

    // 1. VGA Timing Generator
    vga_timing u_vga_timing (
        .clk      (clk),
        .rst      (rst),
        .H_count  (H_count),
        .V_count  (V_count),
        .Hsync    (Hsync),
        .Vsync    (Vsync),
        .video_on (video_on)
    );

    // 2. Pixel Byte Address Generator
    pixel_addr_gen u_pixel_addr_gen (
        .H_count    (H_count),
        .V_count    (V_count),
        .video_on   (video_on),
        .pixel_addr (pixel_addr)
    );

    // 3. AXI Framebuffer
    axi_framebuffer #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .FB_WIDTH       (FB_WIDTH),
        .FB_HEIGHT      (FB_HEIGHT),
        .FB_BASE_ADDR   (FB_BASE_ADDR)
    ) u_axi_framebuffer (
        .clk      (clk),
        .resetn   (resetn),

        // AXI Write Address Channel
        .awaddr   (awaddr),
        .awvalid  (awvalid),
        .awready  (awready),

        // AXI Write Data Channel
        .wdata    (wdata),
        .wstrb    (wstrb),
        .wvalid   (wvalid),
        .wready   (wready),

        // AXI Write Response Channel
        .bresp    (bresp),
        .bvalid   (bvalid),
        .bready   (bready),

        // AXI Read Address Channel
        .araddr   (araddr),
        .arvalid  (arvalid),
        .arready  (arready),

        // AXI Read Data Channel
        .rdata    (rdata),
        .rresp    (rresp),
        .rvalid   (rvalid),
        .rready   (rready),

        // VGA Pixel Read Port
        .vga_addr (pixel_addr),
        .vga_data (vga_data)
    );

    // 4. RGB Output Stage
    rgb_output u_rgb_output (
        .clk      (clk),
        .rst      (rst),
        .video_on (video_on),
        .vga_data (vga_data),
        .red      (red),
        .green    (green),
        .blue     (blue)
    );

endmodule
