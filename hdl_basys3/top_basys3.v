module top_basys3(
    input  wire       clk,         // 100 MHz
    input  wire       btnU,
    input  wire       btnD,
    input  wire       btnL,
    input  wire       btnR,
    input  wire       btnC,
    input  wire [0:0] sw,
    output reg  [3:0] vgaRed   = 4'd0,
    output reg  [3:0] vgaGreen = 4'd0,
    output reg  [3:0] vgaBlue  = 4'd0,
    output reg        Hsync    = 1'b1,
    output reg        Vsync    = 1'b1
);

wire pixel_clk;    // 25.175 MHz - 640x480 pixel clock
wire clk_locked;

clk_wiz_vga u_clk_wiz (
    .clk_in1  (clk),
    .clk_out1 (pixel_clk),
    .reset    (1'b0),
    .locked   (clk_locked)
);

reg [3:0] por = 4'd0;
always @(posedge pixel_clk)
    if (!clk_locked)   por <= 4'd0;
    else if (!(&por))  por <= por + 4'd1;
wire rst = ~(&por);

wire [4:0] btn_p;      // {start, right, left, down, up}, debounced, active-high
pad_input #(.WIDTH(5)) u_btns (
    .clk     (pixel_clk),
    .key     (~{btnC, btnR, btnL, btnD, btnU}),
    .pressed (btn_p)
);

reg [4:0] btn_prev = 5'd0;
always @(posedge pixel_clk) btn_prev <= btn_p;
wire [4:0] btn_down = btn_p & ~btn_prev;

reg sw_s0 = 1'b0, sw_s1 = 1'b0;
always @(posedge pixel_clk) begin
    sw_s0 <= sw[0];
    sw_s1 <= sw_s0;
end

wire [7:0] vid_r, vid_g, vid_b;
wire       vid_hs, vid_vs, vid_de;
wire       t_hs, t_vs, t_blank;
wire [9:0] t_x, t_y;
wire [2:0] game_state;

vga_timing u_timing (
    .clk   (pixel_clk),
    .HS    (t_hs),
    .VS    (t_vs),
    .x     (t_x),
    .y     (t_y),
    .blank (t_blank)
);

puzzle_core u_core (
    .clk         (pixel_clk),
    .rst         (rst),
    .x           (t_x),
    .y           (t_y),
    .hs_in       (t_hs),
    .vs_in       (t_vs),
    .blank_in    (t_blank),
    .press_up    (btn_down[0]),
    .press_down  (btn_down[1]),
    .press_left  (btn_down[2] & ~btn_p[3]),
    .press_right (btn_down[3] & ~btn_p[2]),
    .press_start (btn_down[4]),
    .peek        (sw_s1 | (btn_p[2] & btn_p[3])),
    .r           (vid_r),
    .g           (vid_g),
    .b           (vid_b),
    .hs          (vid_hs),
    .vs          (vid_vs),
    .de          (vid_de),
    .game_state  (game_state)
);

wire [3:0] bayer  = {t_x[0] ^ t_y[0], t_y[0], t_x[1] ^ t_y[1], t_y[1]};
wire [7:0] thresh = {bayer, 4'b1000};

function [3:0] dither4;
    input [7:0] c;
    input [7:0] t;
    reg  [11:0] v;
    begin
        v = {4'd0, c} * 12'd15 + {4'd0, t};   // at most 3825 + 248 = 4073
        dither4 = v[11:8];
    end
endfunction

always @(posedge pixel_clk) begin
    Hsync    <= vid_hs;
    Vsync    <= vid_vs;
    vgaRed   <= vid_de ? dither4(vid_r, thresh) : 4'd0;
    vgaGreen <= vid_de ? dither4(vid_g, thresh) : 4'd0;
    vgaBlue  <= vid_de ? dither4(vid_b, thresh) : 4'd0;
end

endmodule
