`ifndef AXI_LITE_DRIVER_SV
`define AXI_LITE_DRIVER_SV

class axi_lite_driver extends uvm_driver #(axi_lite_item);
  `uvm_component_utils(axi_lite_driver)

  virtual axi_lite_if vif;

  function new(string name = "axi_lite_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_lite_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF", "Virtual interface not found in uvm_config_db for axi_lite_driver")
    end
  endfunction

  task run_phase(uvm_phase phase);
    reset_signals();

    // Wait for reset release
    @(negedge vif.rst);
    @(posedge vif.clk);

    forever begin
      seq_item_port.get_next_item(req);
      drive_transaction(req);
      seq_item_port.item_done();
    end
  endtask

  task reset_signals();
    vif.awaddr  <= '0;
    vif.awvalid <= 1'b0;
    vif.wdata   <= '0;
    vif.wstrb   <= '0;
    vif.wvalid  <= 1'b0;
    vif.bready  <= 1'b0;
    vif.araddr  <= '0;
    vif.arvalid <= 1'b0;
    vif.rready  <= 1'b0;
  endtask

  task drive_transaction(axi_lite_item item);
    // Apply pre-transaction delay cycles
    if (item.pre_delay > 0) begin
      repeat (item.pre_delay) @(posedge vif.clk);
    end

    if (item.op == axi_lite_types_pkg::AXI_WRITE) begin
      drive_write(item);
    end else begin
      drive_read(item);
    end
  endtask

  task drive_write(axi_lite_item item);
    bit aw_done = 0;
    bit w_done  = 0;

    @(posedge vif.clk);
    vif.awaddr  <= item.addr;
    vif.awvalid <= 1'b1;
    vif.wdata   <= item.data;
    vif.wstrb   <= item.strb;
    vif.wvalid  <= 1'b1;
    vif.bready  <= 1'b1;

    while (!(aw_done && w_done)) begin
      @(posedge vif.clk);
      if (vif.awvalid && vif.awready) begin
        vif.awvalid <= 1'b0;
        aw_done = 1;
      end
      if (vif.wvalid && vif.wready) begin
        vif.wvalid <= 1'b0;
        w_done = 1;
      end
    end

    // Wait for Write Response (B channel)
    while (!vif.bvalid) begin
      @(posedge vif.clk);
    end

    item.resp = axi_lite_types_pkg::axi_resp_e'(vif.bresp);
    @(posedge vif.clk);
    vif.bready <= 1'b0;
  endtask

  task drive_read(axi_lite_item item);
    @(posedge vif.clk);
    vif.araddr  <= item.addr;
    vif.arvalid <= 1'b1;
    vif.rready  <= 1'b1;

    // Wait for address acceptance
    while (1) begin
      @(posedge vif.clk);
      if (vif.arready) begin
        vif.arvalid <= 1'b0;
        break;
      end
    end

    // Wait for Read Data (R channel)
    while (!vif.rvalid) begin
      @(posedge vif.clk);
    end

    item.data = vif.rdata;
    item.resp = axi_lite_types_pkg::axi_resp_e'(vif.rresp);
    @(posedge vif.clk);
    vif.rready <= 1'b0;
  endtask

endclass : axi_lite_driver

`endif // AXI_LITE_DRIVER_SV
