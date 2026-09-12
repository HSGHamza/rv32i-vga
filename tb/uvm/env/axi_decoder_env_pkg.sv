`timescale 1ns / 1ps

`ifndef AXI_DECODER_ENV_PKG_SV
`define AXI_DECODER_ENV_PKG_SV

`include "uvm_macros.svh"

package axi_decoder_env_pkg;
  import uvm_pkg::*;
  import axi_lite_types_pkg::*;
  import axi_lite_pkg::*;

  `include "axi_decoder_scoreboard.sv"
  `include "axi_decoder_coverage.sv"
  `include "axi_decoder_env.sv"

endpackage : axi_decoder_env_pkg

`endif // AXI_DECODER_ENV_PKG_SV
