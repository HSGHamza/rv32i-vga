`ifndef AXI_DECODER_SCOREBOARD_SV
`define AXI_DECODER_SCOREBOARD_SV

`uvm_analysis_imp_decl(_master)
`uvm_analysis_imp_decl(_s0)
`uvm_analysis_imp_decl(_s1)

class axi_decoder_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi_decoder_scoreboard)

  uvm_analysis_imp_master #(axi_lite_item, axi_decoder_scoreboard) master_export;
  uvm_analysis_imp_s0     #(axi_lite_item, axi_decoder_scoreboard) s0_export;
  uvm_analysis_imp_s1     #(axi_lite_item, axi_decoder_scoreboard) s1_export;

  // Expected queues for crossbar verification
  axi_lite_item s0_expected_q[$];
  axi_lite_item s1_expected_q[$];

  // Statistics counters
  int unsigned master_trans_cnt   = 0;
  int unsigned s0_trans_cnt       = 0;
  int unsigned s1_trans_cnt       = 0;
  int unsigned unmapped_trans_cnt = 0;
  int unsigned pass_cnt           = 0;
  int unsigned error_cnt          = 0;

  function new(string name = "axi_decoder_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    master_export = new("master_export", this);
    s0_export     = new("s0_export", this);
    s1_export     = new("s1_export", this);
  endfunction

  // Master Transaction Evaluation
  function void write_master(axi_lite_item item);
    master_trans_cnt++;
    `uvm_info("SCB_MST", $sformatf("Observed Master Transaction: %s", item.convert2string()), UVM_HIGH)

    case (item.target_region)
      axi_lite_types_pkg::REGION_DATA_MEM: begin
        axi_lite_item exp_item;
        $cast(exp_item, item.clone());
        s0_expected_q.push_back(exp_item);
        `uvm_info("SCB_DECODE", $sformatf("Addr 0x%08x decoded to SLAVE 0 (RAM)", item.addr), UVM_HIGH)
      end

      axi_lite_types_pkg::REGION_VGA_REG,
      axi_lite_types_pkg::REGION_FRAMEBUFFER: begin
        axi_lite_item exp_item;
        $cast(exp_item, item.clone());
        s1_expected_q.push_back(exp_item);
        `uvm_info("SCB_DECODE", $sformatf("Addr 0x%08x decoded to SLAVE 1 (VGA Subsystem)", item.addr), UVM_HIGH)
      end

      axi_lite_types_pkg::REGION_UNMAPPED: begin
        unmapped_trans_cnt++;
        if (item.resp != axi_lite_types_pkg::AXI_RESP_SLVERR) begin
          `uvm_error("SCB_ERR_RESP", $sformatf("Unmapped addr 0x%08x expected SLVERR (0x2), but got %s (0x%0x)",
                                               item.addr, item.resp.name(), item.resp))
          error_cnt++;
        end else begin
          `uvm_info("SCB_PASS", $sformatf("PASS: Unmapped addr 0x%08x correctly returned SLVERR", item.addr), UVM_MEDIUM)
          pass_cnt++;
        end
      end
    endcase
  endfunction

  // Slave 0 (Data Memory) Transaction Verification
  function void write_s0(axi_lite_item item);
    s0_trans_cnt++;
    if (s0_expected_q.size() == 0) begin
      `uvm_error("SCB_UNEXPECTED_S0", $sformatf("Unexpected transaction received on Slave 0: %s", item.convert2string()))
      error_cnt++;
      return;
    end

    begin
      axi_lite_item exp = s0_expected_q.pop_front();
      if (exp.addr == item.addr && exp.op == item.op) begin
        if (exp.op == axi_lite_types_pkg::AXI_WRITE && exp.data !== item.data) begin
          `uvm_error("SCB_DATA_MISMATCH_S0", $sformatf("Slave 0 Write Data mismatch! Exp: 0x%08x, Act: 0x%08x", exp.data, item.data))
          error_cnt++;
        end else begin
          `uvm_info("SCB_PASS", $sformatf("PASS: Slave 0 matched addr=0x%08x op=%s", item.addr, item.op.name()), UVM_MEDIUM)
          pass_cnt++;
        end
      end else begin
        `uvm_error("SCB_MISMATCH_S0", $sformatf("Slave 0 mismatch! Exp Addr: 0x%08x, Act Addr: 0x%08x", exp.addr, item.addr))
        error_cnt++;
      end
    end
  endfunction

  // Slave 1 (VGA Subsystem) Transaction Verification
  function void write_s1(axi_lite_item item);
    s1_trans_cnt++;
    if (s1_expected_q.size() == 0) begin
      `uvm_error("SCB_UNEXPECTED_S1", $sformatf("Unexpected transaction received on Slave 1: %s", item.convert2string()))
      error_cnt++;
      return;
    end

    begin
      axi_lite_item exp = s1_expected_q.pop_front();
      if (exp.addr == item.addr && exp.op == item.op) begin
        if (exp.op == axi_lite_types_pkg::AXI_WRITE && exp.data !== item.data) begin
          `uvm_error("SCB_DATA_MISMATCH_S1", $sformatf("Slave 1 Write Data mismatch! Exp: 0x%08x, Act: 0x%08x", exp.data, item.data))
          error_cnt++;
        end else begin
          `uvm_info("SCB_PASS", $sformatf("PASS: Slave 1 matched addr=0x%08x op=%s", item.addr, item.op.name()), UVM_MEDIUM)
          pass_cnt++;
        end
      end else begin
        `uvm_error("SCB_MISMATCH_S1", $sformatf("Slave 1 mismatch! Exp Addr: 0x%08x, Act Addr: 0x%08x", exp.addr, item.addr))
        error_cnt++;
      end
    end
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (s0_expected_q.size() > 0) begin
      `uvm_error("SCB_LEAK_S0", $sformatf("%0d transactions remained unserviced in Slave 0 expected queue!", s0_expected_q.size()))
      error_cnt += s0_expected_q.size();
    end
    if (s1_expected_q.size() > 0) begin
      `uvm_error("SCB_LEAK_S1", $sformatf("%0d transactions remained unserviced in Slave 1 expected queue!", s1_expected_q.size()))
      error_cnt += s1_expected_q.size();
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB_REPORT", "==================================================", UVM_LOW)
    `uvm_info("SCB_REPORT", "        AXI DECODER SCOREBOARD FINAL REPORT       ", UVM_LOW)
    `uvm_info("SCB_REPORT", "==================================================", UVM_LOW)
    `uvm_info("SCB_REPORT", $sformatf("  Total Master Transactions : %0d", master_trans_cnt), UVM_LOW)
    `uvm_info("SCB_REPORT", $sformatf("  Slave 0 (RAM) Routed      : %0d", s0_trans_cnt), UVM_LOW)
    `uvm_info("SCB_REPORT", $sformatf("  Slave 1 (VGA) Routed      : %0d", s1_trans_cnt), UVM_LOW)
    `uvm_info("SCB_REPORT", $sformatf("  Unmapped Error Responses  : %0d", unmapped_trans_cnt), UVM_LOW)
    `uvm_info("SCB_REPORT", $sformatf("  PASSED Checks             : %0d", pass_cnt), UVM_LOW)
    `uvm_info("SCB_REPORT", $sformatf("  FAILED Checks             : %0d", error_cnt), UVM_LOW)
    `uvm_info("SCB_REPORT", "==================================================", UVM_LOW)
    if (error_cnt == 0 && master_trans_cnt > 0) begin
      `uvm_info("SCB_REPORT", "  STATUS: *** TEST PASSED (NO MISMATCHES) ***", UVM_LOW)
    end else if (master_trans_cnt == 0) begin
      `uvm_warning("SCB_REPORT", "  STATUS: *** NO TRANSACTIONS EVALUATED ***")
    end else begin
      `uvm_error("SCB_REPORT", $sformatf("  STATUS: *** TEST FAILED WITH %0d ERRORS ***", error_cnt))
    end
    `uvm_info("SCB_REPORT", "==================================================", UVM_LOW)
  endfunction

endclass : axi_decoder_scoreboard

`endif // AXI_DECODER_SCOREBOARD_SV
