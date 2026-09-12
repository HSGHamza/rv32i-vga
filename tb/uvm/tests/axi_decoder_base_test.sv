`ifndef AXI_DECODER_BASE_TEST_SV
`define AXI_DECODER_BASE_TEST_SV

class axi_decoder_base_test extends uvm_test;
  `uvm_component_utils(axi_decoder_base_test)

  axi_decoder_env env;

  function new(string name = "axi_decoder_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi_decoder_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

endclass : axi_decoder_base_test

`endif // AXI_DECODER_BASE_TEST_SV
