`timescale 1ns / 1ps

module zybo_top (
    input  wire        clk,        // 125.0 MHz onboard oscillator (Pin K17)
    input  wire [3:0]  sw,         // Slide switches: sw[0]=Reset (1=rst, 0=run), sw[1]=AI toggle
    input  wire [3:0]  btn,        // Pushbuttons: btn[0]=L_UP, btn[1]=L_DN, btn[2]=R_UP, btn[3]=R_DN

    // User Status LEDs (Pins M14, M15, G14, D18)
    output wire [3:0]  led,

    // VGA 1-bit Interface via Single Pmod Port JC (RGB111: 1 wire per channel, 8 colors)
    // Red:   JC1 -> V15
    // Green: JC2 -> W15
    // Blue:  JC3 -> T11
    // Hsync: JC7 -> W14
    // Vsync: JC8 -> Y14
    output wire        vga_r,
    output wire        vga_g,
    output wire        vga_b,
    output wire        vga_hs,
    output wire        vga_vs
);

    // -------------------------------------------------------------------------
    // 1. Clock Generation: 125 MHz -> 25 MHz (Divide-by-5 with 50% duty cycle)
    // -------------------------------------------------------------------------
    reg [2:0] clk_cnt = 3'd0;
    reg       clk_25m_reg = 1'b0;
    wire      rst_btn_or_sw = sw[0]; // Reset on switch 0: UP = Reset, DOWN = Run

    always @(posedge clk or posedge rst_btn_or_sw) begin
        if (rst_btn_or_sw) begin
            clk_cnt     <= 3'd0;
            clk_25m_reg <= 1'b0;
        end else begin
            if (clk_cnt == 3'd4) begin
                clk_cnt     <= 3'd0;
                clk_25m_reg <= 1'b1;
            end else begin
                clk_cnt <= clk_cnt + 3'd1;
                if (clk_cnt == 3'd1)
                    clk_25m_reg <= 1'b0;
            end
        end
    end

    wire clk_25m = clk_25m_reg;

    // -------------------------------------------------------------------------
    // 2. Synchronized Reset Generation on 25 MHz domain
    // -------------------------------------------------------------------------
    reg [2:0] rst_sync = 3'b111;
    always @(posedge clk_25m or posedge rst_btn_or_sw) begin
        if (rst_btn_or_sw)
            rst_sync <= 3'b111;
        else
            rst_sync <= {rst_sync[1:0], 1'b0};
    end
    wire sys_rst = rst_sync[2];

    // -------------------------------------------------------------------------
    // 3. Heartbeat Counter (Blinks LED[3] at ~1.5 Hz to indicate FPGA is alive)
    // -------------------------------------------------------------------------
    reg [23:0] heartbeat_cnt = 24'd0;
    always @(posedge clk_25m) begin
        if (sys_rst)
            heartbeat_cnt <= 24'd0;
        else
            heartbeat_cnt <= heartbeat_cnt + 24'd1;
    end
    wire heartbeat = heartbeat_cnt[23];

    // -------------------------------------------------------------------------
    // 4. Instantiate Complete RV32I-AXI-VGA SoC
    //    160x120 Framebuffer with 4x hardware pixel replication to 640x480.
    //    Consumes only 17 Block RAMs (well within XC7Z010's 60 BRAM limit).
    // -------------------------------------------------------------------------
    wire [7:0]  soc_red;
    wire [7:0]  soc_green;
    wire [7:0]  soc_blue;
    wire        soc_hsync;
    wire        soc_vsync;
    wire        cpu_stall;
    wire        display_enable;
    wire        mem_write;
    wire        mem_read;
    wire [31:0] pcRegister;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;

    soc_top #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(32),
        .FB_WIDTH      (160),
        .FB_HEIGHT     (120),
        .FB_BASE       (32'h5000_0000),
        .FB_SIZE       (32'h0001_2C00), // 160*120*4 = 76,800 bytes
        .PIXEL_SCALE   (4)              // 4x scaling -> outputs standard 640x480 timing
    ) u_soc_top (
        .clk            (clk_25m),
        .reset          (sys_rst),
        .btn            (btn),
        .sw             (sw),

        .Hsync          (soc_hsync),
        .Vsync          (soc_vsync),
        .red            (soc_red),
        .green          (soc_green),
        .blue           (soc_blue),

        .pcRegister     (pcRegister),
        .mem_addr       (mem_addr),
        .mem_wdata      (mem_wdata),
        .mem_write      (mem_write),
        .mem_read       (mem_read),
        .cpu_stall      (cpu_stall),
        .display_enable (display_enable)
    );

    // -------------------------------------------------------------------------
    // 5. VGA 1-bit (RGB111: 1-1-1) Output Mapping (Single Pmod JC)
    // -------------------------------------------------------------------------
    assign vga_r  = soc_red[7];
    assign vga_g  = soc_green[7];
    assign vga_b  = soc_blue[7];
    assign vga_hs = soc_hsync;
    assign vga_vs = soc_vsync;

    // -------------------------------------------------------------------------
    // 6. User Status LEDs
    // -------------------------------------------------------------------------
    // Sticky flag for CPU memory write: lights permanently once first write occurs
    reg mem_written = 1'b0;
    always @(posedge clk_25m or posedge sys_rst) begin
        if (sys_rst)
            mem_written <= 1'b0;
        else if (mem_write)
            mem_written <= 1'b1;
    end

    // LED 0: Display enable status (solid ON when CPU activates VGA display via MMIO)
    // LED 1: CPU stall indicator
    // LED 2: Memory write activity (solid ON once CPU writes)
    // LED 3: System Heartbeat (25 MHz clock running, blinks at ~1.5 Hz)
    assign led[0] = display_enable;
    assign led[1] = cpu_stall;
    assign led[2] = mem_written;
    assign led[3] = heartbeat;

endmodule
