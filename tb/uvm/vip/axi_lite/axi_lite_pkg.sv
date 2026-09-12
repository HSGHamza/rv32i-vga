`timescale 1ns / 1ps

`ifndef AXI_LITE_PKG_SV
`define AXI_LITE_PKG_SV

`include "uvm_macros.svh"

package axi_lite_pkg;
  import uvm_pkg::*;
  import axi_lite_types_pkg::*;

  `include "axi_lite_item.sv"
  `include "axi_lite_sequencer.sv"
  `include "axi_lite_driver.sv"
  `include "axi_lite_monitor.sv"
  `include "axi_lite_agent.sv"
  `include "axi_lite_seq_lib.sv"

endpackage : axi_lite_pkg

`endif // AXI_LITE_PKG_SV
