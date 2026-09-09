`timescale 1ns / 1ps

module vga_subsystem_tb;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam int AXI_ADDR_WIDTH   = 32;
    localparam int AXI_DATA_WIDTH   = 32;
    localparam int FB_WIDTH         = 640;
    localparam int FB_HEIGHT        = 480;
    localparam logic [31:0] FB_BASE = 32'h5000_0000;

    localparam logic [31:0] ADDR_VGA_CTRL   = 32'h1000_0000;
    localparam logic [31:0] ADDR_VGA_STATUS = 32'h1000_0004;
    localparam logic [31:0] ADDR_FB_BASE    = 32'h1000_0008;
    localparam logic [31:0] ADDR_FB_SIZE    = 32'h1000_000C;

    localparam logic [1:0] AXI_OKAY   = 2'b00;
    localparam logic [1:0] AXI_SLVERR = 2'b10;

    // -------------------------------------------------------------------------
    // Signals
    // -------------------------------------------------------------------------
    logic clk;
    logic rst;

    // AXI4-Lite Master Interface
    logic [AXI_ADDR_WIDTH-1:0]     s_axi_awaddr;
    logic                          s_axi_awvalid;
    logic                          s_axi_awready;

    logic [AXI_DATA_WIDTH-1:0]     s_axi_wdata;
    logic [AXI_DATA_WIDTH/8-1:0]   s_axi_wstrb;
    logic                          s_axi_wvalid;
    logic                          s_axi_wready;

    logic [1:0]                    s_axi_bresp;
    logic                          s_axi_bvalid;
    logic                          s_axi_bready;

    logic [AXI_ADDR_WIDTH-1:0]     s_axi_araddr;
    logic                          s_axi_arvalid;
    logic                          s_axi_arready;

    logic [AXI_DATA_WIDTH-1:0]     s_axi_rdata;
    logic [1:0]                    s_axi_rresp;
    logic                          s_axi_rvalid;
    logic                          s_axi_rready;

    // Sideband & Interconnect wires
    logic        display_enable;
    logic        vga_fb_req;
    logic [20:0] vga_fb_addr;
    logic        vga_video_on;

    logic [18:0] fb_addr;
    logic [31:0] fb_wdata;
    logic [3:0]  fb_we;
    logic        fb_en;
    logic [31:0] fb_rdata;

    // Physical VGA Pins
    logic        Hsync;
    logic        Vsync;
    logic [7:0]  red;
    logic [7:0]  green;
    logic [7:0]  blue;

    // Verification tracking
    int errors = 0;
    int warnings = 0;

    // -------------------------------------------------------------------------
    // Device Under Test (DUT) Instantiations
    // -------------------------------------------------------------------------
    // 1. VGA Registers & Single-Port Access Controller
    vga_registers #(
        .AXI_ADDR_WIDTH   (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH   (AXI_DATA_WIDTH),
        .FB_WIDTH_DEFAULT (FB_WIDTH),
        .FB_HEIGHT_DEFAULT(FB_HEIGHT),
        .FB_BASE_DEFAULT  (FB_BASE)
    ) u_vga_registers (
        .clk            (clk),
        .rst            (rst),

        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),

        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),

        .vga_fb_req     (vga_fb_req),
        .vga_fb_addr    (vga_fb_addr),
        .vga_video_on   (vga_video_on),
        .display_enable (display_enable),

        .fb_addr        (fb_addr),
        .fb_wdata       (fb_wdata),
        .fb_we          (fb_we),
        .fb_en          (fb_en),
        .fb_rdata       (fb_rdata)
    );

    // 2. Physical Single-Port Framebuffer SRAM
    framebuffer_sram #(
        .FB_WIDTH  (FB_WIDTH),
        .FB_HEIGHT (FB_HEIGHT)
    ) u_framebuffer_sram (
        .clk   (clk),
        .en    (fb_en),
        .we    (fb_we),
        .addr  (fb_addr),
        .wdata (fb_wdata),
        .rdata (fb_rdata)
    );

    // 3. VGA Controller
    vga_controller u_vga_controller (
        .clk            (clk),
        .rst            (rst),

        .display_enable (display_enable),
        .vga_fb_req     (vga_fb_req),
        .vga_fb_addr    (vga_fb_addr),
        .vga_video_on   (vga_video_on),
        .vga_data       (fb_rdata),

        .Hsync          (Hsync),
        .Vsync          (Vsync),
        .red            (red),
        .green          (green),
        .blue           (blue)
    );

    // -------------------------------------------------------------------------
    // Clock Generation: 25.175 MHz pixel clock (period = 39.72ns ~ 40ns)
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #20 clk = ~clk;

    // -------------------------------------------------------------------------
    // AXI4-Lite Master Helper Tasks with Timeout Protection
    // -------------------------------------------------------------------------
    localparam int TIMEOUT_CYCLES = 2000;

    // Standard AXI Write (same cycle AW/W)
    task automatic axi_write(
        input  logic [31:0] addr,
        input  logic [31:0] data,
        input  logic [3:0]  strb,
        output logic [1:0]  resp
    );
        int timeout_cnt = 0;
        @(posedge clk);
        s_axi_awaddr  <= addr;
        s_axi_awvalid <= 1'b1;
        s_axi_wdata   <= data;
        s_axi_wstrb   <= strb;
        s_axi_wvalid  <= 1'b1;
        s_axi_bready  <= 1'b1;

        // Wait for AWREADY & WREADY
        while (!(s_axi_awready && s_axi_wready)) begin
            @(posedge clk);
            timeout_cnt++;
            if (timeout_cnt > TIMEOUT_CYCLES) begin
                $display("[FAIL][TIMEOUT] AXI Write AWREADY/WREADY timed out at addr %h", addr);
                errors++;
                s_axi_awvalid <= 0;
                s_axi_wvalid  <= 0;
                return;
            end
        end

        @(posedge clk);
        s_axi_awvalid <= 1'b0;
        s_axi_wvalid  <= 1'b0;

        // Wait for BVALID
        timeout_cnt = 0;
        while (!s_axi_bvalid) begin
            @(posedge clk);
            timeout_cnt++;
            if (timeout_cnt > TIMEOUT_CYCLES) begin
                $display("[FAIL][TIMEOUT] AXI Write BVALID timed out at addr %h", addr);
                errors++;
                s_axi_bready <= 0;
                return;
            end
        end

        resp = s_axi_bresp;
        @(posedge clk);
        s_axi_bready <= 1'b0;
    endtask

    // Independent channel arrival: Address first
    task automatic axi_write_addr_first(
        input  logic [31:0] addr,
        input  logic [31:0] data,
        input  logic [3:0]  strb,
        output logic [1:0]  resp
    );
        int timeout_cnt = 0;
        @(posedge clk);
        s_axi_awaddr  <= addr;
        s_axi_awvalid <= 1'b1;
        s_axi_wvalid  <= 1'b0;

        while (!s_axi_awready) begin
            @(posedge clk);
            timeout_cnt++;
            if (timeout_cnt > TIMEOUT_CYCLES) begin
                $display("[FAIL][TIMEOUT] AXI Write AWREADY timed out");
                errors++;
                s_axi_awvalid <= 0;
                return;
            end
        end

        @(posedge clk);
        s_axi_awvalid <= 1'b0;
        s_axi_wdata   <= data;
        s_axi_wstrb   <= strb;
        s_axi_wvalid  <= 1'b1;
        s_axi_bready  <= 1'b1;

        timeout_cnt = 0;
        while (!s_axi_wready) begin
            @(posedge clk);
            timeout_cnt++;
            if (timeout_cnt > TIMEOUT_CYCLES) begin
                $display("[FAIL][TIMEOUT] AXI Write WREADY timed out");
                errors++;
                s_axi_wvalid <= 0;
                return;
            end
        end

        @(posedge clk);
        s_axi_wvalid <= 1'b0;

        timeout_cnt = 0;
        while (!s_axi_bvalid) begin
            @(posedge clk);
            timeout_cnt++;
            if (timeout_cnt > TIMEOUT_CYCLES) begin
                $display("[FAIL][TIMEOUT] AXI Write BVALID timed out");
                errors++;
                s_axi_bready <= 0;
                return;
            end
        end

        resp = s_axi_bresp;
        @(posedge clk);
        s_axi_bready <= 1'b0;
    endtask

    // Independent channel arrival: Data first
    task automatic axi_write_data_first(
        input  logic [31:0] addr,
        input  logic [31:0] data,
        input  logic [3:0]  strb,
        output logic [1:0]  resp
    );
        int timeout_cnt = 0;
        @(posedge clk);
        s_axi_wdata   <= data;
        s_axi_wstrb   <= strb;
        s_axi_wvalid  <= 1'b1;
        s_axi_awvalid <= 1'b0;

        while (!s_axi_wready) begin
            @(posedge clk);
            timeout_cnt++;
            if (timeout_cnt > TIMEOUT_CYCLES) begin
                $display("[FAIL][TIMEOUT] AXI Write WREADY timed out");
                errors++;
                s_axi_wvalid <= 0;
                return;
            end
        end

        @(posedge clk);
        s_axi_wvalid  <= 1'b0;
        s_axi_awaddr  <= addr;
        s_axi_awvalid <= 1'b1;
        s_axi_bready  <= 1'b1;

        timeout_cnt = 0;
        while (!s_axi_awready) begin
            @(posedge clk);
            timeout_cnt++;
            if (timeout_cnt > TIMEOUT_CYCLES) begin
                $display("[FAIL][TIMEOUT] AXI Write AWREADY timed out");
                errors++;
                s_axi_awvalid <= 0;
                return;
            end
        end

        @(posedge clk);
        s_axi_awvalid <= 1'b0;

        timeout_cnt = 0;
        while (!s_axi_bvalid) begin
            @(posedge clk);
            timeout_cnt++;
            if (timeout_cnt > TIMEOUT_CYCLES) begin
                $display("[FAIL][TIMEOUT] AXI Write BVALID timed out");
                errors++;
                s_axi_bready <= 0;
                return;
            end
        end

        resp = s_axi_bresp;
        @(posedge clk);
        s_axi_bready <= 1'b0;
    endtask

    // Standard AXI Read
    task automatic axi_read(
        input  logic [31:0] addr,
        output logic [31:0] data,
        output logic [1:0]  resp
    );
        int timeout_cnt = 0;
        @(posedge clk);
        s_axi_araddr  <= addr;
        s_axi_arvalid <= 1'b1;
        s_axi_rready  <= 1'b1;

        while (!s_axi_arready) begin
            @(posedge clk);
            timeout_cnt++;
            if (timeout_cnt > TIMEOUT_CYCLES) begin
                $display("[FAIL][TIMEOUT] AXI Read ARREADY timed out at addr %h", addr);
                errors++;
                s_axi_arvalid <= 0;
                return;
            end
        end

        @(posedge clk);
        s_axi_arvalid <= 1'b0;

        timeout_cnt = 0;
        while (!s_axi_rvalid) begin
            @(posedge clk);
            timeout_cnt++;
            if (timeout_cnt > TIMEOUT_CYCLES) begin
                $display("[FAIL][TIMEOUT] AXI Read RVALID timed out at addr %h", addr);
                errors++;
                s_axi_rready <= 0;
                return;
            end
        end

        data = s_axi_rdata;
        resp = s_axi_rresp;
        @(posedge clk);
        s_axi_rready <= 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Main Directed Testbench Execution
    // -------------------------------------------------------------------------
    logic [31:0] rdata_val;
    logic [1:0]  resp_val;

    initial begin
        // Signal Initializations
        rst           = 1;
        s_axi_awaddr  = 0;
        s_axi_awvalid = 0;
        s_axi_wdata   = 0;
        s_axi_wstrb   = 0;
        s_axi_wvalid  = 0;
        s_axi_bready  = 0;
        s_axi_araddr  = 0;
        s_axi_arvalid = 0;
        s_axi_rready  = 0;

        $display("================================================================");
        $display("     STARTING SYSTEMVERILOG VGA SUBSYSTEM DIRECTED VERIFICATION ");
        $display("================================================================");

        // =====================================================================
        // TEST 1 — RESET VERIFICATION
        // =====================================================================
        #100;
        @(posedge clk);
        #1;
        if (u_vga_controller.u_vga_timing.H_count !== 16'd0 || 
            u_vga_controller.u_vga_timing.V_count !== 16'd0 ||
            display_enable !== 1'b0 ||
            red !== 8'h00 || green !== 8'h00 || blue !== 8'h00 ||
            fb_we !== 4'b0000) begin
            $display("[FAIL] TEST 1: Reset state mismatch! H=%0d, V=%0d, display_enable=%b, RGB=%h_%h_%h",
                     u_vga_controller.u_vga_timing.H_count, u_vga_controller.u_vga_timing.V_count,
                     display_enable, red, green, blue);
            errors++;
        end else begin
            $display("[PASS] TEST 1: Reset active verified (Counters=0, Display=0, RGB=Black, WE=0).");
        end

        // Release reset
        rst = 0;
        #40;

        // Verify timing counters start advancing
        @(posedge clk);
        #1;
        if (u_vga_controller.u_vga_timing.H_count == 16'd0) begin
            $display("[FAIL] TEST 1: H_count did not advance after reset release");
            errors++;
        end else begin
            $display("[PASS] TEST 1: Timing counters running after reset.");
        end

        // =====================================================================
        // TEST 2 — VGA REGISTER WRITE/READ & INDEPENDENT AXI CHANNELS
        // =====================================================================
        // Check FB_BASE and FB_SIZE reset values
        axi_read(ADDR_FB_BASE, rdata_val, resp_val);
        if (rdata_val !== FB_BASE || resp_val !== AXI_OKAY) begin
            $display("[FAIL] TEST 2: FB_BASE reset mismatch: expected %h, got %h", FB_BASE, rdata_val);
            errors++;
        end else $display("[PASS] TEST 2: FB_BASE reads fixed 0x5000_0000.");

        axi_read(ADDR_FB_SIZE, rdata_val, resp_val);
        if (rdata_val !== {16'd480, 16'd640} || resp_val !== AXI_OKAY) begin
            $display("[FAIL] TEST 2: FB_SIZE reset mismatch: expected {480,640}, got %h", rdata_val);
            errors++;
        end else $display("[PASS] TEST 2: FB_SIZE reads {480, 640}.");

        // Write VGA_CTRL via standard same-cycle
        axi_write(ADDR_VGA_CTRL, 32'h0000_0001, 4'b1111, resp_val);
        axi_read(ADDR_VGA_CTRL, rdata_val, resp_val);
        if (rdata_val !== 32'h0000_0001) begin
            $display("[FAIL] TEST 2: VGA_CTRL write/read mismatch. Got %h", rdata_val);
            errors++;
        end else $display("[PASS] TEST 2: VGA_CTRL written and read successfully.");

        // Write FB_SIZE using address-first channel arrival
        axi_write_addr_first(ADDR_FB_SIZE, {16'd600, 16'd800}, 4'b1111, resp_val);
        axi_read(ADDR_FB_SIZE, rdata_val, resp_val);
        if (rdata_val !== {16'd600, 16'd800}) begin
            $display("[FAIL] TEST 2: FB_SIZE address-first write failed. Got %h", rdata_val);
            errors++;
        end else $display("[PASS] TEST 2: Address-first write completed cleanly.");

        // Write FB_SIZE using data-first channel arrival with byte strobes
        axi_write_data_first(ADDR_FB_SIZE, {16'd480, 16'd640}, 4'b1111, resp_val);
        axi_read(ADDR_FB_SIZE, rdata_val, resp_val);
        if (rdata_val !== {16'd480, 16'd640}) begin
            $display("[FAIL] TEST 2: FB_SIZE data-first write failed. Got %h", rdata_val);
            errors++;
        end else $display("[PASS] TEST 2: Data-first write completed cleanly.");

        // Read-only check: Attempt writing to FB_BASE and VGA_STATUS
        axi_write(ADDR_FB_BASE, 32'h6000_0000, 4'b1111, resp_val);
        axi_read(ADDR_FB_BASE, rdata_val, resp_val);
        if (rdata_val !== FB_BASE) begin
            $display("[FAIL] TEST 2: FB_BASE was modified by write! Expected %h, got %h", FB_BASE, rdata_val);
            errors++;
        end else $display("[PASS] TEST 2: FB_BASE is strictly read-only.");

        axi_write(ADDR_VGA_STATUS, 32'hFFFF_FFFF, 4'b1111, resp_val);
        axi_read(ADDR_VGA_STATUS, rdata_val, resp_val);
        if (rdata_val[31:2] !== 30'd0) begin
            $display("[FAIL] TEST 2: VGA_STATUS was corrupted by write! Got %h", rdata_val);
            errors++;
        end else $display("[PASS] TEST 2: VGA_STATUS write safely ignored.");

        // =====================================================================
        // TEST 3 — DISPLAY ENABLE / DISABLE
        // =====================================================================
        // Disable display
        axi_write(ADDR_VGA_CTRL, 32'h0000_0000, 4'b1111, resp_val);
        @(posedge clk); #1;
        if (display_enable !== 1'b0 || red !== 8'h00 || green !== 8'h00 || blue !== 8'h00) begin
            $display("[FAIL] TEST 3: Display disable failed to force black RGB");
            errors++;
        end else $display("[PASS] TEST 3: Display disable forces RGB black.");

        // Verify timing keeps running
        repeat (100) @(posedge clk);
        if (u_vga_controller.u_vga_timing.H_count == 16'd0) begin
            $display("[FAIL] TEST 3: Timing stopped when display_enable = 0");
            errors++;
        end else $display("[PASS] TEST 3: Timing continues when display_enable = 0.");

        // Re-enable display
        axi_write(ADDR_VGA_CTRL, 32'h0000_0001, 4'b1111, resp_val);

        // =====================================================================
        // TEST 4 — HSYNC TIMING VERIFICATION (Cycle-by-Cycle Automatic Check)
        // =====================================================================
        $display("[INFO] Running cycle-by-cycle HSYNC check for one full line (800 clocks)...");
        // Align to H_count = 0
        while (u_vga_controller.u_vga_timing.H_count !== 16'd0) begin
            @(posedge clk);
            #1;
        end

        for (int h = 0; h < 800; h++) begin
            logic exp_raw_hsync;
            exp_raw_hsync = ~((h >= (640 + 16)) && (h < (640 + 16 + 96))); // Active-low 656..751
            if (u_vga_controller.raw_hsync !== exp_raw_hsync) begin
                $display("[FAIL] TEST 4: HSYNC timing mismatch at H=%0d. Expected %b, got %b",
                         h, exp_raw_hsync, u_vga_controller.raw_hsync);
                errors++;
            end
            @(posedge clk); #1;
        end
        $display("[PASS] TEST 4: HSYNC timing strictly matches standard 640x480 @ 60Hz.");

        // =====================================================================
        // TEST 5 & 6 — VSYNC & VIDEO_ON BOUNDARY VERIFICATION
        // =====================================================================
        $display("[INFO] Checking video_on boundaries and VSYNC pulse...");
        // Wait until line 479, pixel 639
        while (!(u_vga_controller.u_vga_timing.V_count == 16'd479 && u_vga_controller.u_vga_timing.H_count == 16'd639)) begin
            @(posedge clk);
            #1;
        end
        if (u_vga_controller.raw_video_on !== 1'b1) begin
            $display("[FAIL] TEST 6: Boundary (639, 479) video_on expected 1, got 0");
            errors++;
        end

        @(posedge clk); #1; // H = 640, V = 479
        if (u_vga_controller.raw_video_on !== 1'b0) begin
            $display("[FAIL] TEST 6: Boundary (640, 479) video_on expected 0, got 1");
            errors++;
        end

        // Advance to VSYNC lines (490, 491)
        while (u_vga_controller.u_vga_timing.V_count !== 16'd490) begin
            @(posedge clk);
            #1;
        end
        if (u_vga_controller.raw_vsync !== 1'b0) begin
            $display("[FAIL] TEST 5: VSYNC expected 0 (active-low) at line 490, got %b", u_vga_controller.raw_vsync);
            errors++;
        end

        while (u_vga_controller.u_vga_timing.V_count !== 16'd492) begin
            @(posedge clk);
            #1;
        end
        if (u_vga_controller.raw_vsync !== 1'b1) begin
            $display("[FAIL] TEST 5: VSYNC expected 1 at line 492, got %b", u_vga_controller.raw_vsync);
            errors++;
        end else $display("[PASS] TEST 5 & 6: VSYNC pulse and video_on boundaries verified.");

        // =====================================================================
        // TEST 7 — PIXEL ADDRESS GENERATION CHECK
        // =====================================================================
        // Wait for active video start (H=0, V=0)
        while (!(u_vga_controller.u_vga_timing.H_count == 16'd0 && u_vga_controller.u_vga_timing.V_count == 16'd0)) begin
            @(posedge clk);
            #1;
        end
        if (vga_fb_addr !== 21'd0) begin
            $display("[FAIL] TEST 7: Pixel (0,0) address expected 0, got %0d", vga_fb_addr);
            errors++;
        end

        @(posedge clk); #1; // Pixel (1,0)
        if (vga_fb_addr !== 21'd4) begin
            $display("[FAIL] TEST 7: Pixel (1,0) address expected 4, got %0d", vga_fb_addr);
            errors++;
        end

        @(posedge clk); #1; // Pixel (2,0)
        if (vga_fb_addr !== 21'd8) begin
            $display("[FAIL] TEST 7: Pixel (2,0) address expected 8, got %0d", vga_fb_addr);
            errors++;
        end
        $display("[PASS] TEST 7: Pixel address generator verified with 21-bit precision.");

        // =====================================================================
        // TEST 8 & 9 — FRAMEBUFFER CPU WRITE & READBACK
        // =====================================================================
        // Write during blanking or active (arbitration will handle stalls)
        axi_write(FB_BASE + 32'd0,  32'h00FF_0000, 4'b1111, resp_val); // Red
        axi_write(FB_BASE + 32'd4,  32'h0000_FF00, 4'b1111, resp_val); // Green
        axi_write(FB_BASE + 32'd8,  32'h0000_00FF, 4'b1111, resp_val); // Blue
        axi_write(FB_BASE + 32'd12, 32'h00FF_FFFF, 4'b1111, resp_val); // White

        // Readback
        axi_read(FB_BASE + 32'd0,  rdata_val, resp_val);
        if (rdata_val !== 32'h00FF_0000) begin
            $display("[FAIL] TEST 9: Word 0 readback mismatch. Expected 00FF0000, got %h", rdata_val);
            errors++;
        end

        axi_read(FB_BASE + 32'd4,  rdata_val, resp_val);
        if (rdata_val !== 32'h0000_FF00) begin
            $display("[FAIL] TEST 9: Word 1 readback mismatch. Expected 0000FF00, got %h", rdata_val);
            errors++;
        end

        axi_read(FB_BASE + 32'd8,  rdata_val, resp_val);
        if (rdata_val !== 32'h0000_00FF) begin
            $display("[FAIL] TEST 9: Word 2 readback mismatch. Expected 000000FF, got %h", rdata_val);
            errors++;
        end

        axi_read(FB_BASE + 32'd12, rdata_val, resp_val);
        if (rdata_val !== 32'h00FF_FFFF) begin
            $display("[FAIL] TEST 9: Word 3 readback mismatch. Expected 00FFFFFF, got %h", rdata_val);
            errors++;
        end else $display("[PASS] TEST 8 & 9: Framebuffer CPU writes and synchronous readbacks passed.");

        // =====================================================================
        // TEST 10 — FRAMEBUFFER WSTRB BYTE ENABLES
        // =====================================================================
        axi_write(FB_BASE + 32'd16, 32'h0000_0000, 4'b1111, resp_val);
        axi_write(FB_BASE + 32'd16, 32'h0000_00AA, 4'b0001, resp_val);
        axi_write(FB_BASE + 32'd16, 32'h0000_BB00, 4'b0010, resp_val);
        axi_write(FB_BASE + 32'd16, 32'h00CC_0000, 4'b0100, resp_val);
        axi_read(FB_BASE + 32'd16, rdata_val, resp_val);
        if (rdata_val !== 32'h00CC_BBAA) begin
            $display("[FAIL] TEST 10: WSTRB byte masking failed. Expected 00CCBBAA, got %h", rdata_val);
            errors++;
        end else $display("[PASS] TEST 10: WSTRB individual byte writes verified.");

        // =====================================================================
        // TEST 11, 12, 19 — PREDEFINED PATTERN & RGB COLOR EXTRACTION VERIFICATION
        // =====================================================================
        $display("[INFO] Verifying pipeline display of Predefined Pattern (Red, Green, Blue, White)...");
        // Wait until raster reaches (0,0) with display enabled
        while (!(u_vga_controller.u_vga_timing.H_count == 16'd0 && u_vga_controller.u_vga_timing.V_count == 16'd0)) begin
            @(posedge clk);
            #1;
        end

        // Word 0 (Red): Sampled at H=1 due to 1-clock synchronous SRAM latency
        @(posedge clk); #1; // H = 1
        if (red !== 8'hFF || green !== 8'h00 || blue !== 8'h00) begin
            $display("[FAIL] TEST 11/12/19: Pixel 0 RGB mismatch! Expected (FF,00,00), got (%h,%h,%h)", red, green, blue);
            errors++;
        end

        // Word 1 (Green): Sampled at H=2
        @(posedge clk); #1; // H = 2
        if (red !== 8'h00 || green !== 8'hFF || blue !== 8'h00) begin
            $display("[FAIL] TEST 11/12/19: Pixel 1 RGB mismatch! Expected (00,FF,00), got (%h,%h,%h)", red, green, blue);
            errors++;
        end

        // Word 2 (Blue): Sampled at H=3
        @(posedge clk); #1; // H = 3
        if (red !== 8'h00 || green !== 8'h00 || blue !== 8'hFF) begin
            $display("[FAIL] TEST 11/12/19: Pixel 2 RGB mismatch! Expected (00,00,FF), got (%h,%h,%h)", red, green, blue);
            errors++;
        end

        // Word 3 (White): Sampled at H=4
        @(posedge clk); #1; // H = 4
        if (red !== 8'hFF || green !== 8'hFF || blue !== 8'hFF) begin
            $display("[FAIL] TEST 11/12/19: Pixel 3 RGB mismatch! Expected (FF,FF,FF), got (%h,%h,%h)", red, green, blue);
            errors++;
        end else $display("[PASS] TEST 11, 12, 19: Predefined pattern scanned and RGB correctly extracted.");

        // =====================================================================
        // TEST 13 — RGB BLANKING CHECK
        // =====================================================================
        while (u_vga_controller.u_vga_timing.H_count !== 16'd642) @(posedge clk);
        #1;
        if (red !== 8'h00 || green !== 8'h00 || blue !== 8'h00) begin
            $display("[FAIL] TEST 13: RGB not forced to black during horizontal blanking! Got (%h,%h,%h)", red, green, blue);
            errors++;
        end else $display("[PASS] TEST 13: RGB blanking outside active display verified.");

        // =====================================================================
        // TEST 14 & 15 — SINGLE-PORT ARBITRATION & VGA ACTIVE PRIORITY
        // =====================================================================
        $display("[INFO] Testing CPU write contention during active visible video...");
        // Wait for active video line
        while (u_vga_controller.raw_video_on !== 1'b1) @(posedge clk);

        // Initiate CPU write in parallel with active display
        fork
            begin
                axi_write(FB_BASE + 32'd100, 32'h0055_6677, 4'b1111, resp_val);
            end
            begin
                // While write is pending, verify VGA raster maintains SRAM port control without glitching
                repeat (5) begin
                    @(posedge clk); #1;
                    if (u_vga_controller.raw_video_on && display_enable && fb_we !== 4'b0000 && fb_addr !== vga_fb_addr[20:2]) begin
                        $display("[FAIL] TEST 14/15: VGA display raster was interrupted by CPU write!");
                        errors++;
                    end
                end
            end
        join

        // Verify write cleanly completed once granted
        axi_read(FB_BASE + 32'd100, rdata_val, resp_val);
        if (rdata_val !== 32'h0055_6677) begin
            $display("[FAIL] TEST 14/15: Stalled CPU write did not correctly complete. Got %h", rdata_val);
            errors++;
        end else $display("[PASS] TEST 14 & 15: VGA priority during active display and safe CPU stalling verified.");

        // =====================================================================
        // TEST 16 & 17 — INVALID AXI ADDRESSES & FRAMEBUFFER BOUNDARIES
        // =====================================================================
        // Upper valid word (Word 307,199 @ 0x5012_BFFC)
        axi_write(32'h5012_BFFC, 32'h0012_3456, 4'b1111, resp_val);
        if (resp_val !== AXI_OKAY) begin
            $display("[FAIL] TEST 17: Valid upper boundary 0x5012_BFFC returned error %b", resp_val);
            errors++;
        end

        // Out-of-range address (0x5012_C000)
        axi_read(32'h5012_C000, rdata_val, resp_val);
        if (resp_val !== AXI_SLVERR) begin
            $display("[FAIL] TEST 16/17: Out-of-range address 0x5012_C000 expected SLVERR, got %b", resp_val);
            errors++;
        end

        // Unaligned address (0x5000_0001)
        axi_read(32'h5000_0001, rdata_val, resp_val);
        if (resp_val !== AXI_SLVERR) begin
            $display("[FAIL] TEST 16/17: Unaligned address 0x5000_0001 expected SLVERR, got %b", resp_val);
            errors++;
        end else $display("[PASS] TEST 16 & 17: Framebuffer range boundaries and SLVERR responses verified.");

        // =====================================================================
        // TEST 18 — VGA STATUS REGISTER VERIFICATION
        // =====================================================================
        // While in active video with display on
        while (u_vga_controller.raw_video_on !== 1'b1) @(posedge clk);
        axi_read(ADDR_VGA_STATUS, rdata_val, resp_val);
        if (rdata_val[0] !== 1'b1 || rdata_val[1] !== 1'b1) begin
            $display("[FAIL] TEST 18: VGA_STATUS in active video expected [1:0]=2'b11, got %b", rdata_val[1:0]);
            errors++;
        end else $display("[PASS] TEST 18: VGA_STATUS active video and busy flags verified.");

        // =====================================================================
        // TEST 20 — SIMPLE SOFTWARE-CONTROLLED UPDATE
        // =====================================================================
        // Modify pixel 0 from Red to Blue
        axi_write(FB_BASE + 32'd0, 32'h0000_00FF, 4'b1111, resp_val); // Blue

        // Scan next frame at (0,0)
        while (!(u_vga_controller.u_vga_timing.H_count == 16'd0 && u_vga_controller.u_vga_timing.V_count == 16'd0)) begin
            @(posedge clk);
            #1;
        end
        @(posedge clk); #1; // H = 1
        if (red !== 8'h00 || green !== 8'h00 || blue !== 8'hFF) begin
            $display("[FAIL] TEST 20: Software update failed! Expected Blue (00,00,FF), got (%h,%h,%h)", red, green, blue);
            errors++;
        end else $display("[PASS] TEST 20: Runtime software framebuffer update verified.");

        // =====================================================================
        // TEST 22 — AXI RESPONSE STABILITY & BACKPRESSURE
        // =====================================================================
        // Read with backpressure (rready held low initially)
        @(posedge clk);
        s_axi_araddr  <= ADDR_VGA_CTRL;
        s_axi_arvalid <= 1'b1;
        s_axi_rready  <= 1'b0;

        while (!s_axi_arready) @(posedge clk);
        @(posedge clk);
        s_axi_arvalid <= 1'b0;

        while (!s_axi_rvalid) @(posedge clk);
        // Hold RREADY low for 3 cycles and verify RDATA and RVALID remain stable
        repeat (3) begin
            @(posedge clk); #1;
            if (s_axi_rvalid !== 1'b1 || s_axi_rdata !== 32'h0000_0001 || s_axi_rresp !== AXI_OKAY) begin
                $display("[FAIL] TEST 22: AXI Read response unstable under backpressure!");
                errors++;
            end
        end
        s_axi_rready <= 1'b1;
        @(posedge clk);
        s_axi_rready <= 1'b0;
        $display("[PASS] TEST 22: AXI response stability under master backpressure verified.");

        // =====================================================================
        // SUMMARY
        // =====================================================================
        $display("================================================================");
        if (errors == 0) begin
            $display("                  VGA VERIFICATION PASSED                       ");
            $display("              All directed test cases succeeded!                ");
        end else begin
            $display("                  VGA VERIFICATION FAILED                       ");
            $display("              Total errors detected: %0d                        ", errors);
        end
        $display("================================================================");
        $finish;
    end

endmodule
