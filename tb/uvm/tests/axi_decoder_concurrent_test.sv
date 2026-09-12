`ifndef AXI_DECODER_CONCURRENT_TEST_SV
`define AXI_DECODER_CONCURRENT_TEST_SV

class axi_decoder_concurrent_test extends axi_decoder_base_test;
  `uvm_component_utils(axi_decoder_concurrent_test)

  function new(string name = "axi_decoder_concurrent_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi_lite_concurrent_seq seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "Starting AXI Decoder Concurrent Burst Test...", UVM_LOW)
    seq = axi_lite_concurrent_seq::type_id::create("concurrent_seq");
    seq.start(env.master_agent.sequencer);

    #100ns;
    `uvm_info("TEST", "Finished AXI Decoder Concurrent Burst Test.", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass : axi_decoder_concurrent_test

`endif // AXI_DECODER_CONCURRENT_TEST_SV
