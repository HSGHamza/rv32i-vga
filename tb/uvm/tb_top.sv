`timescale 1ns / 1ps

`include "uvm_macros.svh"

module tb_top;
  import uvm_pkg::*;
  import axi_lite_types_pkg::*;
  import axi_lite_pkg::*;
  import axi_decoder_env_pkg::*;
  import axi_decoder_test_pkg::*;

  // ---------------------------------------------------------------------------
  // Clock & Reset Generator
  // ---------------------------------------------------------------------------
  logic clk;
  logic rst;

  // 100 MHz Simulation Clock (10ns period)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Synchronous Reset Assertion
  initial begin
    rst = 1;
    #40;
    @(posedge clk);
    rst = 0;
  end

  // ---------------------------------------------------------------------------
  // AXI4-Lite Interfaces
  // ---------------------------------------------------------------------------
  axi_lite_if #(32, 32) m_if  (clk, rst); // Master Side (CPU Driver / Monitor)
  axi_lite_if #(32, 32) s0_if (clk, rst); // Slave 0 (Data RAM Monitor)
  axi_lite_if #(32, 32) s1_if (clk, rst); // Slave 1 (VGA Subsystem Monitor)

  // ---------------------------------------------------------------------------
  // DUT: AXI Crossbar Decoder Interconnect
  // ---------------------------------------------------------------------------
  axi_decoder #(
      .AXI_ADDR_WIDTH(32),
      .AXI_DATA_WIDTH(32),
      .DATA_MEM_BASE (32'h0000_0000),
      .DATA_MEM_SIZE (32'h0000_0100),
      .VGA_REG_BASE  (32'h1000_0000),
      .VGA_REG_SIZE  (32'h0000_0020),
      .FB_BASE       (32'h5000_0000),
      .FB_SIZE       (32'h0012_C000)
  ) u_dut_decoder (
      .clk            (clk),
      .rst            (rst),

      // Master Interface (driven by UVM Master Agent)
      .m_axi_awaddr   (m_if.awaddr),
      .m_axi_awvalid  (m_if.awvalid),
      .m_axi_awready  (m_if.awready),
      .m_axi_wdata    (m_if.wdata),
      .m_axi_wstrb    (m_if.wstrb),
      .m_axi_wvalid   (m_if.wvalid),
      .m_axi_wready   (m_if.wready),
      .m_axi_bresp    (m_if.bresp),
      .m_axi_bvalid   (m_if.bvalid),
      .m_axi_bready   (m_if.bready),
      .m_axi_araddr   (m_if.araddr),
      .m_axi_arvalid  (m_if.arvalid),
      .m_axi_arready  (m_if.arready),
      .m_axi_rdata    (m_if.rdata),
      .m_axi_rresp    (m_if.rresp),
      .m_axi_rvalid   (m_if.rvalid),
      .m_axi_rready   (m_if.rready),

      // Slave 0 Interface (Data Memory)
      .s0_axi_awaddr  (s0_if.awaddr),
      .s0_axi_awvalid (s0_if.awvalid),
      .s0_axi_awready (s0_if.awready),
      .s0_axi_wdata   (s0_if.wdata),
      .s0_axi_wstrb   (s0_if.wstrb),
      .s0_axi_wvalid  (s0_if.wvalid),
      .s0_axi_wready  (s0_if.wready),
      .s0_axi_bresp   (s0_if.bresp),
      .s0_axi_bvalid  (s0_if.bvalid),
      .s0_axi_bready  (s0_if.bready),
      .s0_axi_araddr  (s0_if.araddr),
      .s0_axi_arvalid (s0_if.arvalid),
      .s0_axi_arready (s0_if.arready),
      .s0_axi_rdata   (s0_if.rdata),
      .s0_axi_rresp   (s0_if.rresp),
      .s0_axi_rvalid  (s0_if.rvalid),
      .s0_axi_rready  (s0_if.rready),

      // Slave 1 Interface (VGA Subsystem)
      .s1_axi_awaddr  (s1_if.awaddr),
      .s1_axi_awvalid (s1_if.awvalid),
      .s1_axi_awready (s1_if.awready),
      .s1_axi_wdata   (s1_if.wdata),
      .s1_axi_wstrb   (s1_if.wstrb),
      .s1_axi_wvalid  (s1_if.wvalid),
      .s1_axi_wready  (s1_if.wready),
      .s1_axi_bresp   (s1_if.bresp),
      .s1_axi_bvalid  (s1_if.bvalid),
      .s1_axi_bready  (s1_if.bready),
      .s1_axi_araddr  (s1_if.araddr),
      .s1_axi_arvalid (s1_if.arvalid),
      .s1_axi_arready (s1_if.arready),
      .s1_axi_rdata   (s1_if.rdata),
      .s1_axi_rresp   (s1_if.rresp),
      .s1_axi_rvalid  (s1_if.rvalid),
      .s1_axi_rready  (s1_if.rready)
  );

  // ---------------------------------------------------------------------------
  // Real Target RTL Slave 0: AXI Data Memory
  // ---------------------------------------------------------------------------
  axi_data_memory #(
      .AXI_ADDR_WIDTH(32),
      .AXI_DATA_WIDTH(32),
      .MEM_SIZE_BYTES(256),
      .BASE_ADDR     (32'h0000_0000)
  ) u_slave0_ram (
      .clk           (clk),
      .rst           (rst),
      .s_axi_awaddr  (s0_if.awaddr),
      .s_axi_awvalid (s0_if.awvalid),
      .s_axi_awready (s0_if.awready),
      .s_axi_wdata   (s0_if.wdata),
      .s_axi_wstrb   (s0_if.wstrb),
      .s_axi_wvalid  (s0_if.wvalid),
      .s_axi_wready  (s0_if.wready),
      .s_axi_bresp   (s0_if.bresp),
      .s_axi_bvalid  (s0_if.bvalid),
      .s_axi_bready  (s0_if.bready),
      .s_axi_araddr  (s0_if.araddr),
      .s_axi_arvalid (s0_if.arvalid),
      .s_axi_arready (s0_if.arready),
      .s_axi_rdata   (s0_if.rdata),
      .s_axi_rresp   (s0_if.rresp),
      .s_axi_rvalid  (s0_if.rvalid),
      .s_axi_rready  (s0_if.rready)
  );

  // ---------------------------------------------------------------------------
  // Real Target RTL Slave 1: VGA Registers & Framebuffer Subsystem
  // ---------------------------------------------------------------------------
  wire [18:0] fb_addr;
  wire [31:0] fb_wdata;
  wire [3:0]  fb_we;
  wire        fb_en;
  wire [31:0] fb_rdata;

  vga_registers #(
      .AXI_ADDR_WIDTH   (32),
      .AXI_DATA_WIDTH   (32),
      .FB_WIDTH_DEFAULT (640),
      .FB_HEIGHT_DEFAULT(480),
      .FB_BASE_DEFAULT  (32'h5000_0000)
  ) u_slave1_vga_reg (
      .clk            (clk),
      .rst            (rst),
      .btn            (4'h0),
      .sw             (4'h0),
      .s_axi_awaddr   (s1_if.awaddr),
      .s_axi_awvalid  (s1_if.awvalid),
      .s_axi_awready  (s1_if.awready),
      .s_axi_wdata    (s1_if.wdata),
      .s_axi_wstrb    (s1_if.wstrb),
      .s_axi_wvalid   (s1_if.wvalid),
      .s_axi_wready   (s1_if.wready),
      .s_axi_bresp    (s1_if.bresp),
      .s_axi_bvalid   (s1_if.bvalid),
      .s_axi_bready   (s1_if.bready),
      .s_axi_araddr   (s1_if.araddr),
      .s_axi_arvalid  (s1_if.arvalid),
      .s_axi_arready  (s1_if.arready),
      .s_axi_rdata    (s1_if.rdata),
      .s_axi_rresp    (s1_if.rresp),
      .s_axi_rvalid   (s1_if.rvalid),
      .s_axi_rready   (s1_if.rready),
      .vga_fb_req     (1'b0),
      .vga_fb_addr    (21'd0),
      .vga_video_on   (1'b0),
      .display_enable (),
      .fb_addr        (fb_addr),
      .fb_wdata       (fb_wdata),
      .fb_we          (fb_we),
      .fb_en          (fb_en),
      .fb_rdata       (fb_rdata)
  );

  framebuffer_sram #(
      .FB_WIDTH (640),
      .FB_HEIGHT(480)
  ) u_slave1_fb_sram (
      .clk  (clk),
      .en   (fb_en),
      .we   (fb_we),
      .addr (fb_addr),
      .wdata(fb_wdata),
      .rdata(fb_rdata)
  );

  // ---------------------------------------------------------------------------
  // UVM Test Execution & Database Registration
  // ---------------------------------------------------------------------------
  initial begin
    // Set virtual interfaces for UVM agents
    uvm_config_db#(virtual axi_lite_if)::set(null, "*.master_agent.*", "vif", m_if);
    uvm_config_db#(virtual axi_lite_if)::set(null, "*.s0_agent.*",     "vif", s0_if);
    uvm_config_db#(virtual axi_lite_if)::set(null, "*.s1_agent.*",     "vif", s1_if);

    // Run active UVM test (+UVM_TESTNAME=<name>)
    run_test();
  end

endmodule
