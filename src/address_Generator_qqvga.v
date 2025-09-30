// Edited by Hydronic1219
// Date: 2025-09-28
// Instance naming convention unified to u_<module>

// address_Generator_qqvga.v
// Map VGA 640x480 active video to QQVGA(160x120) address space by /4 scaling.
// Also provides 3x3 neighbor addresses (clamped at borders).

module Address_Generator #(
    parameter integer IMG_W = 160,
    parameter integer IMG_H = 120
)(
    input  wire        CLK25,
    input  wire        reset,
    input  wire        enable,    // activeArea
    input  wire        vsync,     // not used here but kept for compatibility

    output reg [14:0]  address_C,
    output reg [14:0]  address_N,
    output reg [14:0]  address_NE,
    output reg [14:0]  address_E,
    output reg [14:0]  address_SE,
    output reg [14:0]  address_S,
    output reg [14:0]  address_SW,
    output reg [14:0]  address_W,
    output reg [14:0]  address_NW,

    input  wire [10:0] Hcount_in, // VGA counters (0..639, 0..479 in active)
    input  wire [10:0] Vcount_in
);

    // Scale down 640x480 -> 160x120 by >>2
    wire [9:0] hx = Hcount_in[10:2]; // 0..159
    wire [8:0] vy = Vcount_in[9:2];  // 0..119

    // Clamp helpers
    wire [9:0] xL = (hx == 0)              ? 0       : hx - 1;
    wire [9:0] xR = (hx == IMG_W-1)        ? IMG_W-1 : hx + 1;
    wire [8:0] yU = (vy == 0)              ? 0       : vy - 1;
    wire [8:0] yD = (vy == IMG_H-1)        ? IMG_H-1 : vy + 1;

    wire [14:0] C  = vy*IMG_W + hx;
    wire [14:0] N  = yU*IMG_W + hx;
    wire [14:0] S  = yD*IMG_W + hx;
    wire [14:0] W  = vy*IMG_W + xL;
    wire [14:0] E  = vy*IMG_W + xR;
    wire [14:0] NW = yU*IMG_W + xL;
    wire [14:0] NE = yU*IMG_W + xR;
    wire [14:0] SW = yD*IMG_W + xL;
    wire [14:0] SE = yD*IMG_W + xR;

    always @(posedge CLK25) begin
        if (reset) begin
            address_C  <= 0;
            address_N  <= 0;
            address_NE <= 0;
            address_E  <= 0;
            address_SE <= 0;
            address_S  <= 0;
            address_SW <= 0;
            address_W  <= 0;
            address_NW <= 0;
        end else if (enable) begin
            address_C  <= C;
            address_N  <= N;
            address_NE <= NE;
            address_E  <= E;
            address_SE <= SE;
            address_S  <= S;
            address_SW <= SW;
            address_W  <= W;
            address_NW <= NW;
        end
    end
endmodule
