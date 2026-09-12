`ifndef AXI_LITE_MONITOR_SV
`define AXI_LITE_MONITOR_SV

class axi_lite_monitor extends uvm_monitor;
  `uvm_component_utils(axi_lite_monitor)

  virtual axi_lite_if vif;
  uvm_analysis_port #(axi_lite_item) item_ap;

  function new(string name = "axi_lite_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    item_ap = new("item_ap", this);
    if (!uvm_config_db#(virtual axi_lite_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF", "Virtual interface not found in uvm_config_db for axi_lite_monitor")
    end
  endfunction

  task run_phase(uvm_phase phase);
    @(negedge vif.rst);
    @(posedge vif.clk);

    fork
      monitor_writes();
      monitor_reads();
    join
  endtask

  task monitor_writes();
    bit [31:0] captured_addr;
    bit [31:0] captured_data;
    bit [3:0]  captured_strb;
    bit        have_addr;
    bit        have_data;

    forever begin
      have_addr = 0;
      have_data = 0;

      while (!(have_addr && have_data)) begin
        @(posedge vif.clk);
        if (vif.awvalid && vif.awready) begin
          captured_addr = vif.awaddr;
          have_addr = 1;
        end
        if (vif.wvalid && vif.wready) begin
          captured_data = vif.wdata;
          captured_strb = vif.wstrb;
          have_data = 1;
        end
      end

      // Wait for write response handshake
      while (!(vif.bvalid && vif.bready)) begin
        @(posedge vif.clk);
      end

      // Create transaction item
      begin
        axi_lite_item item = axi_lite_item::type_id::create("mon_write_item");
        item.op    = axi_lite_types_pkg::AXI_WRITE;
        item.addr  = captured_addr;
        item.data  = captured_data;
        item.strb  = captured_strb;
        item.resp  = axi_lite_types_pkg::axi_resp_e'(vif.bresp);
        classify_region(item);
        item_ap.write(item);
      end
    end
  endtask

  task monitor_reads();
    bit [31:0] captured_addr;

    forever begin
      while (!(vif.arvalid && vif.arready)) begin
        @(posedge vif.clk);
      end
      captured_addr = vif.araddr;

      while (!(vif.rvalid && vif.rready)) begin
        @(posedge vif.clk);
      end

      // Create transaction item
      begin
        axi_lite_item item = axi_lite_item::type_id::create("mon_read_item");
        item.op    = axi_lite_types_pkg::AXI_READ;
        item.addr  = captured_addr;
        item.data  = vif.rdata;
        item.resp  = axi_lite_types_pkg::axi_resp_e'(vif.rresp);
        classify_region(item);
        item_ap.write(item);
      end
    end
  endtask

  function void classify_region(axi_lite_item item);
    if ((item.addr >= 32'h0000_0000) && (item.addr < 32'h0000_0100)) begin
      item.target_region = axi_lite_types_pkg::REGION_DATA_MEM;
    end else if ((item.addr >= 32'h1000_0000) && (item.addr < 32'h1000_0020)) begin
      item.target_region = axi_lite_types_pkg::REGION_VGA_REG;
    end else if ((item.addr >= 32'h5000_0000) && (item.addr < 32'h5012_C000)) begin
      item.target_region = axi_lite_types_pkg::REGION_FRAMEBUFFER;
    end else begin
      item.target_region = axi_lite_types_pkg::REGION_UNMAPPED;
    end
  endfunction

endclass : axi_lite_monitor

`endif // AXI_LITE_MONITOR_SV
