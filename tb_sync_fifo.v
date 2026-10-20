// Self-checking testbench: a reference model runs alongside the DUT and
// every cycle compares read data, count, full and empty.
`timescale 1ns/1ps
module tb_sync_fifo;
    localparam W = 8, D = 8;
    reg clk = 0, rst_n = 0, wr_en = 0, rd_en = 0;
    reg  [W-1:0] wdata = 0;
    wire [W-1:0] rdata;
    wire full, empty;
    wire [$clog2(D+1)-1:0] count;

    sync_fifo #(W, D) dut (.clk(clk), .rst_n(rst_n), .wr_en(wr_en), .rd_en(rd_en),
                           .wdata(wdata), .rdata(rdata), .full(full),
                           .empty(empty), .count(count));
    always #5 clk = ~clk;

    // ---------- reference model ----------
    reg [W-1:0] ref_mem [0:D-1];
    integer ref_wp = 0, ref_rp = 0, ref_cnt = 0, errors = 0;
    reg [W-1:0] exp_data;
    reg exp_valid = 0, g_wr, g_rd;

    always @(posedge clk) begin
        exp_valid = 0;
        if (!rst_n) begin ref_wp = 0; ref_rp = 0; ref_cnt = 0; end
        else begin
            g_wr = wr_en && (ref_cnt < D);   // same gating as the spec
            g_rd = rd_en && (ref_cnt > 0);
            if (g_rd) begin
                exp_data = ref_mem[ref_rp]; exp_valid = 1;
                ref_rp = (ref_rp + 1) % D;
            end
            if (g_wr) begin
                ref_mem[ref_wp] = wdata;
                ref_wp = (ref_wp + 1) % D;
            end
            ref_cnt = ref_cnt + g_wr - g_rd;
        end
        #1;  // let DUT outputs settle, then compare
        if (rst_n) begin
            if (exp_valid && rdata !== exp_data) begin
                errors = errors + 1; $display("[%0t] DATA  exp=%0h got=%0h", $time, exp_data, rdata); end
            if (count !== ref_cnt) begin errors = errors + 1; $display("[%0t] COUNT exp=%0d got=%0d", $time, ref_cnt, count); end
            if (full  !== (ref_cnt == D)) begin errors = errors + 1; $display("[%0t] FULL flag wrong",  $time); end
            if (empty !== (ref_cnt == 0)) begin errors = errors + 1; $display("[%0t] EMPTY flag wrong", $time); end
        end
    end

    // ---------- stimulus helper (drives on negedge) ----------
    task drive(input w, input r, input [W-1:0] d);
        begin @(negedge clk); wr_en = w; rd_en = r; wdata = d; end
    endtask
    integer i;

    initial begin
        repeat (3) @(negedge clk); rst_n = 1;

        $display("T1: fill to full, then overflow attempts");
        for (i = 0; i < D; i = i + 1) drive(1, 0, i + 8'hA0);
        for (i = 0; i < 3; i = i + 1) drive(1, 0, 8'hEE);     // must be ignored
        drive(0, 0, 0);

        $display("T2: simultaneous r/w while full (read wins, write blocked)");
        drive(1, 1, 8'hDD);
        drive(0, 0, 0);

        $display("T3: drain to empty, then underflow attempts");
        for (i = 0; i < D + 3; i = i + 1) drive(0, 1, 0);
        drive(0, 0, 0);

        $display("T4: simultaneous r/w when empty (write only)");
        drive(1, 1, 8'h55);
        drive(0, 0, 0);

        $display("T5: pointer wraparound (many push/pop cycles)");
        for (i = 0; i < 4 * D; i = i + 1) begin drive(1, 0, i); drive(0, 1, 0); end

        $display("T6: simultaneous r/w in steady state");
        for (i = 0; i < 4; i = i + 1) drive(1, 0, 8'h10 + i);
        for (i = 0; i < 20; i = i + 1) drive(1, 1, 8'h20 + i);

        $display("T7: random traffic");
        for (i = 0; i < 2000; i = i + 1) drive($random, $random, $random);

        drive(0, 0, 0); repeat (3) @(negedge clk);
        if (errors == 0) $display("RESULT: PASS - all checks passed");
        else             $display("RESULT: FAIL - %0d errors", errors);
        $finish;
    end
endmodule
