// Edited by Hydronic1219
// Date: 2025-09-28
// Instance naming convention unified to u_<module>


// ov7670_decimate_fixed.v
// Downsample accepted pixels/lines by SCALE_X, SCALE_Y (e.g., 4,4 => 640x480 -> 160x120)

`timescale 1ns/1ps

module ov7670_decimate #(
    parameter integer SCALE_X    = 4, // decimate columns by 4
    parameter integer SCALE_Y    = 4, // decimate rows by 4
    parameter integer IMG_W      = 160,
    parameter integer ADDR_WIDTH = 15
)(
    input  wire                  pclk,
    input  wire                  rst,
    input  wire                  vsync,   // from camera
    input  wire                  href,    // from camera
    input  wire                  we_in,   // 1-cycle pulse per captured pixel
    input  wire [11:0]           din,     // 12b pixel (RGB444 packed)

    output reg  [ADDR_WIDTH-1:0] addra,   // compact QQVGA address
    output reg                   we_out,  // write strobe for compact buffer
    output wire [11:0]           dout     // pass-through data
);
    assign dout = din;

    // Edge detectors
    reg vsync_d, href_d;
    always @(posedge pclk) begin
        vsync_d <= vsync;
        href_d  <= href;
    end
    wire vsync_fall = (vsync_d == 1'b1) && (vsync == 1'b0);
    wire href_rise  = (href_d  == 1'b0) && (href  == 1'b1);
    wire href_fall  = (href_d  == 1'b1) && (href  == 1'b0);

    // Row/Column decimation counters
    localparam integer YBITS = (SCALE_Y<=2)?1:((SCALE_Y<=4)?2:3);
    localparam integer XBITS = (SCALE_X<=2)?1:((SCALE_X<=4)?2:3);

    // Width-matched constants (avoid inline slicing)
    localparam [YBITS-1:0] SCALE_Y_M1 = SCALE_Y - 1;
    localparam [XBITS-1:0] SCALE_X_M1 = SCALE_X - 1;

    reg [YBITS-1:0] yskip;
    reg [XBITS-1:0] xskip;

    wire accept_line = (yskip == {YBITS{1'b0}});

    // Line base address in compact buffer
    reg [ADDR_WIDTH-1:0] line_base;
    localparam [ADDR_WIDTH-1:0] IMG_W_ADDR = IMG_W[ADDR_WIDTH-1:0];

    always @(posedge pclk) begin
        if (rst || vsync_fall) begin
            yskip     <= {YBITS{1'b0}};
            xskip     <= {XBITS{1'b0}};
            line_base <= {ADDR_WIDTH{1'b0}};
            addra     <= {ADDR_WIDTH{1'b0}};
            we_out    <= 1'b0;
        end else begin
            we_out <= 1'b0; // default

            // Start of a new line
            if (href_rise) begin
                xskip <= {XBITS{1'b0}};
                addra <= line_base; // next accepted write will start from here
            end

            // For each pixel captured
            if (we_in) begin
                if (accept_line) begin
                    if (xskip == {XBITS{1'b0}}) begin
                        we_out <= 1'b1;   // accept this pixel
                        addra  <= addra + {{(ADDR_WIDTH-1){1'b0}},1'b1};
                    end
                    // increment xskip modulo SCALE_X
                    if (xskip == SCALE_X_M1)
                        xskip <= {XBITS{1'b0}};
                    else
                        xskip <= xskip + {{(XBITS-1){1'b0}},1'b1};
                end
            end

            // End of line
            if (href_fall) begin
                if (accept_line) begin
                    line_base <= line_base + IMG_W_ADDR;
                end
                // increment yskip modulo SCALE_Y
                if (yskip == SCALE_Y_M1)
                    yskip <= {YBITS{1'b0}};
                else
                    yskip <= yskip + {{(YBITS-1){1'b0}},1'b1};
            end
        end
    end
endmodule