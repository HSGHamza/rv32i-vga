`ifndef AXI_LITE_SEQUENCER_SV
`define AXI_LITE_SEQUENCER_SV

class axi_lite_sequencer extends uvm_sequencer #(axi_lite_item);
  `uvm_component_utils(axi_lite_sequencer)

  function new(string name = "axi_lite_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass : axi_lite_sequencer

`endif // AXI_LITE_SEQUENCER_SV
