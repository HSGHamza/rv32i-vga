`ifndef AXI_LITE_AGENT_SV
`define AXI_LITE_AGENT_SV

class axi_lite_agent extends uvm_agent;
  `uvm_component_utils(axi_lite_agent)

  axi_lite_driver    driver;
  axi_lite_sequencer sequencer;
  axi_lite_monitor   monitor;

  uvm_analysis_port #(axi_lite_item) item_ap;

  function new(string name = "axi_lite_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    item_ap = new("item_ap", this);
    monitor = axi_lite_monitor::type_id::create("monitor", this);

    if (get_is_active() == UVM_ACTIVE) begin
      driver    = axi_lite_driver::type_id::create("driver", this);
      sequencer = axi_lite_sequencer::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    monitor.item_ap.connect(item_ap);

    if (get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

endclass : axi_lite_agent

`endif // AXI_LITE_AGENT_SV
