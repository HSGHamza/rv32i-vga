`ifndef AXI_DECODER_ENV_SV
`define AXI_DECODER_ENV_SV

class axi_decoder_env extends uvm_env;
  `uvm_component_utils(axi_decoder_env)

  axi_lite_agent         master_agent;
  axi_lite_agent         s0_agent;
  axi_lite_agent         s1_agent;
  axi_decoder_scoreboard scoreboard;
  axi_decoder_coverage   coverage;

  function new(string name = "axi_decoder_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Master Agent (Active - drives transactions to DUT)
    master_agent = axi_lite_agent::type_id::create("master_agent", this);

    // Slave 0 Agent (Passive - monitors traffic delivered to Data RAM)
    uvm_config_db#(uvm_active_passive_enum)::set(this, "s0_agent", "is_active", UVM_PASSIVE);
    s0_agent = axi_lite_agent::type_id::create("s0_agent", this);

    // Slave 1 Agent (Passive - monitors traffic delivered to VGA Subsystem)
    uvm_config_db#(uvm_active_passive_enum)::set(this, "s1_agent", "is_active", UVM_PASSIVE);
    s1_agent = axi_lite_agent::type_id::create("s1_agent", this);

    // Verification Scoreboard & Functional Coverage
    scoreboard = axi_decoder_scoreboard::type_id::create("scoreboard", this);
    coverage   = axi_decoder_coverage::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect Monitor Analysis Ports to Scoreboard Exports
    master_agent.item_ap.connect(scoreboard.master_export);
    s0_agent.item_ap.connect(scoreboard.s0_export);
    s1_agent.item_ap.connect(scoreboard.s1_export);

    // Connect Master Monitor to Functional Coverage Subscriber
    master_agent.item_ap.connect(coverage.analysis_export);
  endfunction

endclass : axi_decoder_env

`endif // AXI_DECODER_ENV_SV
