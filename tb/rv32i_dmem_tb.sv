`timescale 1ns / 1ps

module rv32i_dmem_tb;

    // -------------------------------------------------------------------------
    // Clock & Reset
    // -------------------------------------------------------------------------
    logic clk;
    logic reset;

    // -------------------------------------------------------------------------
    // CPU <-> AXI Master Bridge Interconnect
    // -------------------------------------------------------------------------
    logic [31:0] cpu_mem_addr;
    logic [31:0] cpu_mem_wdata;
    logic        cpu_mem_write;
    logic        cpu_mem_read;
    logic [31:0] cpu_mem_rdata;
    logic        cpu_stall;
    logic [31:0] pcRegister;

    // -------------------------------------------------------------------------
    // AXI Master Bridge <-> Decoder (Master Channels)
    // -------------------------------------------------------------------------
    logic [31:0] m_axi_awaddr;
    logic        m_axi_awvalid;
    logic        m_axi_awready;

    logic [31:0] m_axi_wdata;
    logic [3:0]  m_axi_wstrb;
    logic        m_axi_wvalid;
    logic        m_axi_wready;

    logic [1:0]  m_axi_bresp;
    logic        m_axi_bvalid;
    logic        m_axi_bready;

    logic [31:0] m_axi_araddr;
    logic        m_axi_arvalid;
    logic        m_axi_arready;

    logic [31:0] m_axi_rdata;
    logic [1:0]  m_axi_rresp;
    logic        m_axi_rvalid;
    logic        m_axi_rready;

    // -------------------------------------------------------------------------
    // Decoder <-> Data Memory (Slave 0 Channels)
    // -------------------------------------------------------------------------
    logic [31:0] s0_axi_awaddr;
    logic        s0_axi_awvalid;
    logic        s0_axi_awready;

    logic [31:0] s0_axi_wdata;
    logic [3:0]  s0_axi_wstrb;
    logic        s0_axi_wvalid;
    logic        s0_axi_wready;

    logic [1:0]  s0_axi_bresp;
    logic        s0_axi_bvalid;
    logic        s0_axi_bready;

    logic [31:0] s0_axi_araddr;
    logic        s0_axi_arvalid;
    logic        s0_axi_arready;

    logic [31:0] s0_axi_rdata;
    logic [1:0]  s0_axi_rresp;
    logic        s0_axi_rvalid;
    logic        s0_axi_rready;

    int errors = 0;

    // -------------------------------------------------------------------------
    // 1. RV32I Processor Datapath (from rtl/rv32i/)
    // -------------------------------------------------------------------------
    Datapath u_cpu (
        .clk        (clk),
        .reset      (reset),
        .stall      (cpu_stall),
        .mem_rdata  (cpu_mem_rdata),
        .pcRegister (pcRegister),
        .mem_addr   (cpu_mem_addr),
        .mem_wdata  (cpu_mem_wdata),
        .mem_write  (cpu_mem_write),
        .mem_read   (cpu_mem_read)
    );

    // -------------------------------------------------------------------------
    // 2. CPU-to-AXI4-Lite Master Bridge
    // -------------------------------------------------------------------------
    rv32i_axi_bridge #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(32)
    ) u_axi_bridge (
        .clk           (clk),
        .rst           (reset),

        // CPU Interface
        .cpu_mem_addr  (cpu_mem_addr),
        .cpu_mem_wdata (cpu_mem_wdata),
        .cpu_mem_write (cpu_mem_write),
        .cpu_mem_read  (cpu_mem_read),
        .cpu_mem_rdata (cpu_mem_rdata),
        .cpu_stall     (cpu_stall),

        // AXI4-Lite Master Interface
        .m_axi_awaddr  (m_axi_awaddr),
        .m_axi_awvalid (m_axi_awvalid),
        .m_axi_awready (m_axi_awready),

        .m_axi_wdata   (m_axi_wdata),
        .m_axi_wstrb   (m_axi_wstrb),
        .m_axi_wvalid  (m_axi_wvalid),
        .m_axi_wready  (m_axi_wready),

        .m_axi_bresp   (m_axi_bresp),
        .m_axi_bvalid  (m_axi_bvalid),
        .m_axi_bready  (m_axi_bready),

        .m_axi_araddr  (m_axi_araddr),
        .m_axi_arvalid (m_axi_arvalid),
        .m_axi_arready (m_axi_arready),

        .m_axi_rdata   (m_axi_rdata),
        .m_axi_rresp   (m_axi_rresp),
        .m_axi_rvalid  (m_axi_rvalid),
        .m_axi_rready  (m_axi_rready)
    );

    // -------------------------------------------------------------------------
    // 3. AXI4-Lite Decoder (Routes to Slave 0: Data Memory)
    // -------------------------------------------------------------------------
    axi_decoder #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(32),
        .DATA_MEM_BASE (32'h0000_0000),
        .DATA_MEM_SIZE (32'h0000_0100), // 256 bytes
        .VGA_REG_BASE  (32'h1000_0000),
        .VGA_REG_SIZE  (32'h0000_0010),
        .FB_BASE       (32'h5000_0000),
        .FB_SIZE       (32'h0012_C000)
    ) u_decoder (
        .clk           (clk),
        .rst           (reset),

        // Upstream Master
        .m_axi_awaddr  (m_axi_awaddr),
        .m_axi_awvalid (m_axi_awvalid),
        .m_axi_awready (m_axi_awready),

        .m_axi_wdata   (m_axi_wdata),
        .m_axi_wstrb   (m_axi_wstrb),
        .m_axi_wvalid  (m_axi_wvalid),
        .m_axi_wready  (m_axi_wready),

        .m_axi_bresp   (m_axi_bresp),
        .m_axi_bvalid  (m_axi_bvalid),
        .m_axi_bready  (m_axi_bready),

        .m_axi_araddr  (m_axi_araddr),
        .m_axi_arvalid (m_axi_arvalid),
        .m_axi_arready (m_axi_arready),

        .m_axi_rdata   (m_axi_rdata),
        .m_axi_rresp   (m_axi_rresp),
        .m_axi_rvalid  (m_axi_rvalid),
        .m_axi_rready  (m_axi_rready),

        // Downstream Slave 0 (Data Memory)
        .s0_axi_awaddr  (s0_axi_awaddr),
        .s0_axi_awvalid (s0_axi_awvalid),
        .s0_axi_awready (s0_axi_awready),

        .s0_axi_wdata   (s0_axi_wdata),
        .s0_axi_wstrb   (s0_axi_wstrb),
        .s0_axi_wvalid  (s0_axi_wvalid),
        .s0_axi_wready  (s0_axi_wready),

        .s0_axi_bresp   (s0_axi_bresp),
        .s0_axi_bvalid  (s0_axi_bvalid),
        .s0_axi_bready  (s0_axi_bready),

        .s0_axi_araddr  (s0_axi_araddr),
        .s0_axi_arvalid (s0_axi_arvalid),
        .s0_axi_arready (s0_axi_arready),

        .s0_axi_rdata   (s0_axi_rdata),
        .s0_axi_rresp   (s0_axi_rresp),
        .s0_axi_rvalid  (s0_axi_rvalid),
        .s0_axi_rready  (s0_axi_rready),

        // Downstream Slave 1 (VGA / Framebuffer - disconnected/tied off)
        .s1_axi_awaddr  (),
        .s1_axi_awvalid (),
        .s1_axi_awready (1'b0),

        .s1_axi_wdata   (),
        .s1_axi_wstrb   (),
        .s1_axi_wvalid  (),
        .s1_axi_wready  (1'b0),

        .s1_axi_bresp   (2'b00),
        .s1_axi_bvalid  (1'b0),
        .s1_axi_bready  (),

        .s1_axi_araddr  (),
        .s1_axi_arvalid (),
        .s1_axi_arready (1'b0),

        .s1_axi_rdata   (32'd0),
        .s1_axi_rresp   (2'b00),
        .s1_axi_rvalid  (1'b0),
        .s1_axi_rready  ()
    );

    // -------------------------------------------------------------------------
    // 4. AXI4-Lite 256-Byte Data Memory (Slave 0)
    // -------------------------------------------------------------------------
    axi_data_memory #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(32),
        .BASE_ADDR     (32'h0000_0000),
        .MEM_SIZE_BYTES(256)
    ) u_data_memory (
        .clk           (clk),
        .rst           (reset),

        .s_axi_awaddr  (s0_axi_awaddr),
        .s_axi_awvalid (s0_axi_awvalid),
        .s_axi_awready (s0_axi_awready),

        .s_axi_wdata   (s0_axi_wdata),
        .s_axi_wstrb   (s0_axi_wstrb),
        .s_axi_wvalid  (s0_axi_wvalid),
        .s_axi_wready  (s0_axi_wready),

        .s_axi_bresp   (s0_axi_bresp),
        .s_axi_bvalid  (s0_axi_bvalid),
        .s_axi_bready  (s0_axi_bready),

        .s_axi_araddr  (s0_axi_araddr),
        .s_axi_arvalid (s0_axi_arvalid),
        .s_axi_arready (s0_axi_arready),

        .s_axi_rdata   (s0_axi_rdata),
        .s_axi_rresp   (s0_axi_rresp),
        .s_axi_rvalid  (s0_axi_rvalid),
        .s_axi_rready  (s0_axi_rready)
    );

    // -------------------------------------------------------------------------
    // Clock: 25 MHz (40ns period)
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #20 clk = ~clk;

    // -------------------------------------------------------------------------
    // Helper task to program CPU instruction memory
    // -------------------------------------------------------------------------
    task load_instr(input int word_index, input logic [31:0] instr);
        u_cpu.instr_mem.memory[word_index*4 + 0] = instr[7:0];
        u_cpu.instr_mem.memory[word_index*4 + 1] = instr[15:8];
        u_cpu.instr_mem.memory[word_index*4 + 2] = instr[23:16];
        u_cpu.instr_mem.memory[word_index*4 + 3] = instr[31:24];
    endtask

    // -------------------------------------------------------------------------
    // Test Procedure
    // -------------------------------------------------------------------------
    initial begin
        $display("================================================================");
        $display("     STARTING RV32I CORE + AXI DECODER + DATA MEMORY TESTBENCH  ");
        $display("================================================================");

        reset = 1;

        // VCD Waveform generation for GTKWave
        $dumpfile("rv32i_dmem.vcd");
        $dumpvars(0, rv32i_dmem_tb);

        // ---------------------------------------------------------------------
        // Program Assembly Instructions
        // ---------------------------------------------------------------------
        // Instr 0:  addi x1, x0, 0x123         -> x1 = 0x0000_0123
        load_instr(0,  32'h1230_0093);

        // Instr 1:  addi x2, x0, 0x456         -> x2 = 0x0000_0456
        load_instr(1,  32'h4560_0113);

        // Instr 2:  add  x3, x1, x2            -> x3 = 0x0000_0579 (ALU, no stall)
        load_instr(2,  32'h0020_81B3);

        // Instr 3:  sw   x3, 32(x0)            -> mem[0x20] = 0x0000_0579 (AXI Store, Word 8)
        load_instr(3,  32'h0230_2023);

        // Instr 4:  lw   x4, 32(x0)            -> x4 = mem[0x20] (AXI Load, Word 8)
        load_instr(4,  32'h0200_2203);

        // Instr 5:  lui  x5, 0xDEADC           -> x5 = 0xDEADC000
        load_instr(5,  32'hDEAD_C2B7);

        // Instr 6:  addi x5, x5, -273          -> x5 = 0xDEADBEEF
        load_instr(6,  32'hEEF2_8293);

        // Instr 7:  sw   x5, 0(x0)             -> mem[0x00] = 0xDEADBEEF (AXI Store, Word 0)
        load_instr(7,  32'h0050_2023);

        // Instr 8:  lw   x6, 0(x0)             -> x6 = mem[0x00] (AXI Load, Word 0)
        load_instr(8,  32'h0000_2303);

        // Instr 9:  sw   x5, 252(x0)           -> mem[0xFC] = 0xDEADBEEF (AXI Store, Word 63)
        load_instr(9,  32'h0E50_2E23);

        // Instr 10: lw   x7, 252(x0)           -> x7 = mem[0xFC] (AXI Load, Word 63)
        load_instr(10, 32'h0FC0_2383);

        // Instr 11: beq  x0, x0, 0             -> infinite loop at PC = 0x2C
        load_instr(11, 32'h0000_0063);

        #100;
        @(posedge clk);
        reset = 0;
        $display("[INFO] Reset released. Executing RV32I code...");

        fork
            begin
                while (pcRegister !== 32'h0000_002C) begin
                    @(posedge clk);
                    #1;
                    $display("T=%0t | PC=%h | instr=%h | stall=%b | rd=%b wr=%b | addr=%h wdata=%h rdata=%h | x1=%h x2=%h x3=%h x4=%h x5=%h x6=%h x7=%h",
                             $time, pcRegister, u_cpu.instruction, cpu_stall, cpu_mem_read, cpu_mem_write, cpu_mem_addr, cpu_mem_wdata, cpu_mem_rdata,
                             u_cpu.registerFile.x1,
                             u_cpu.registerFile.x2,
                             u_cpu.registerFile.x3,
                             u_cpu.registerFile.x4,
                             u_cpu.registerFile.x5,
                             u_cpu.registerFile.x6,
                             u_cpu.registerFile.x7);
                end
                $display("[PASS] CPU reached end of program at PC = 0x2C.");
            end
            begin
                repeat (200) @(posedge clk);
                if (pcRegister !== 32'h0000_002C) begin
                    $display("[FAIL][TIMEOUT] CPU failed to reach PC=0x2C within 200 clock cycles. Current PC = %h", pcRegister);
                    errors++;
                end
            end
        join_any

        #40;

        // ---------------------------------------------------------------------
        // Check 1: ALU result
        // ---------------------------------------------------------------------
        if (u_cpu.registerFile.x3 !== 32'h0000_0579) begin
            $display("[FAIL] x3 (ALU x1 + x2) expected 0x0000_0579, got %h", u_cpu.registerFile.x3);
            errors++;
        end else begin
            $display("[PASS] TEST 1: ALU execution verified: x1 (0x123) + x2 (0x456) = x3 (0x579).");
        end

        // ---------------------------------------------------------------------
        // Check 2: Word 8 Store & Load
        // ---------------------------------------------------------------------
        if (u_cpu.registerFile.x4 !== 32'h0000_0579) begin
            $display("[FAIL] x4 expected 0x0000_0579 from Data Memory word 8 LW, got %h", u_cpu.registerFile.x4);
            errors++;
        end else begin
            $display("[PASS] TEST 2: SW and LW to Data Memory Word 8 (0x0000_0020) verified via AXI-Lite (x4 = 0x579).");
        end

        // ---------------------------------------------------------------------
        // Check 3: Word 0 Store & Load (Base address 0x0000_0000)
        // ---------------------------------------------------------------------
        if (u_cpu.registerFile.x6 !== 32'hDEAD_BEEF) begin
            $display("[FAIL] x6 expected 0xDEADBEEF from Data Memory word 0 LW, got %h", u_cpu.registerFile.x6);
            errors++;
        end else begin
            $display("[PASS] TEST 3: SW and LW to Data Memory Word 0 (0x0000_0000) verified via AXI-Lite (x6 = 0xDEADBEEF).");
        end

        // ---------------------------------------------------------------------
        // Check 4: Word 63 Store & Load (Upper boundary 0x0000_00FC)
        // ---------------------------------------------------------------------
        if (u_cpu.registerFile.x7 !== 32'hDEAD_BEEF) begin
            $display("[FAIL] x7 expected 0xDEADBEEF from Data Memory word 63 LW, got %h", u_cpu.registerFile.x7);
            errors++;
        end else begin
            $display("[PASS] TEST 4: SW and LW to Data Memory Word 63 (0x0000_00FC) verified via AXI-Lite (x7 = 0xDEADBEEF).");
        end

        // ---------------------------------------------------------------------
        // Check 5: Verify SRAM physical contents in axi_data_memory
        // ---------------------------------------------------------------------
        if (u_data_memory.memory[0] !== 32'hDEAD_BEEF) begin
            $display("[FAIL] axi_data_memory[0] expected 0xDEADBEEF, got %h", u_data_memory.memory[0]);
            errors++;
        end else begin
            $display("[PASS] TEST 5: axi_data_memory[0] physically holds 0xDEADBEEF.");
        end

        if (u_data_memory.memory[8] !== 32'h0000_0579) begin
            $display("[FAIL] axi_data_memory[8] expected 0x0000_0579, got %h", u_data_memory.memory[8]);
            errors++;
        end else begin
            $display("[PASS] TEST 6: axi_data_memory[8] physically holds 0x0000_0579.");
        end

        if (u_data_memory.memory[63] !== 32'hDEAD_BEEF) begin
            $display("[FAIL] axi_data_memory[63] expected 0xDEADBEEF, got %h", u_data_memory.memory[63]);
            errors++;
        end else begin
            $display("[PASS] TEST 7: axi_data_memory[63] physically holds 0xDEADBEEF.");
        end

        // ---------------------------------------------------------------------
        // Final Summary
        // ---------------------------------------------------------------------
        $display("================================================================");
        if (errors == 0) begin
            $display("   RV32I CORE + AXI DECODER + DATA MEMORY VERIFICATION PASSED!  ");
            $display("   Connection between RV32I, Decoder, and Data Memory is 100%% OK!");
        end else begin
            $display("   VERIFICATION FAILED with %0d errors!                         ", errors);
        end
        $display("================================================================");
        $finish;
    end

endmodule
