// Edited by Hydronic1219
// Date: 2025-09-28
// Instance naming convention unified to u_<module>

// frame_buffer_small.v
// Simple dual-port BRAM for QQVGA (160x120) x 12bpp
// Port A: write (camera pclk), Port B: read (VGA clk)
// Depth = 160*120 = 19200 (< 2^15). Use ADDR_WIDTH=15.

module frame_buffer_small #(
    parameter integer DATA_WIDTH = 12,
    parameter integer IMG_W      = 160,
    parameter integer IMG_H      = 120,
    parameter integer ADDR_WIDTH = 15,               // log2(32768)
    parameter integer DEPTH      = IMG_W*IMG_H       // 19200
)(
    // Read port (B)
    input  wire                   clkb,
    input  wire [ADDR_WIDTH-1:0]  addrb,
    output reg  [DATA_WIDTH-1:0]  doutb,

    // Write port (A)
    input  wire                   clka,
    input  wire [ADDR_WIDTH-1:0]  addra,
    input  wire [DATA_WIDTH-1:0]  dina,
    input  wire                   wea
);
    // Synthesis hint
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] ram [0:DEPTH-1];

    // Port B (sync read)
    always @(posedge clkb) begin
        if (addrb < DEPTH)
            doutb <= ram[addrb];
        else
            doutb <= {DATA_WIDTH{1'b0}};
    end

    // Port A (write)
    always @(posedge clka) begin
        if (wea && (addra < DEPTH)) begin
            ram[addra] <= dina;
        end
    end
endmodule
