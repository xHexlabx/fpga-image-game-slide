`default_nettype none

module gamepad_pmod_rx (
    input  wire        clk,
    input  wire        rst,          // synchronous, active-high
    input  wire        pmod_data,
    input  wire        pmod_clk,
    input  wire        pmod_latch,
    output wire [11:0] btn,          // active-high, see order above
    output wire        present
);

    reg [1:0]  data_s, clk_s, latch_s;
    reg        clk_prev, latch_prev;
    reg [11:0] shift;
    reg [11:0] packet;

    always @(posedge clk) begin
        data_s  <= {data_s[0],  pmod_data};
        clk_s   <= {clk_s[0],   pmod_clk};
        latch_s <= {latch_s[0], pmod_latch};
        clk_prev   <= clk_s[1];
        latch_prev <= latch_s[1];

        if (rst) begin
            shift  <= 12'hfff;
            packet <= 12'hfff;
        end else begin
            if (clk_s[1] && !clk_prev)
                shift <= {shift[10:0], data_s[1]};
            if (latch_s[1] && !latch_prev)
                packet <= shift;
        end
    end

    assign present = (packet != 12'hfff);
    assign btn     = present ? packet : 12'h000;

endmodule

`default_nettype wire
