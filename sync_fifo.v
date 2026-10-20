// Parameterized synchronous FIFO
// - Separate read/write pointers with explicit wraparound (any DEPTH works)
// - Occupancy counter drives full/empty flags
// - Overflow (write when full) and underflow (read when empty) are ignored safely
// - Simultaneous read+write is supported (count unchanged)
module sync_fifo #(
    parameter DATA_W = 8,
    parameter DEPTH  = 16
)(
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire                       wr_en,
    input  wire                       rd_en,
    input  wire [DATA_W-1:0]          wdata,
    output reg  [DATA_W-1:0]          rdata,   // valid 1 cycle after an accepted read
    output wire                       full,
    output wire                       empty,
    output reg  [$clog2(DEPTH+1)-1:0] count
);
    localparam AW = $clog2(DEPTH);

    reg [DATA_W-1:0] mem [0:DEPTH-1];
    reg [AW-1:0]     wptr, rptr;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    wire do_wr = wr_en && !full;    // gated: blocks overflow
    wire do_rd = rd_en && !empty;   // gated: blocks underflow

    always @(posedge clk) begin
        if (!rst_n) begin
            wptr <= 0; rptr <= 0; count <= 0; rdata <= 0;
        end else begin
            if (do_wr) begin
                mem[wptr] <= wdata;
                wptr <= (wptr == DEPTH-1) ? 0 : wptr + 1'b1;   // wraparound
            end
            if (do_rd) begin
                rdata <= mem[rptr];
                rptr  <= (rptr == DEPTH-1) ? 0 : rptr + 1'b1;  // wraparound
            end
            case ({do_wr, do_rd})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: count <= count;   // idle or simultaneous r/w
            endcase
        end
    end
endmodule
