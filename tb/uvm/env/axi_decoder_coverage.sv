`ifndef AXI_DECODER_COVERAGE_SV
`define AXI_DECODER_COVERAGE_SV

class axi_decoder_coverage extends uvm_subscriber #(axi_lite_item);
  `uvm_component_utils(axi_decoder_coverage)

  axi_lite_item cur_item;

  covergroup cg_axi_decoder;
    option.per_instance = 1;
    option.comment      = "AXI Decoder Functional Coverage";

    // Transaction Type
    cp_op: coverpoint cur_item.op {
      bins read_op  = {axi_lite_types_pkg::AXI_READ};
      bins write_op = {axi_lite_types_pkg::AXI_WRITE};
    }

    // Address Region
    cp_region: coverpoint cur_item.target_region {
      bins data_mem    = {axi_lite_types_pkg::REGION_DATA_MEM};
      bins vga_reg     = {axi_lite_types_pkg::REGION_VGA_REG};
      bins framebuffer = {axi_lite_types_pkg::REGION_FRAMEBUFFER};
      bins unmapped    = {axi_lite_types_pkg::REGION_UNMAPPED};
    }

    // Byte Strobes
    cp_strb: coverpoint cur_item.strb {
      bins full_word  = {4'b1111};
      bins lower_half = {4'b0011};
      bins upper_half = {4'b1100};
      bins byte0      = {4'b0001};
      bins byte1      = {4'b0010};
      bins byte2      = {4'b0100};
      bins byte3      = {4'b1000};
    }

    // Response Codes
    cp_resp: coverpoint cur_item.resp {
      bins okay   = {axi_lite_types_pkg::AXI_RESP_OKAY};
      bins slverr = {axi_lite_types_pkg::AXI_RESP_SLVERR};
    }

    // Crosses
    cx_op_region: cross cp_op, cp_region;
    cx_region_resp: cross cp_region, cp_resp;

  endgroup : cg_axi_decoder

  function new(string name = "axi_decoder_coverage", uvm_component parent = null);
    super.new(name, parent);
    cg_axi_decoder = new();
  endfunction

  function void write(axi_lite_item t);
    cur_item = t;
    cg_axi_decoder.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV_REPORT", $sformatf("AXI Decoder Functional Coverage: %0.2f%%", cg_axi_decoder.get_coverage()), UVM_LOW)
  endfunction

endclass : axi_decoder_coverage

`endif // AXI_DECODER_COVERAGE_SV
