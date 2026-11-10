module clk_wiz_vga (
    input  wire clk_in1,
    output wire clk_out1,
    input  wire reset,
    output wire locked
);
    assign clk_out1 = clk_in1;
    assign locked   = 1'b1;
endmodule

module tb_basys3;

    localparam S_TITLE = 0, S_SHUFFLE = 1, S_PLAY = 2;
    localparam HOLD = 160000;      // > 125000-cycle debounce
    localparam BLIP = 50000;

    reg clk = 1'b0;
    always #20 clk = ~clk;

    reg btnU = 0, btnD = 0, btnL = 0, btnR = 0, btnC = 0;
    reg [0:0] sw = 1'b0;
    wire [3:0] vgaRed, vgaGreen, vgaBlue;
    wire Hsync, Vsync;

    top_basys3 dut (
        .clk(clk), .btnU(btnU), .btnD(btnD), .btnL(btnL), .btnR(btnR),
        .btnC(btnC), .sw(sw), .vgaRed(vgaRed), .vgaGreen(vgaGreen),
        .vgaBlue(vgaBlue), .Hsync(Hsync), .Vsync(Vsync)
    );

    wire [2:0] state = dut.u_core.state;
    integer errors = 0;

    integer n_up = 0, n_down = 0, n_left = 0, n_right = 0, n_start = 0;
    reg     saw_shuffle = 0;
    always @(posedge clk) begin
        if (dut.u_core.press_up)    n_up    = n_up + 1;
        if (dut.u_core.press_down)  n_down  = n_down + 1;
        if (dut.u_core.press_left)  n_left  = n_left + 1;
        if (dut.u_core.press_right) n_right = n_right + 1;
        if (dut.u_core.press_start) n_start = n_start + 1;
        if (state == S_SHUFFLE)     saw_shuffle = 1;
    end

    integer hs_len = 0, hs_last = 0, vs_lines = 0, vs_last = 0;
    integer bad_blank = 0, bad_col = 0, n_col = 0, n_lit = 0;
    reg [3:0] er, eg, eb;
    reg       de_d = 0;
    reg [7:0] r_d, g_d, b_d, t_d;
    function [3:0] d4(input [7:0] c, input [7:0] t);
        d4 = ({4'd0, c} * 12'd15 + {4'd0, t}) >> 8;
    endfunction
    always @(posedge clk) begin
        de_d <= dut.vid_de;
        r_d <= dut.vid_r; g_d <= dut.vid_g; b_d <= dut.vid_b; t_d <= dut.thresh;
        if (!dut.rst) begin
            if (!Hsync) hs_len = hs_len + 1;
            else if (hs_len) begin hs_last = hs_len; hs_len = 0; end
            if (!de_d && (vgaRed | vgaGreen | vgaBlue)) bad_blank = bad_blank + 1;
            if (de_d) begin
                n_col = n_col + 1;
                if (vgaRed | vgaGreen | vgaBlue) n_lit = n_lit + 1;
                if (vgaRed != d4(r_d, t_d) || vgaGreen != d4(g_d, t_d) ||
                    vgaBlue != d4(b_d, t_d)) bad_col = bad_col + 1;
            end
        end
    end
    always @(negedge Hsync) if (!Vsync) vs_lines = vs_lines + 1;
    always @(posedge Vsync) if (vs_lines) begin vs_last = vs_lines; vs_lines = 0; end

    task cycles(input integer n); repeat (n) @(posedge clk); endtask
    task frames(input integer n);
        integer f;
        for (f = 0; f < n; f = f + 1) @(posedge dut.u_core.tick);
    endtask
    task clear;
        begin n_up = 0; n_down = 0; n_left = 0; n_right = 0; n_start = 0; saw_shuffle = 0; end
    endtask
    task check(input [8*40:1] what, input integer got, input integer want);
        if (got != want) begin
            $display("FAIL %0s: %0d, expected %0d", what, got, want); errors = errors + 1;
        end else $display("ok   %0s: %0d", what, got);
    endtask
    task wait_play(input integer max_frames);
        integer f;
        begin
            f = 0;
            while (state != S_PLAY && f < max_frames) begin frames(1); f = f + 1; end
            if (state != S_PLAY) begin
                $display("FAIL: never reached PLAY (state %0d)", state); errors = errors + 1;
            end
        end
    endtask

    initial begin
        cycles(5);
        if (dut.rst !== 1'b1) begin $display("FAIL: not in reset at start"); errors = errors + 1; end
        cycles(30);
        if (dut.rst !== 1'b0) begin $display("FAIL: reset never released"); errors = errors + 1; end
        frames(2);
        check("state after reset is TITLE", state, S_TITLE);
        check("no phantom press at power-on", n_up + n_down + n_left + n_right + n_start, 0);
        check("hsync pulse, clocks", hs_last, 96);
        check("vsync pulse, lines", vs_last, 2);
        check("colour outside the picture", bad_blank, 0);
        check("4-bit colour == dithered core colour", bad_col, 0);
        if (n_lit == 0) begin $display("FAIL: picture is all black"); errors = errors + 1; end
        else $display("ok   title picture is lit (%0d of %0d pixels)", n_lit, n_col);

        clear;
        btnU = 1; cycles(BLIP); btnU = 0; cycles(HOLD);
        check("presses from a 2 ms blip", n_up + n_start, 0);

        clear;
        btnC = 1; cycles(HOLD); btnC = 0; cycles(HOLD);
        check("btnC on title: start presses", n_start, 1);
        wait_play(4);
        check("btnC on title: shuffled", saw_shuffle, 1);

        frames(12); wait_play(12); clear;
        btnD = 1; cycles(HOLD); btnD = 0; cycles(HOLD);
        check("btnD: down presses", n_down, 1);
        check("btnD: no other presses", n_up + n_left + n_right + n_start, 0);

        frames(12); wait_play(12); clear;
        sw[0] = 1; cycles(100);
        check("sw0 up: peek on", dut.u_core.peek, 1);
        sw[0] = 0; cycles(100);
        check("sw0 down: peek off", dut.u_core.peek, 0);

        clear;
        btnL = 1; cycles(HOLD);
        btnR = 1; cycles(HOLD);
        check("L+R held: peek on", dut.u_core.peek, 1);
        btnL = 0; btnR = 0; cycles(HOLD);
        check("L+R: left presses", n_left, 1);
        check("L+R: right presses", n_right, 0);
        check("L+R released: peek off", dut.u_core.peek, 0);

        frames(12); wait_play(12); clear;
        btnC = 1; cycles(HOLD); btnC = 0; cycles(HOLD);
        check("btnC in play: start presses", n_start, 1);
        frames(2); wait_play(4);
        check("btnC in play: reshuffled", saw_shuffle, 1);

        check("colour outside the picture (whole run)", bad_blank, 0);
        check("4-bit colour == dithered (whole run)", bad_col, 0);

        if (errors == 0) $display("PASS");
        else             $display("FAILED with %0d errors", errors);
        $finish;
    end

endmodule
