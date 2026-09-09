`timescale 1ns / 1ps

module soc_top_tb;

    // -------------------------------------------------------------------------
    // Clock & Reset
    // -------------------------------------------------------------------------
    logic        clk;
    logic        reset;

    // -------------------------------------------------------------------------
    // Physical VGA Pins from SoC
    // -------------------------------------------------------------------------
    logic        Hsync;
    logic        Vsync;
    logic [7:0]  red;
    logic [7:0]  green;
    logic [7:0]  blue;

    // -------------------------------------------------------------------------
    // Debug Monitoring Signals
    // -------------------------------------------------------------------------
    logic [31:0] pcRegister;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic        mem_write;
    logic        mem_read;
    logic        cpu_stall;

    int errors = 0;

    // -------------------------------------------------------------------------
    // Device Under Test (DUT): Complete RV32I-AXI-VGA SoC
    // -------------------------------------------------------------------------
    soc_top #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(32),
        .FB_WIDTH      (640),
        .FB_HEIGHT     (480),
        .DATA_MEM_BASE (32'h0000_0000),
        .DATA_MEM_SIZE (32'h0000_0100),
        .VGA_REG_BASE  (32'h1000_0000),
        .VGA_REG_SIZE  (32'h0000_0010),
        .FB_BASE       (32'h5000_0000),
        .FB_SIZE       (32'h0012_C000)
    ) dut_soc (
        .clk        (clk),
        .reset      (reset),

        // Physical VGA Output Pins
        .Hsync      (Hsync),
        .Vsync      (Vsync),
        .red        (red),
        .green      (green),
        .blue       (blue),

        // Core Debug Monitoring Ports
        .pcRegister (pcRegister),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_write  (mem_write),
        .mem_read   (mem_read),
        .cpu_stall  (cpu_stall)
    );

    // -------------------------------------------------------------------------
    // Clock: 25 MHz Pixel Clock (40ns period)
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #20 clk = ~clk;

    // -------------------------------------------------------------------------
    // Helper task to load instructions into CPU instruction memory
    // -------------------------------------------------------------------------
    task load_instruction(input int word_index, input logic [31:0] instr);
        dut_soc.u_cpu_datapath.instr_mem.memory[word_index*4 + 0] = instr[7:0];
        dut_soc.u_cpu_datapath.instr_mem.memory[word_index*4 + 1] = instr[15:8];
        dut_soc.u_cpu_datapath.instr_mem.memory[word_index*4 + 2] = instr[23:16];
        dut_soc.u_cpu_datapath.instr_mem.memory[word_index*4 + 3] = instr[31:24];
    endtask

    // -------------------------------------------------------------------------
    // Test Procedure
    // -------------------------------------------------------------------------
    initial begin
        $display("================================================================");
        $display("   STARTING END-TO-END RV32I -> AXI -> VGA GRAPHICS TESTBENCH   ");
        $display("================================================================");

        reset = 1;

        // VCD Waveform generation for GTKWave
        $dumpfile("soc_top.vcd");
        $dumpvars(0, soc_top_tb);

        // ---------------------------------------------------------------------
        // CPU instructions are loaded directly from instructions.hex via
        // instructionMemory.v ($readmemh).
        // ---------------------------------------------------------------------
        $display("[INFO] Instructions loaded from instructions.hex by instructionMemory module.");

        #100;
        @(posedge clk);
        reset = 0;
        $display("[INFO] CPU Reset deasserted. Running RISC-V graphics program...");

        // Wait for CPU to finish executing program and reach halt loop at PC = 0x4C
        fork
            begin
                while (pcRegister !== 32'h0000_004C) begin
                    @(posedge clk);
                    #1;
                    $display("T=%0t PC=%h instr=%h stall=%b wr=%b addr=%h wdata=%h",
                             $time, pcRegister, dut_soc.u_cpu_datapath.instruction,
                             cpu_stall, mem_write, mem_addr, mem_wdata);
                end
                $display("[PASS] CPU completed rendering sequence and reached PC = 0x4C.");
            end
            begin
                repeat (200) @(posedge clk);
                if (pcRegister !== 32'h0000_004C) begin
                    $display("[FAIL][TIMEOUT] CPU failed to reach PC=0x4C in time. Current PC = %h", pcRegister);
                    errors++;
                end
            end
        join_any

        #40;

        // ---------------------------------------------------------------------
        // Check 1: Data Memory Write & Readback via AXI
        // ---------------------------------------------------------------------
        if (dut_soc.u_cpu_datapath.registerFile.x2 !== 32'h0000_0042) begin
            $display("[FAIL] x2 expected 0x0000_0042 from Data Memory LW, got %h",
                     dut_soc.u_cpu_datapath.registerFile.x2);
            errors++;
        end else begin
            $display("[PASS] Check 1: Data Memory readback verified: x2 = 0x42.");
        end

        // ---------------------------------------------------------------------
        // Check 2: VGA Control Register display_enable via AXI
        // ---------------------------------------------------------------------
        if (dut_soc.display_enable !== 1'b1) begin
            $display("[FAIL] VGA display_enable is NOT 1!");
            errors++;
        end else begin
            $display("[PASS] Check 2: VGA display_enable confirmed set to 1 via AXI MMIO.");
        end

        // ---------------------------------------------------------------------
        // Check 3: Framebuffer SRAM Memory Content Verification
        // ---------------------------------------------------------------------
        if (dut_soc.u_framebuffer_sram.memory[0] !== 32'h00FF_0000) begin
            $display("[FAIL] Framebuffer Word 0 (Red) expected 0x00FF_0000, got %h",
                     dut_soc.u_framebuffer_sram.memory[0]);
            errors++;
        end else begin
            $display("[PASS] Check 3a: Framebuffer Word 0 holds Red pixel (0x00FF_0000).");
        end

        if (dut_soc.u_framebuffer_sram.memory[64] !== 32'h0000_FF00) begin
            $display("[FAIL] Framebuffer Word 64 (Green) expected 0x0000_FF00, got %h",
                     dut_soc.u_framebuffer_sram.memory[64]);
            errors++;
        end else begin
            $display("[PASS] Check 3b: Framebuffer Word 64 holds Green pixel (0x0000_FF00).");
        end

        if (dut_soc.u_framebuffer_sram.memory[128] !== 32'h0000_00FF) begin
            $display("[FAIL] Framebuffer Word 128 (Blue) expected 0x0000_00FF, got %h",
                     dut_soc.u_framebuffer_sram.memory[128]);
            errors++;
        end else begin
            $display("[PASS] Check 3c: Framebuffer Word 128 holds Blue pixel (0x0000_00FF).");
        end

        if (dut_soc.u_framebuffer_sram.memory[192] !== 32'h00FF_FFFF) begin
            $display("[FAIL] Framebuffer Word 192 (White) expected 0x00FF_FFFF, got %h",
                     dut_soc.u_framebuffer_sram.memory[192]);
            errors++;
        end else begin
            $display("[PASS] Check 3d: Framebuffer Word 192 holds White pixel (0x00FF_FFFF).");
        end

        if (dut_soc.u_framebuffer_sram.memory[640] !== 32'h00FF_0000) begin
            $display("[FAIL] Framebuffer Word 640 (Scanline 1 Red) expected 0x00FF_0000, got %h",
                     dut_soc.u_framebuffer_sram.memory[640]);
            errors++;
        end else begin
            $display("[PASS] Check 3e: Framebuffer Word 640 holds Scanline 1 Red pixel (0x00FF_0000).");
        end

        // ---------------------------------------------------------------------
        // Check 4: LIVE PHYSICAL VGA PIN VERIFICATION (Scanline 0)
        // ---------------------------------------------------------------------
        $display("[INFO] Monitoring physical VGA output pins during active display raster...");

        // 4a. Wait for raster beam to reach Pixel 64 (Green)
        while (dut_soc.u_vga_controller.H_count !== 16'd65) @(negedge clk);
        if (red !== 8'h00 || green !== 8'hFF || blue !== 8'h00) begin
            $display("[FAIL] Physical VGA pins at Pixel 64 expected RGB (0x00, 0xFF, 0x00), got (%h, %h, %h)",
                     red, green, blue);
            errors++;
        end else begin
            $display("[PASS] Check 4a: VGA physical pins output pure GREEN (0x00, 0xFF, 0x00) at Pixel 64!");
        end

        // 4b. Wait for raster beam to reach Pixel 128 (Blue)
        while (dut_soc.u_vga_controller.H_count !== 16'd129) @(negedge clk);
        if (red !== 8'h00 || green !== 8'h00 || blue !== 8'hFF) begin
            $display("[FAIL] Physical VGA pins at Pixel 128 expected RGB (0x00, 0x00, 0xFF), got (%h, %h, %h)",
                     red, green, blue);
            errors++;
        end else begin
            $display("[PASS] Check 4b: VGA physical pins output pure BLUE (0x00, 0x00, 0xFF) at Pixel 128!");
        end

        // 4c. Wait for raster beam to reach Pixel 192 (White)
        while (dut_soc.u_vga_controller.H_count !== 16'd193) @(negedge clk);
        if (red !== 8'hFF || green !== 8'hFF || blue !== 8'hFF) begin
            $display("[FAIL] Physical VGA pins at Pixel 192 expected RGB (0xFF, 0xFF, 0xFF), got (%h, %h, %h)",
                     red, green, blue);
            errors++;
        end else begin
            $display("[PASS] Check 4c: VGA physical pins output pure WHITE (0xFF, 0xFF, 0xFF) at Pixel 192!");
        end

        // 4d. Wait for raster beam to reach Horizontal Blanking Interval (H >= 640)
        while (dut_soc.u_vga_controller.H_count !== 16'd645) @(negedge clk);
        if (red !== 8'h00 || green !== 8'h00 || blue !== 8'h00) begin
            $display("[FAIL] Physical VGA pins during blanking expected Black (0,0,0), got (%h, %h, %h)",
                     red, green, blue);
            errors++;
        end else begin
            $display("[PASS] Check 4d: VGA physical pins correctly blanked to BLACK outside visible area.");
        end

        // 4e. Verify active-low Hsync pulse in [656, 751]
        while (dut_soc.u_vga_controller.H_count !== 16'd660) @(negedge clk);
        if (Hsync !== 1'b0) begin
            $display("[FAIL] Hsync physical pin expected active-low (0) in sync region, got %b", Hsync);
            errors++;
        end else begin
            $display("[PASS] Check 4e: Hsync physical pin correctly asserts active-low (0) in sync interval.");
        end

        // ---------------------------------------------------------------------
        // Check 5: LIVE PHYSICAL VGA PIN VERIFICATION (Scanline 1, Pixel 0 Red)
        // ---------------------------------------------------------------------
        // Scanline 1 starts when V_count = 1. Pixel 0 is displayed when H_count = 1 on Scanline 1.
        while (!(dut_soc.u_vga_controller.V_count == 16'd1 && dut_soc.u_vga_controller.H_count == 16'd1)) @(negedge clk);
        if (red !== 8'hFF || green !== 8'h00 || blue !== 8'h00) begin
            $display("[FAIL] Physical VGA pins at Scanline 1 Pixel 0 expected RED (0xFF, 0x00, 0x00), got (%h, %h, %h)",
                     red, green, blue);
            errors++;
        end else begin
            $display("[PASS] Check 5: VGA physical pins output pure RED (0xFF, 0x00, 0x00) on Scanline 1 Pixel 0!");
        end

        // ---------------------------------------------------------------------
        // 5. FULL-FRAME RASTER CAPTURE FROM PHYSICAL VGA PINS (640x480)
        // ---------------------------------------------------------------------
        $display("----------------------------------------------------------------");
        $display("[INFO] Starting Full-Frame Video Capture directly from VGA pins...");
        $dumpoff; // Stop VCD waveform dumping to maximize simulation speed

        capture_vga_frame("vga_display.ppm");

        // ---------------------------------------------------------------------
        // SUMMARY
        // ---------------------------------------------------------------------
        $display("================================================================");
        if (errors == 0) begin
            $display("   COMPLETE GRAPHICS FLOW VERIFIED FROM RV32I TO VGA DISPLAY!   ");
            $display("   1. RV32I executed code & rendered pixels to Framebuffer.     ");
            $display("   2. AXI-Lite Bridge, Decoder, & VGA Registers functioned 100%%. ");
            $display("   3. Physical pins (red, green, blue, Hsync) matched exactly!   ");
            $display("   4. Full 640x480 frame captured to vga_display.ppm!           ");
            $display("   GRAPHICS PIPELINE FROM RV32I TO SCREEN IS FULLY OPERATIONAL! ");
        end else begin
            $display("   GRAPHICS PIPELINE TEST FAILED with %0d errors!                ", errors);
        end
        $display("================================================================");
        $finish;
    end

    // -------------------------------------------------------------------------
    // Helper task to capture 1 complete 640x480 frame from physical VGA pins
    // -------------------------------------------------------------------------
    task capture_vga_frame(input string filename);
        int fd;
        int x, y;
        logic [7:0] frame_r [0:479][0:639];
        logic [7:0] frame_g [0:479][0:639];
        logic [7:0] frame_b [0:479][0:639];

        $display("[INFO] Synchronizing with start of new VGA frame (V_count=0, H_count=0)...");
        while (!(dut_soc.u_vga_controller.V_count == 16'd0 && dut_soc.u_vga_controller.H_count == 16'd0)) @(negedge clk);

        $display("[INFO] Active video frame started. Capturing 640x480 physical pixels...");
        for (y = 0; y < 480; y++) begin
            for (x = 0; x < 640; x++) begin
                while (!(dut_soc.u_vga_controller.V_count == y && dut_soc.u_vga_controller.H_count == (x + 1))) @(negedge clk);
                frame_r[y][x] = red;
                frame_g[y][x] = green;
                frame_b[y][x] = blue;
            end
        end

        $display("[INFO] Raster capture complete! Writing PPM image: %s...", filename);
        fd = $fopen(filename, "wb");
        if (fd == 0) begin
            $display("[ERROR] Failed to open %s for binary writing!", filename);
            errors++;
        end else begin
            $fwrite(fd, "P6\n640 480\n255\n");
            for (y = 0; y < 480; y++) begin
                for (x = 0; x < 640; x++) begin
                    $fwrite(fd, "%c%c%c", frame_r[y][x], frame_g[y][x], frame_b[y][x]);
                end
            end
            $fclose(fd);
            $display("[SUCCESS] Successfully exported 640x480 display output to %s (%0d bytes)!", filename, 640*480*3 + 15);
        end
    endtask

endmodule
