`ifndef AXI_LITE_SEQ_LIB_SV
`define AXI_LITE_SEQ_LIB_SV

// Base Sequence
class axi_lite_base_sequence extends uvm_sequence #(axi_lite_item);
  `uvm_object_utils(axi_lite_base_sequence)

  function new(string name = "axi_lite_base_sequence");
    super.new(name);
  endfunction

  task write_word(input bit [31:0] addr, input bit [31:0] data, input bit [3:0] strb = 4'hF);
    req = axi_lite_item::type_id::create("write_word_req");
    start_item(req);
    req.op        = axi_lite_types_pkg::AXI_WRITE;
    req.addr      = addr;
    req.data      = data;
    req.strb      = strb;
    req.pre_delay = 0;
    finish_item(req);
  endtask

  task read_word(input bit [31:0] addr);
    req = axi_lite_item::type_id::create("read_word_req");
    start_item(req);
    req.op        = axi_lite_types_pkg::AXI_READ;
    req.addr      = addr;
    req.pre_delay = 0;
    finish_item(req);
  endtask
endclass : axi_lite_base_sequence

// Directed Sanity Sequence
class axi_lite_sanity_seq extends axi_lite_base_sequence;
  `uvm_object_utils(axi_lite_sanity_seq)

  function new(string name = "axi_lite_sanity_seq");
    super.new(name);
  endfunction

  task body();
    `uvm_info("SANITY_SEQ", "Starting directed sanity transactions to all valid regions...", UVM_LOW)

    // 1. Target Slave 0: Data RAM (0x0000_0000)
    write_word(32'h0000_0010, 32'hA5A5_1234, 4'hF);
    read_word(32'h0000_0010);

    write_word(32'h0000_0024, 32'hCAFE_BABE, 4'hF);
    read_word(32'h0000_0024);

    // 2. Target Slave 1: VGA Control Registers (0x1000_0000)
    write_word(32'h1000_0000, 32'h0000_0001, 4'hF); // VGA_CTRL: display_enable = 1
    read_word(32'h1000_0000);

    // 3. Target Slave 1: Framebuffer Memory (0x5000_0000)
    write_word(32'h5000_0000, 32'h00FF_0000, 4'hF); // Red pixel at (0, 0)
    read_word(32'h5000_0000);

    write_word(32'h5000_0080, 32'h0000_FF00, 4'hF); // Green pixel
    read_word(32'h5000_0080);

    `uvm_info("SANITY_SEQ", "Completed directed sanity transactions.", UVM_LOW)
  endtask
endclass : axi_lite_sanity_seq

// Unmapped Address / Error Slave Sequence
class axi_lite_unmapped_seq extends axi_lite_base_sequence;
  `uvm_object_utils(axi_lite_unmapped_seq)

  function new(string name = "axi_lite_unmapped_seq");
    super.new(name);
  endfunction

  task body();
    `uvm_info("UNMAPPED_SEQ", "Testing illegal/unmapped addresses to verify SLVERR response...", UVM_LOW)

    // Addresses in the holes between valid slaves
    write_word(32'h0000_1000, 32'hDEAD_0001, 4'hF);
    read_word(32'h0000_1000);

    write_word(32'h2000_0000, 32'hDEAD_0002, 4'hF);
    read_word(32'h2000_0000);

    write_word(32'h7000_0000, 32'hDEAD_0003, 4'hF);
    read_word(32'h7000_0000);

    write_word(32'hFFFF_0000, 32'hDEAD_0004, 4'hF);
    read_word(32'hFFFF_0000);

    `uvm_info("UNMAPPED_SEQ", "Completed unmapped address tests.", UVM_LOW)
  endtask
endclass : axi_lite_unmapped_seq

// Constrained-Random Sequence
class axi_lite_random_seq extends axi_lite_base_sequence;
  `uvm_object_utils(axi_lite_random_seq)

  rand int unsigned num_trans;
  constraint c_num { num_trans inside {[50:100]}; }

  function new(string name = "axi_lite_random_seq");
    super.new(name);
    num_trans = 50;
  endfunction

  task body();
    `uvm_info("RAND_SEQ", $sformatf("Generating %0d constrained-random transactions...", num_trans), UVM_LOW)
    for (int i = 0; i < num_trans; i++) begin
      req = axi_lite_item::type_id::create($sformatf("rand_item_%0d", i));
      start_item(req);
      if (!req.randomize()) begin
        `uvm_error("RAND_ERR", "Randomization failed for axi_lite_item")
      end
      finish_item(req);
    end
    `uvm_info("RAND_SEQ", "Completed random transactions.", UVM_LOW)
  endtask
endclass : axi_lite_random_seq

// Concurrent / Back-to-Back Burst Sequence
class axi_lite_concurrent_seq extends axi_lite_base_sequence;
  `uvm_object_utils(axi_lite_concurrent_seq)

  function new(string name = "axi_lite_concurrent_seq");
    super.new(name);
  endfunction

  task body();
    `uvm_info("CONCURRENT_SEQ", "Starting zero-delay back-to-back writes and reads...", UVM_LOW)
    for (int i = 0; i < 20; i++) begin
      write_word(32'h0000_0000 + (i * 4), 32'h1000_0000 + i, 4'hF);
      read_word(32'h0000_0000 + (i * 4));
      write_word(32'h5000_0000 + (i * 4), 32'h5000_0000 + i, 4'hF);
      read_word(32'h5000_0000 + (i * 4));
    end
    `uvm_info("CONCURRENT_SEQ", "Completed concurrent test sequences.", UVM_LOW)
  endtask
endclass : axi_lite_concurrent_seq

`endif // AXI_LITE_SEQ_LIB_SV
