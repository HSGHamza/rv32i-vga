`timescale 1ns / 1ps

module vga_tb;

    // DUT Signals
    reg         clk;
    reg         rst;
    wire [15:0] H_count;
    wire [15:0] V_count;
    wire        Hsync;
    wire        Vsync;
    wire        video_on;

    // Test tracking variables
    integer errors;
    integer i;

    // Instantiate Design Under Test (DUT)
    vga_timing dut (
        .clk(clk),
        .rst(rst),
        .H_count(H_count),
        .V_count(V_count),
        .Hsync(Hsync),
        .Vsync(Vsync),
        .video_on(video_on)
    );

    // Clock generation: 25 MHz (40ns period -> 20ns high, 20ns low)
    always #20 clk = ~clk;

    initial begin
        // Initialize inputs
        clk = 0;
        rst = 1;
        errors = 0;

        $display("==================================================");
        $display("          STARTING VGA_TIMING TESTBENCH           ");
        $display("==================================================");

        // ----------------------------------------------------
        // Test 1 — Reset Verification
        // ----------------------------------------------------
        #100; // Hold reset for 100ns
        @(negedge clk);
        if (H_count !== 16'd0 || V_count !== 16'd0) begin
            $display("[FAIL] Test 1 (Reset): Expected H_count=0, V_count=0. Got H=%0d, V=%0d", H_count, V_count);
            errors = errors + 1;
        end else begin
            $display("[PASS] Test 1 (Reset): H_count=0, V_count=0 after reset.");
        end

        // Release reset synchronously
        @(posedge clk);
        #1 rst = 0;

        // ----------------------------------------------------
        // Test 2 — Horizontal Counting (0 -> 1 -> ... -> 799 -> 0)
        // ----------------------------------------------------
        for (i = 0; i < 800; i = i + 1) begin
            if (H_count !== i[15:0]) begin
                $display("[FAIL] Test 2 (Horizontal count): Expected H_count=%0d, Got %0d", i, H_count);
                errors = errors + 1;
            end
            @(posedge clk);
            #1; // Sample shortly after clock edge
        end

        // After 800 clocks, H_count should wrap back to 0
        if (H_count !== 16'd0) begin
            $display("[FAIL] Test 2 (Horizontal rollover): Expected H_count=0 after 799, Got %0d", H_count);
            errors = errors + 1;
        end else begin
            $display("[PASS] Test 2 (Horizontal counting): Counts 0 to 799 and wraps to 0 correctly.");
        end

        // ----------------------------------------------------
        // Test 3 — Vertical Counting (Increments on H_count = 799 rollover)
        // ----------------------------------------------------
        // We just wrapped to line 1. V_count should now be 1.
        if (V_count !== 16'd1) begin
            $display("[FAIL] Test 3 (Vertical count): Expected V_count=1 after one full horizontal line, Got %0d", V_count);
            errors = errors + 1;
        end else begin
            $display("[PASS] Test 3 (Vertical counting): V_count increments correctly when H_count wraps from 799.");
        end

        // ----------------------------------------------------
        // Test 4 — HSYNC Check
        // H_count = 655 -> Hsync = 1
        // H_count = 656 -> Hsync = 0
        // H_count = 751 -> Hsync = 0
        // H_count = 752 -> Hsync = 1
        // ----------------------------------------------------
        // Run until H_count = 655
        while (H_count !== 16'd655) begin
            @(posedge clk);
            #1;
        end
        if (Hsync !== 1'b1) begin
            $display("[FAIL] Test 4 (HSYNC): At H_count=655, expected Hsync=1, Got %b", Hsync);
            errors = errors + 1;
        end

        @(posedge clk); #1; // H_count = 656
        if (Hsync !== 1'b0) begin
            $display("[FAIL] Test 4 (HSYNC): At H_count=656, expected Hsync=0, Got %b", Hsync);
            errors = errors + 1;
        end

        while (H_count !== 16'd751) begin
            @(posedge clk);
            #1;
        end
        if (Hsync !== 1'b0) begin
            $display("[FAIL] Test 4 (HSYNC): At H_count=751, expected Hsync=0, Got %b", Hsync);
            errors = errors + 1;
        end

        @(posedge clk); #1; // H_count = 752
        if (Hsync !== 1'b1) begin
            $display("[FAIL] Test 4 (HSYNC): At H_count=752, expected Hsync=1, Got %b", Hsync);
            errors = errors + 1;
        end else begin
            $display("[PASS] Test 4 (HSYNC): Hsync asserted active-low (0) strictly in [656, 751].");
        end

        // ----------------------------------------------------
        // Test 5 & 6 — Advance frames to check VSYNC & video_on boundary conditions
        // Test 5 (VSYNC):
        // V_count = 489 -> Vsync = 1
        // V_count = 490 -> Vsync = 0
        // V_count = 491 -> Vsync = 0
        // V_count = 492 -> Vsync = 1
        //
        // Test 6 (video_on):
        // H=639, V=479 -> video_on = 1
        // H=640, V=479 -> video_on = 0
        // H=639, V=480 -> video_on = 0
        // ----------------------------------------------------

        // Advance until V_count = 479
        while (V_count !== 16'd479) begin
            @(posedge clk);
            #1;
        end

        // Test 6 check: H=639, V=479 -> video_on = 1
        while (H_count !== 16'd639) begin
            @(posedge clk);
            #1;
        end
        if (video_on !== 1'b1) begin
            $display("[FAIL] Test 6 (video_on): Expected video_on=1 at H=639, V=479, Got %b", video_on);
            errors = errors + 1;
        end

        // Test 6 check: H=640, V=479 -> video_on = 0
        @(posedge clk); #1; // H=640, V=479
        if (video_on !== 1'b0) begin
            $display("[FAIL] Test 6 (video_on): Expected video_on=0 at H=640, V=479, Got %b", video_on);
            errors = errors + 1;
        end

        // Advance to V_count = 480
        while (V_count !== 16'd480) begin
            @(posedge clk);
            #1;
        end

        // Test 6 check: H=639, V=480 -> video_on = 0
        while (H_count !== 16'd639) begin
            @(posedge clk);
            #1;
        end
        if (video_on !== 1'b0) begin
            $display("[FAIL] Test 6 (video_on): Expected video_on=0 at H=639, V=480, Got %b", video_on);
            errors = errors + 1;
        end else begin
            $display("[PASS] Test 6 (video_on): video_on boundaries verified correctly.");
        end

        // Advance to V_count = 489 for VSYNC check
        while (V_count !== 16'd489) begin
            @(posedge clk);
            #1;
        end
        if (Vsync !== 1'b1) begin
            $display("[FAIL] Test 5 (VSYNC): Expected Vsync=1 at V=489, Got %b", Vsync);
            errors = errors + 1;
        end

        // Advance to V_count = 490
        while (V_count !== 16'd490) begin
            @(posedge clk);
            #1;
        end
        if (Vsync !== 1'b0) begin
            $display("[FAIL] Test 5 (VSYNC): Expected Vsync=0 at V=490, Got %b", Vsync);
            errors = errors + 1;
        end

        // Advance to V_count = 491
        while (V_count !== 16'd491) begin
            @(posedge clk);
            #1;
        end
        if (Vsync !== 1'b0) begin
            $display("[FAIL] Test 5 (VSYNC): Expected Vsync=0 at V=491, Got %b", Vsync);
            errors = errors + 1;
        end

        // Advance to V_count = 492
        while (V_count !== 16'd492) begin
            @(posedge clk);
            #1;
        end
        if (Vsync !== 1'b1) begin
            $display("[FAIL] Test 5 (VSYNC): Expected Vsync=1 at V=492, Got %b", Vsync);
            errors = errors + 1;
        end else begin
            $display("[PASS] Test 5 (VSYNC): Vsync asserted active-low (0) strictly in [490, 491].");
        end

        // ----------------------------------------------------
        // Summary
        // ----------------------------------------------------
        $display("==================================================");
        if (errors == 0) begin
            $display("         ALL TESTS PASSED SUCCESSFULLY!           ");
        end else begin
            $display("         TESTBENCH FINISHED WITH %0d ERROR(S)     ", errors);
        end
        $display("==================================================");

        $finish;
    end

endmodule
