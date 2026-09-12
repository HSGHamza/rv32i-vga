`ifndef AXI_LITE_ITEM_SV
`define AXI_LITE_ITEM_SV

class axi_lite_item extends uvm_sequence_item;

  // Transaction control
  rand axi_lite_types_pkg::axi_op_e      op;
  rand bit [31:0]                        addr;
  rand bit [31:0]                        data;
  rand bit [3:0]                         strb;
  rand int unsigned                      pre_delay;
  rand axi_lite_types_pkg::axi_region_e  target_region;

  // Response (observed from DUT)
  axi_lite_types_pkg::axi_resp_e         resp;

  `uvm_object_utils_begin(axi_lite_item)
    `uvm_field_enum(axi_lite_types_pkg::axi_op_e, op, UVM_ALL_ON)
    `uvm_field_int(addr, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(data, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(strb, UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(pre_delay, UVM_ALL_ON | UVM_DEC)
    `uvm_field_enum(axi_lite_types_pkg::axi_region_e, target_region, UVM_ALL_ON)
    `uvm_field_enum(axi_lite_types_pkg::axi_resp_e, resp, UVM_ALL_ON)
  `uvm_object_utils_end

  // Constraints
  constraint c_align {
    addr[1:0] == 2'b00; // 32-bit aligned accesses
  }

  constraint c_strb {
    strb inside {4'b1111, 4'b0011, 4'b1100, 4'b0001, 4'b0010, 4'b0100, 4'b1000};
  }

  constraint c_delay {
    pre_delay inside {[0:5]};
  }

  constraint c_region {
    if (target_region == axi_lite_types_pkg::REGION_DATA_MEM) {
      addr inside {[32'h0000_0000 : 32'h0000_00FC]};
    } else if (target_region == axi_lite_types_pkg::REGION_VGA_REG) {
      addr inside {[32'h1000_0000 : 32'h1000_001C]};
    } else if (target_region == axi_lite_types_pkg::REGION_FRAMEBUFFER) {
      addr inside {[32'h5000_0000 : 32'h5000_01FC]}; // Focused subset for fast sim
    } else {
      !(addr inside {[32'h0000_0000 : 32'h0000_00FF],
                     [32'h1000_0000 : 32'h1000_001F],
                     [32'h5000_0000 : 32'h5012_BFFF]});
      addr[31:28] inside {4'h2, 4'h3, 4'h4, 4'h6, 4'h7, 4'h8, 4'hF};
    }
  }

  function new(string name = "axi_lite_item");
    super.new(name);
    op = axi_lite_types_pkg::AXI_WRITE;
    addr = 32'h0;
    data = 32'h0;
    strb = 4'hF;
    pre_delay = 0;
    target_region = axi_lite_types_pkg::REGION_DATA_MEM;
    resp = axi_lite_types_pkg::AXI_RESP_OKAY;
  endfunction

  function string convert2string();
    return $sformatf("op=%s addr=0x%08x data=0x%08x strb=0x%1x region=%s resp=%s delay=%0d",
                     op.name(), addr, data, strb, target_region.name(), resp.name(), pre_delay);
  endfunction

endclass : axi_lite_item

`endif // AXI_LITE_ITEM_SV
