`timescale 1ns / 1ps

module vga_registers_tb;

    reg         clk;
    reg         rst;

    // AXI4-Lite signals
    reg  [31:0] s_axi_awaddr;
    reg         s_axi_awvalid;
    wire        s_axi_awready;
    reg  [31:0] s_axi_wdata;
    reg  [3:0]  s_axi_wstrb;
    reg         s_axi_wvalid;
    wire        s_axi_wready;
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready;

    reg  [31:0] s_axi_araddr;
    reg         s_axi_arvalid;
    wire        s_axi_arready;
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;
    reg         s_axi_rready;

    // VGA Controller interface sideband
    reg         vga_fb_req;
    reg  [20:0] vga_fb_addr;
    reg         vga_video_on;
    wire        display_enable;

    // Framebuffer SRAM interface
    wire [18:0] fb_addr;
    wire [31:0] fb_wdata;
    wire [3:0]  fb_we;
    wire        fb_en;
    wire [31:0] fb_rdata;

    integer errors;

    // Instantiate VGA Registers (DUT)
    vga_registers #(
        .AXI_ADDR_WIDTH   (32),
        .AXI_DATA_WIDTH   (32),
        .FB_WIDTH_DEFAULT (640),
        .FB_HEIGHT_DEFAULT(480),
        .FB_BASE_DEFAULT  (32'h5000_0000)
    ) dut_regs (
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

    // Instantiate single-port Framebuffer SRAM
    framebuffer_sram #(
        .FB_WIDTH       (640),
        .FB_HEIGHT      (480)
    ) dut_sram (
        .clk            (clk),
        .en             (fb_en),
        .we             (fb_we),
        .addr           (fb_addr),
        .wdata          (fb_wdata),
        .rdata          (fb_rdata)
    );

    // 25 MHz Pixel / Bus Clock
    always #20 clk = ~clk;

    // AXI Write Task (records response status)
    task axi_write(input [31:0] addr, input [31:0] data, input [3:0] strb, output [1:0] resp);
        begin
            @(posedge clk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= 1'b1;
            s_axi_wdata   <= data;
            s_axi_wstrb   <= strb;
            s_axi_wvalid  <= 1'b1;
            s_axi_bready  <= 1'b1;

            @(posedge clk);
            while (!s_axi_awready && !s_axi_wready) @(posedge clk);
            s_axi_awvalid <= 1'b0;
            s_axi_wvalid  <= 1'b0;

            while (!s_axi_bvalid) @(posedge clk);
            resp = s_axi_bresp;
            @(posedge clk);
            s_axi_bready  <= 1'b0;
        end
    endtask

    // AXI Read Task (records data and response status)
    task axi_read(input [31:0] addr, output [31:0] data, output [1:0] resp);
        begin
            @(posedge clk);
            s_axi_araddr  <= addr;
            s_axi_arvalid <= 1'b1;
            s_axi_rready  <= 1'b1;

            @(posedge clk);
            while (!s_axi_arready) @(posedge clk);
            s_axi_arvalid <= 1'b0;

            while (!s_axi_rvalid) @(posedge clk);
            data = s_axi_rdata;
            resp = s_axi_rresp;
            @(posedge clk);
            s_axi_rready  <= 1'b0;
        end
    endtask

    reg [31:0] rd_val;
    reg [1:0]  resp_val;

    initial begin
        clk = 0;
        rst = 1;
        errors = 0;
        s_axi_awaddr = 0;
        s_axi_awvalid = 0;
        s_axi_wdata = 0;
        s_axi_wstrb = 0;
        s_axi_wvalid = 0;
        s_axi_bready = 0;
        s_axi_araddr = 0;
        s_axi_arvalid = 0;
        s_axi_rready = 0;
        vga_fb_req = 0;
        vga_fb_addr = 0;
        vga_video_on = 0;

        #100;
        @(posedge clk);
        rst = 0;
        #20;

        $display("==================================================");
        $display("       STARTING VGA_REGISTERS & FB TESTBENCH      ");
        $display("==================================================");

        // ----------------------------------------------------
        // Test 1: Verify Register Reset Values & FB_BASE Read-Only Behavior
        // ----------------------------------------------------
        axi_read(32'h1000_0008, rd_val, resp_val); // FB_BASE
        if (rd_val !== 32'h5000_0000 || resp_val !== 2'b00) begin
            $display("[FAIL] FB_BASE reset value mismatch: expected 50000000 (OKAY), got %h (resp %b)", rd_val, resp_val);
            errors = errors + 1;
        end else $display("[PASS] FB_BASE read returns fixed 0x5000_0000");

        // Attempt writing a new address to FB_BASE (e.g., 0x6000_0000)
        axi_write(32'h1000_0008, 32'h6000_0000, 4'b1111, resp_val);
        if (resp_val !== 2'b00) begin
            $display("[FAIL] FB_BASE write did not return OKAY response");
            errors = errors + 1;
        end else $display("[PASS] FB_BASE write safely handled with OKAY response");

        // Verify FB_BASE did not change
        axi_read(32'h1000_0008, rd_val, resp_val);
        if (rd_val !== 32'h5000_0000) begin
            $display("[FAIL] FB_BASE changed after write! Expected 50000000, got %h", rd_val);
            errors = errors + 1;
        end else $display("[PASS] FB_BASE remains strictly fixed at 0x5000_0000 after write attempt");

        // ----------------------------------------------------
        // Test 2: Framebuffer Word Index 0 Access (0x5000_0000)
        // ----------------------------------------------------
        axi_write(32'h5000_0000, 32'h0011_2233, 4'b1111, resp_val);
        axi_read(32'h5000_0000, rd_val, resp_val);
        if (rd_val !== 32'h0011_2233 || resp_val !== 2'b00) begin
            $display("[FAIL] FB Word 0 (0x5000_0000) readback mismatch: expected 00112233, got %h", rd_val);
            errors = errors + 1;
        end else $display("[PASS] 0x5000_0000 correctly accessed SRAM word 0");

        // ----------------------------------------------------
        // Test 3: Framebuffer Word Index 1 Access (0x5000_0004)
        // ----------------------------------------------------
        axi_write(32'h5000_0004, 32'h0044_5566, 4'b1111, resp_val);
        axi_read(32'h5000_0004, rd_val, resp_val);
        if (rd_val !== 32'h0044_5566 || resp_val !== 2'b00) begin
            $display("[FAIL] FB Word 1 (0x5000_0004) readback mismatch: expected 00445566, got %h", rd_val);
            errors = errors + 1;
        end else $display("[PASS] 0x5000_0004 correctly accessed SRAM word 1");

        // ----------------------------------------------------
        // Test 4: Upper Valid Framebuffer Word (0x5012_BFFC -> Word 307,199)
        // ----------------------------------------------------
        axi_write(32'h5012_BFFC, 32'h00AA_BBCC, 4'b1111, resp_val);
        axi_read(32'h5012_BFFC, rd_val, resp_val);
        if (rd_val !== 32'h00AA_BBCC || resp_val !== 2'b00) begin
            $display("[FAIL] Upper FB Word (0x5012_BFFC) readback mismatch: expected 00AABBCC, got %h", rd_val);
            errors = errors + 1;
        end else $display("[PASS] Upper valid framebuffer address 0x5012_BFFC (Word 307,199) succeeded");

        // ----------------------------------------------------
        // Test 5: Out-of-Range Framebuffer Access Returns SLVERR (0x5012_C000)
        // ----------------------------------------------------
        axi_read(32'h5012_C000, rd_val, resp_val);
        if (resp_val !== 2'b10) begin
            $display("[FAIL] Out-of-range read (0x5012_C000) expected SLVERR (2'b10), got %b", resp_val);
            errors = errors + 1;
        end else $display("[PASS] Out-of-range address 0x5012_C000 returned SLVERR");

        axi_write(32'h5012_C000, 32'hFFFF_FFFF, 4'b1111, resp_val);
        if (resp_val !== 2'b10) begin
            $display("[FAIL] Out-of-range write (0x5012_C000) expected SLVERR (2'b10), got %b", resp_val);
            errors = errors + 1;
        end else $display("[PASS] Out-of-range write 0x5012_C000 returned SLVERR");

        // ----------------------------------------------------
        // Test 6: Unaligned Address Access Returns SLVERR (0x5000_0001, 0x5000_0002, 0x5000_0003)
        // ----------------------------------------------------
        axi_read(32'h5000_0001, rd_val, resp_val);
        if (resp_val !== 2'b10) begin
            $display("[FAIL] Unaligned read (0x5000_0001) expected SLVERR, got %b", resp_val);
            errors = errors + 1;
        end else $display("[PASS] Unaligned read 0x5000_0001 returned SLVERR");

        axi_write(32'h5000_0002, 32'hDEAD_BEEF, 4'b1111, resp_val);
        if (resp_val !== 2'b10) begin
            $display("[FAIL] Unaligned write (0x5000_0002) expected SLVERR, got %b", resp_val);
            errors = errors + 1;
        end else $display("[PASS] Unaligned write 0x5000_0002 returned SLVERR");

        // ----------------------------------------------------
        // Summary
        // ----------------------------------------------------
        $display("==================================================");
        if (errors == 0) begin
            $display("         ALL TESTS PASSED SUCCESSFULLY!           ");
        end else begin
            $display("         TESTBENCH FINISHED WITH %0d ERRORS        ", errors);
        end
        $display("==================================================");
        $finish;
    end

endmodule
