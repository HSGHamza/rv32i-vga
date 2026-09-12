`timescale 1ns / 1ps

`ifndef AXI_LITE_IF_SV
`define AXI_LITE_IF_SV

interface axi_lite_if #(
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst
);

  // Write Address Channel
  logic [AXI_ADDR_WIDTH-1:0]   awaddr;
  logic                        awvalid;
  logic                        awready;

  // Write Data Channel
  logic [AXI_DATA_WIDTH-1:0]   wdata;
  logic [AXI_DATA_WIDTH/8-1:0] wstrb;
  logic                        wvalid;
  logic                        wready;

  // Write Response Channel
  logic [1:0]                  bresp;
  logic                        bvalid;
  logic                        bready;

  // Read Address Channel
  logic [AXI_ADDR_WIDTH-1:0]   araddr;
  logic                        arvalid;
  logic                        arready;

  // Read Data Channel
  logic [AXI_DATA_WIDTH-1:0]   rdata;
  logic [1:0]                  rresp;
  logic                        rvalid;
  logic                        rready;

  // Passive Monitor Clocking Block
  clocking mon_cb @(posedge clk);
    default input #1step;
    input awaddr, awvalid, awready;
    input wdata, wstrb, wvalid, wready;
    input bresp, bvalid, bready;
    input araddr, arvalid, arready;
    input rdata, rresp, rvalid, rready;
  endclocking

  modport monitor(clocking mon_cb, input clk, input rst);

endinterface : axi_lite_if

`endif // AXI_LITE_IF_SV
