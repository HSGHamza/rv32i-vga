`timescale 1ns / 1ps

module axi_decoder_tb;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam int AXI_ADDR_WIDTH = 32;
    localparam int AXI_DATA_WIDTH = 32;

    localparam logic [1:0] AXI_OKAY   = 2'b00;
    localparam logic [1:0] AXI_SLVERR = 2'b10;

    // -------------------------------------------------------------------------
    // Signals
    // -------------------------------------------------------------------------
    logic clk;
    logic rst;

    // Master Interface (CPU Side)
    logic [AXI_ADDR_WIDTH-1:0]     m_axi_awaddr;
    logic                          m_axi_awvalid;
    logic                          m_axi_awready;

    logic [AXI_DATA_WIDTH-1:0]     m_axi_wdata;
    logic [AXI_DATA_WIDTH/8-1:0]   m_axi_wstrb;
    logic                          m_axi_wvalid;
    logic                          m_axi_wready;

    logic [1:0]                    m_axi_bresp;
    logic                          m_axi_bvalid;
    logic                          m_axi_bready;

    logic [AXI_ADDR_WIDTH-1:0]     m_axi_araddr;
    logic                          m_axi_arvalid;
    logic                          m_axi_arready;

    logic [AXI_DATA_WIDTH-1:0]     m_axi_rdata;
    logic [1:0]                    m_axi_rresp;
    logic                          m_axi_rvalid;
    logic                          m_axi_rready;

    // Slave 0 Interface (Data SRAM - Future/Reserved)
    logic [AXI_ADDR_WIDTH-1:0]     s0_axi_awaddr;
    logic                          s0_axi_awvalid;
    logic                          s0_axi_awready;
    logic [AXI_DATA_WIDTH-1:0]     s0_axi_wdata;
    logic [AXI_DATA_WIDTH/8-1:0]   s0_axi_wstrb;
    logic                          s0_axi_wvalid;
    logic                          s0_axi_wready;
    logic [1:0]                    s0_axi_bresp;
    logic                          s0_axi_bvalid;
    logic                          s0_axi_bready;
    logic [AXI_ADDR_WIDTH-1:0]     s0_axi_araddr;
    logic                          s0_axi_arvalid;
    logic                          s0_axi_arready;
    logic [AXI_DATA_WIDTH-1:0]     s0_axi_rdata;
    logic [1:0]                    s0_axi_rresp;
    logic                          s0_axi_rvalid;
    logic                          s0_axi_rready;

    // Slave 1 Interface (VGA Subsystem)
    logic [AXI_ADDR_WIDTH-1:0]     s1_axi_awaddr;
    logic                          s1_axi_awvalid;
    logic                          s1_axi_awready;
    logic [AXI_DATA_WIDTH-1:0]     s1_axi_wdata;
    logic [AXI_DATA_WIDTH/8-1:0]   s1_axi_wstrb;
    logic                          s1_axi_wvalid;
    logic                          s1_axi_wready;
    logic [1:0]                    s1_axi_bresp;
    logic                          s1_axi_bvalid;
    logic                          s1_axi_bready;
    logic [AXI_ADDR_WIDTH-1:0]     s1_axi_araddr;
    logic                          s1_axi_arvalid;
    logic                          s1_axi_arready;
    logic [AXI_DATA_WIDTH-1:0]     s1_axi_rdata;
    logic [1:0]                    s1_axi_rresp;
    logic                          s1_axi_rvalid;
    logic                          s1_axi_rready;

    // Sideband & Interconnect wires for VGA Subsystem
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

    int errors = 0;

    // -------------------------------------------------------------------------
    // DUT: AXI Decoder / Interconnect
    // -------------------------------------------------------------------------
    axi_decoder #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH)
    ) dut_decoder (
        .clk            (clk),
        .rst            (rst),

        // Master side
        .m_axi_awaddr   (m_axi_awaddr),
        .m_axi_awvalid  (m_axi_awvalid),
        .m_axi_awready  (m_axi_awready),
        .m_axi_wdata    (m_axi_wdata),
        .m_axi_wstrb    (m_axi_wstrb),
        .m_axi_wvalid   (m_axi_wvalid),
        .m_axi_wready   (m_axi_wready),
        .m_axi_bresp    (m_axi_bresp),
        .m_axi_bvalid   (m_axi_bvalid),
        .m_axi_bready   (m_axi_bready),
        .m_axi_araddr   (m_axi_araddr),
        .m_axi_arvalid  (m_axi_arvalid),
        .m_axi_arready  (m_axi_arready),
        .m_axi_rdata    (m_axi_rdata),
        .m_axi_rresp    (m_axi_rresp),
        .m_axi_rvalid   (m_axi_rvalid),
        .m_axi_rready   (m_axi_rready),

        // Slave 0 (Reserved)
        .s0_axi_awaddr  (s0_axi_awaddr),
        .s0_axi_awvalid (s0_axi_awvalid),
        .s0_axi_awready (s0_axi_awready),
        .s0_axi_wdata   (s0_axi_wdata),
        .s0_axi_wstrb   (s0_axi_wstrb),
        .s0_axi_wvalid  (s0_axi_wvalid),
        .s0_axi_wready  (s0_axi_wready),
        .s0_axi_bresp   (s0_axi_bresp),
        .s0_axi_bvalid  (s0_axi_bvalid),
        .s0_axi_bready  (s0_axi_bready),
        .s0_axi_araddr  (s0_axi_araddr),
        .s0_axi_arvalid (s0_axi_arvalid),
        .s0_axi_arready (s0_axi_arready),
        .s0_axi_rdata   (s0_axi_rdata),
        .s0_axi_rresp   (s0_axi_rresp),
        .s0_axi_rvalid  (s0_axi_rvalid),
        .s0_axi_rready  (s0_axi_rready),

        // Slave 1 (VGA Subsystem)
        .s1_axi_awaddr  (s1_axi_awaddr),
        .s1_axi_awvalid (s1_axi_awvalid),
        .s1_axi_awready (s1_axi_awready),
        .s1_axi_wdata   (s1_axi_wdata),
        .s1_axi_wstrb   (s1_axi_wstrb),
        .s1_axi_wvalid  (s1_axi_wvalid),
        .s1_axi_wready  (s1_axi_wready),
        .s1_axi_bresp   (s1_axi_bresp),
        .s1_axi_bvalid  (s1_axi_bvalid),
        .s1_axi_bready  (s1_axi_bready),
        .s1_axi_araddr  (s1_axi_araddr),
        .s1_axi_arvalid (s1_axi_arvalid),
        .s1_axi_arready (s1_axi_arready),
        .s1_axi_rdata   (s1_axi_rdata),
        .s1_axi_rresp   (s1_axi_rresp),
        .s1_axi_rvalid  (s1_axi_rvalid),
        .s1_axi_rready  (s1_axi_rready)
    );

    // -------------------------------------------------------------------------
    // Connected Slave 1: vga_registers
    // -------------------------------------------------------------------------
    vga_registers #(
        .AXI_ADDR_WIDTH   (32),
        .AXI_DATA_WIDTH   (32),
        .FB_WIDTH_DEFAULT (640),
        .FB_HEIGHT_DEFAULT(480),
        .FB_BASE_DEFAULT  (32'h5000_0000)
    ) u_vga_registers (
        .clk            (clk),
        .rst            (rst),

        .s_axi_awaddr   (s1_axi_awaddr),
        .s_axi_awvalid  (s1_axi_awvalid),
        .s_axi_awready  (s1_axi_awready),
        .s_axi_wdata    (s1_axi_wdata),
        .s_axi_wstrb    (s1_axi_wstrb),
        .s_axi_wvalid   (s1_axi_wvalid),
        .s_axi_wready   (s1_axi_wready),
        .s_axi_bresp    (s1_axi_bresp),
        .s_axi_bvalid   (s1_axi_bvalid),
        .s_axi_bready   (s1_axi_bready),

        .s_axi_araddr   (s1_axi_araddr),
        .s_axi_arvalid  (s1_axi_arvalid),
        .s_axi_arready  (s1_axi_arready),
        .s_axi_rdata    (s1_axi_rdata),
        .s_axi_rresp    (s1_axi_rresp),
        .s_axi_rvalid   (s1_axi_rvalid),
        .s_axi_rready   (s1_axi_rready),

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

    // Connected Single-Port Framebuffer SRAM
    framebuffer_sram #(
        .FB_WIDTH       (640),
        .FB_HEIGHT      (480)
    ) u_framebuffer_sram (
        .clk            (clk),
        .en             (fb_en),
        .we             (fb_we),
        .addr           (fb_addr),
        .wdata          (fb_wdata),
        .rdata          (fb_rdata)
    );

    // Connected VGA Controller
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
    // Clock Generation
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #20 clk = ~clk;

    // Tie off unused Slave 0 inputs
    assign s0_axi_awready = 1'b0;
    assign s0_axi_wready  = 1'b0;
    assign s0_axi_bvalid  = 1'b0;
    assign s0_axi_bresp   = AXI_SLVERR;
    assign s0_axi_arready = 1'b0;
    assign s0_axi_rvalid  = 1'b0;
    assign s0_axi_rresp   = AXI_SLVERR;
    assign s0_axi_rdata   = 32'd0;

    // -------------------------------------------------------------------------
    // Master Helper Tasks
    // -------------------------------------------------------------------------
    task automatic master_write_sync(
        input  logic [31:0] addr,
        input  logic [31:0] data,
        input  logic [3:0]  strb,
        output logic [1:0]  resp
    );
        @(posedge clk);
        m_axi_awaddr  <= addr;
        m_axi_awvalid <= 1'b1;
        m_axi_wdata   <= data;
        m_axi_wstrb   <= strb;
        m_axi_wvalid  <= 1'b1;
        m_axi_bready  <= 1'b1;

        @(posedge clk);
        while (!(m_axi_awready && m_axi_wready)) @(posedge clk);
        m_axi_awvalid <= 1'b0;
        m_axi_wvalid  <= 1'b0;

        while (!m_axi_bvalid) @(posedge clk);
        resp = m_axi_bresp;
        @(posedge clk);
        m_axi_bready  <= 1'b0;
    endtask

    task automatic master_write_aw_first(
        input  logic [31:0] addr,
        input  logic [31:0] data,
        input  logic [3:0]  strb,
        output logic [1:0]  resp
    );
        @(posedge clk);
        m_axi_awaddr  <= addr;
        m_axi_awvalid <= 1'b1;
        m_axi_wvalid  <= 1'b0;

        while (!m_axi_awready) @(posedge clk);
        @(posedge clk);
        m_axi_awvalid <= 1'b0;
        m_axi_wdata   <= data;
        m_axi_wstrb   <= strb;
        m_axi_wvalid  <= 1'b1;
        m_axi_bready  <= 1'b1;

        while (!m_axi_wready) @(posedge clk);
        @(posedge clk);
        m_axi_wvalid <= 1'b0;

        while (!m_axi_bvalid) @(posedge clk);
        resp = m_axi_bresp;
        @(posedge clk);
        m_axi_bready <= 1'b0;
    endtask

    task automatic master_write_w_first(
        input  logic [31:0] addr,
        input  logic [31:0] data,
        input  logic [3:0]  strb,
        output logic [1:0]  resp
    );
        @(posedge clk);
        m_axi_wdata   <= data;
        m_axi_wstrb   <= strb;
        m_axi_wvalid  <= 1'b1;
        m_axi_awvalid <= 1'b0;

        while (!m_axi_wready) @(posedge clk);
        @(posedge clk);
        m_axi_wvalid  <= 1'b0;
        m_axi_awaddr  <= addr;
        m_axi_awvalid <= 1'b1;
        m_axi_bready  <= 1'b1;

        while (!m_axi_awready) @(posedge clk);
        @(posedge clk);
        m_axi_awvalid <= 1'b0;

        while (!m_axi_bvalid) @(posedge clk);
        resp = m_axi_bresp;
        @(posedge clk);
        m_axi_bready <= 1'b0;
    endtask

    task automatic master_read(
        input  logic [31:0] addr,
        output logic [31:0] data,
        output logic [1:0]  resp
    );
        @(posedge clk);
        m_axi_araddr  <= addr;
        m_axi_arvalid <= 1'b1;
        m_axi_rready  <= 1'b1;

        while (!m_axi_arready) @(posedge clk);
        @(posedge clk);
        m_axi_arvalid <= 1'b0;

        while (!m_axi_rvalid) @(posedge clk);
        data = m_axi_rdata;
        resp = m_axi_rresp;
        @(posedge clk);
        m_axi_rready <= 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Main Verification Procedure
    // -------------------------------------------------------------------------
    logic [31:0] rdata;
    logic [1:0]  resp;

    initial begin
        rst           = 1;
        m_axi_awaddr  = 0;
        m_axi_awvalid = 0;
        m_axi_wdata   = 0;
        m_axi_wstrb   = 0;
        m_axi_wvalid  = 0;
        m_axi_bready  = 0;
        m_axi_araddr  = 0;
        m_axi_arvalid = 0;
        m_axi_rready  = 0;

        #100;
        @(posedge clk);
        rst = 0;
        #40;

        $display("================================================================");
        $display("          STARTING AXI4-LITE DECODER VERIFICATION               ");
        $display("================================================================");

        // ---------------------------------------------------------------------
        // Check 1 & 2: 0x1000_0000 (VGA_CTRL) Write/Read selects Slave 1
        // ---------------------------------------------------------------------
        master_write_sync(32'h1000_0000, 32'h0000_0001, 4'b1111, resp);
        if (resp !== AXI_OKAY) begin
            $display("[FAIL] 0x1000_0000 write failed with response %b", resp);
            errors++;
        end
        master_read(32'h1000_0000, rdata, resp);
        if (rdata !== 32'h0000_0001 || resp !== AXI_OKAY) begin
            $display("[FAIL] 0x1000_0000 read failed: data=%h, resp=%b", rdata, resp);
            errors++;
        end else begin
            $display("[PASS] 0x1000_0000 (VGA_CTRL) correctly routed to Slave 1.");
        end

        // ---------------------------------------------------------------------
        // Check 3: 0x1000_0004 (VGA_STATUS) selects Slave 1
        // ---------------------------------------------------------------------
        master_read(32'h1000_0004, rdata, resp);
        if (resp !== AXI_OKAY) begin
            $display("[FAIL] 0x1000_0004 (VGA_STATUS) read failed with resp %b", resp);
            errors++;
        end else begin
            $display("[PASS] 0x1000_0004 (VGA_STATUS) correctly routed to Slave 1.");
        end

        // ---------------------------------------------------------------------
        // Check 4: 0x1000_0008 (FB_BASE) selects Slave 1
        // ---------------------------------------------------------------------
        master_read(32'h1000_0008, rdata, resp);
        if (rdata !== 32'h5000_0000 || resp !== AXI_OKAY) begin
            $display("[FAIL] 0x1000_0008 (FB_BASE) read failed: data=%h, resp=%b", rdata, resp);
            errors++;
        end else begin
            $display("[PASS] 0x1000_0008 (FB_BASE) correctly routed to Slave 1.");
        end

        // ---------------------------------------------------------------------
        // Check 5: 0x1000_000C (FB_SIZE) selects Slave 1
        // ---------------------------------------------------------------------
        master_read(32'h1000_000C, rdata, resp);
        if (rdata !== {16'd480, 16'd640} || resp !== AXI_OKAY) begin
            $display("[FAIL] 0x1000_000C (FB_SIZE) read failed: data=%h, resp=%b", rdata, resp);
            errors++;
        end else begin
            $display("[PASS] 0x1000_000C (FB_SIZE) correctly routed to Slave 1.");
        end

        // ---------------------------------------------------------------------
        // Check 6: 0x5000_0000 (FB Base / Word 0) selects Slave 1
        // ---------------------------------------------------------------------
        master_write_sync(32'h5000_0000, 32'h00AA_BBCC, 4'b1111, resp);
        master_read(32'h5000_0000, rdata, resp);
        if (rdata !== 32'h00AA_BBCC || resp !== AXI_OKAY) begin
            $display("[FAIL] 0x5000_0000 Framebuffer write/read failed: data=%h", rdata);
            errors++;
        end else begin
            $display("[PASS] 0x5000_0000 (Framebuffer Word 0) correctly routed to Slave 1.");
        end

        // ---------------------------------------------------------------------
        // Check 7: Middle Framebuffer Address (0x5009_6000) selects Slave 1
        // ---------------------------------------------------------------------
        master_write_sync(32'h5009_6000, 32'h0011_2233, 4'b1111, resp);
        master_read(32'h5009_6000, rdata, resp);
        if (rdata !== 32'h0011_2233 || resp !== AXI_OKAY) begin
            $display("[FAIL] Middle Framebuffer (0x5009_6000) write/read failed: data=%h", rdata);
            errors++;
        end else begin
            $display("[PASS] Middle Framebuffer address 0x5009_6000 correctly routed to Slave 1.");
        end

        // ---------------------------------------------------------------------
        // Check 8: 0x5012_BFFC (Upper FB Word 307,199) selects Slave 1
        // ---------------------------------------------------------------------
        master_write_sync(32'h5012_BFFC, 32'h0044_5566, 4'b1111, resp);
        master_read(32'h5012_BFFC, rdata, resp);
        if (rdata !== 32'h0044_5566 || resp !== AXI_OKAY) begin
            $display("[FAIL] Upper Framebuffer (0x5012_BFFC) write/read failed: data=%h", rdata);
            errors++;
        end else begin
            $display("[PASS] Upper Framebuffer address 0x5012_BFFC correctly routed to Slave 1.");
        end

        // ---------------------------------------------------------------------
        // Check 9: Unmapped Address Returns SLVERR (0x2000_0000 & 0x6000_0000)
        // ---------------------------------------------------------------------
        master_read(32'h2000_0000, rdata, resp);
        if (resp !== AXI_SLVERR) begin
            $display("[FAIL] Unmapped read 0x2000_0000 expected SLVERR, got %b", resp);
            errors++;
        end else begin
            $display("[PASS] Unmapped address 0x2000_0000 read returned SLVERR.");
        end

        master_write_sync(32'h6000_0000, 32'hDEAD_BEEF, 4'b1111, resp);
        if (resp !== AXI_SLVERR) begin
            $display("[FAIL] Unmapped write 0x6000_0000 expected SLVERR, got %b", resp);
            errors++;
        end else begin
            $display("[PASS] Unmapped address 0x6000_0000 write returned SLVERR.");
        end

        // ---------------------------------------------------------------------
        // Check 10, 11, 12: Independent AW and W arrivals
        // ---------------------------------------------------------------------
        // AW before W
        master_write_aw_first(32'h5000_0004, 32'h0012_3456, 4'b1111, resp);
        master_read(32'h5000_0004, rdata, resp);
        if (rdata !== 32'h0012_3456 || resp !== AXI_OKAY) begin
            $display("[FAIL] AW-first write failed: data=%h", rdata);
            errors++;
        end else begin
            $display("[PASS] AW arriving before W operates cleanly.");
        end

        // W before AW
        master_write_w_first(32'h5000_0008, 32'h0078_9ABC, 4'b1111, resp);
        master_read(32'h5000_0008, rdata, resp);
        if (rdata !== 32'h0078_9ABC || resp !== AXI_OKAY) begin
            $display("[FAIL] W-first write failed: data=%h", rdata);
            errors++;
        end else begin
            $display("[PASS] W arriving before AW operates cleanly.");
        end

        // ---------------------------------------------------------------------
        // Check 15 & 16: Response stability under backpressure
        // ---------------------------------------------------------------------
        @(posedge clk);
        m_axi_araddr  <= 32'h1000_0000;
        m_axi_arvalid <= 1'b1;
        m_axi_rready  <= 1'b0;

        while (!m_axi_arready) @(posedge clk);
        @(posedge clk);
        m_axi_arvalid <= 1'b0;

        while (!m_axi_rvalid) @(posedge clk);
        // Hold RREADY low and verify RVALID and RDATA stability
        repeat (3) begin
            @(posedge clk); #1;
            if (m_axi_rvalid !== 1'b1 || m_axi_rdata !== 32'h0000_0001) begin
                $display("[FAIL] Master read response unstable under backpressure!");
                errors++;
            end
        end
        m_axi_rready <= 1'b1;
        @(posedge clk);
        m_axi_rready <= 1'b0;
        $display("[PASS] Response stability verified under master backpressure.");

        // ---------------------------------------------------------------------
        // Check 19: Slave 0 is never selected
        // ---------------------------------------------------------------------
        if (s0_axi_awvalid !== 1'b0 || s0_axi_arvalid !== 1'b0) begin
            $display("[FAIL] Slave 0 was erroneously selected!");
            errors++;
        end else begin
            $display("[PASS] Slave 0 is never asserted in current configuration.");
        end

        // ---------------------------------------------------------------------
        // SUMMARY
        // ---------------------------------------------------------------------
        $display("================================================================");
        if (errors == 0) begin
            $display("              AXI DECODER VERIFICATION PASSED                   ");
        end else begin
            $display("              AXI DECODER VERIFICATION FAILED (Errors: %0d)     ", errors);
        end
        $display("================================================================");
        $finish;
    end

endmodule
