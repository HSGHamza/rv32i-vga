`timescale 1ns / 1ps

`ifndef AXI_DECODER_TEST_PKG_SV
`define AXI_DECODER_TEST_PKG_SV

`include "uvm_macros.svh"

package axi_decoder_test_pkg;
  import uvm_pkg::*;
  import axi_lite_types_pkg::*;
  import axi_lite_pkg::*;
  import axi_decoder_env_pkg::*;

  `include "axi_decoder_base_test.sv"
  `include "axi_decoder_sanity_test.sv"
  `include "axi_decoder_unmapped_test.sv"
  `include "axi_decoder_random_test.sv"
  `include "axi_decoder_concurrent_test.sv"

endpackage : axi_decoder_test_pkg

`endif // AXI_DECODER_TEST_PKG_SV
