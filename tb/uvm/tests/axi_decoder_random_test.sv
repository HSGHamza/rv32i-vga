`ifndef AXI_DECODER_RANDOM_TEST_SV
`define AXI_DECODER_RANDOM_TEST_SV

class axi_decoder_random_test extends axi_decoder_base_test;
  `uvm_component_utils(axi_decoder_random_test)

  function new(string name = "axi_decoder_random_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi_lite_random_seq seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "Starting AXI Decoder Constrained-Random Test...", UVM_LOW)
    seq = axi_lite_random_seq::type_id::create("random_seq");
    assert(seq.randomize() with { num_trans == 100; });
    seq.start(env.master_agent.sequencer);

    #100ns;
    `uvm_info("TEST", "Finished AXI Decoder Constrained-Random Test.", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass : axi_decoder_random_test

`endif // AXI_DECODER_RANDOM_TEST_SV
