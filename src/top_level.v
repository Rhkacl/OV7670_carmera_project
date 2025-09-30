// Edited by Hydronic1219
// Date: 2025-09-28
// Instance naming convention unified to u_<module>


module top_level(
    input  [3:0]sw,
	input  clk100,
	input  btnc,
	output vga_hsync,
	output vga_vsync,
	output [3:0]vga_r,
	output [3:0]vga_g,
	output [3:0]vga_b,
	input  ov7670_pclk,
	output ov7670_xclk,
	input ov7670_vsync,
	input ov7670_href,
	input [7:0] ov7670_data,
	output ov7670_sioc,
	inout  ov7670_siod,
	output ov7670_pwdn,
	output ov7670_reset,
	output config_finished
);

wire clk_camera, clk_vga,resend,nBlank,vSync,nSync,activeArea,locked,reset_locked;

wire [7:0] red,blue,green;

wire [1:0] size_select;
wire we_full;

wire [11:0] wrdata_full; // 12b 픽셀
wire [18:0] wraddress_full; // (무시해도 됨)


clocking u_clocking(
	.reset(btnc),
	.CLK_100(clk100),
	.CLK_50(clk_camera),
	.CLK_25(clk_vga),
	.locked(locked)
);

resetlocked u_resetlocked(
    .pclk(clk_vga),
	.reset(reset_locked),
	.locked(locked)
);

assign vga_vsync = vSync;

wire [10:0] hcount_f, vcount_f;
wire [10:0] hcount_vga_filtering, vcount_vga_filtering;

VGA u_vga(
	.CLK25(clk_vga),
	.reset(reset_locked),
	.Hsync(vga_hsync),
	.Vsync(vSync),
	.Nblank(nBlank),
	.Nsync(nSync),
	.activeArea(activeArea),
	.Hcnt_out(hcount_vga_filtering),
	.Vcnt_out(vcount_vga_filtering)
);



ov7670_controller u_ov7670_controller(
	.clk(clk_camera),
	.resend(resend),
	.config_finished(config_finished),
	.sioc(ov7670_sioc),
	.siod(ov7670_siod),
	.reset(ov7670_reset),
	.pwdn(ov7670_pwdn),
	.xclk(ov7670_xclk)
);



wire [18:0] address_C, address_N, address_NE, address_E,address_SE,address_S, address_SW, address_W, address_NW;
wire [11:0] rddata_C, rddata_N, rddata_NE, rddata_E, rddata_SE, rddata_S, rddata_SW, rddata_W, rddata_NW;




ov7670_capture u_ov7670_capture(
	.pclk(ov7670_pclk),
	.vsync(ov7670_vsync),
	.href(ov7670_href),
	.d(ov7670_data),
	.addr(wraddress_full),
	.dout(wrdata_full),
	.we(we_full)
);
wire [7:0] R,G,B;

wire [23:0] RGB_C, RGB_N, RGB_NE, RGB_E, RGB_SE, RGB_S, RGB_SW, RGB_W, RGB_NW;
wire [7:0] gray_wire;
wire [11:0] rddata_C_small;
wire [14:0] wraddr_small;
wire        we_small;
wire [11:0] wrdata_small;
wire [14:0] address_center_small, address_left_up_small, address_left_small,
            address_left_down_small, address_up_small, address_right_up_small,
            address_right_small, address_right_down_small, address_down_small;



frame_buffer_small #(
  .DATA_WIDTH(12), .IMG_W(160), .IMG_H(120), .ADDR_WIDTH(15)
) u_fb_small (
  // Read (VGA)
  .clkb (clk_vga),
  .addrb(address_center_small),  // 아래 3)에서 생성
  .doutb(rddata_C_small),
  // Write (Camera)
  .clka (ov7670_pclk),
  .addra(wraddr_small),
  .dina (wrdata_small),
  .wea  (we_small)
);

RGB u_rgb(
	.Din(rddata_C_small),
	.reset(reset_locked),
	.Nblank(activeArea),
	.R(RGB_C[7:0]),
	.G(RGB_C[15:8]),
	.B(RGB_C[23:16]),
	.Grayscale(gray_wire)
	
);

wire [7:0] gray_center, gray_right_up, gray_right, gray_right_down, gray_down, gray_left_down, gray_left, gray_left_up, gray_up;
wire [18:0] address_center, address_left_up, address_left, address_left_down, address_up, address_right_up, address_right, address_right_down, address_down;
// 4×4 디시메이션: 640x480 -> 160x120


ov7670_decimate #(
  .SCALE_X(4), .SCALE_Y(4), .IMG_W(160), .ADDR_WIDTH(15)
) u_decim (
  .pclk (ov7670_pclk),
  .rst  (reset_locked),
  .vsync(ov7670_vsync),
  .href (ov7670_href),
  .we_in(we_full),
  .din  (wrdata_full),
  .addra(wraddr_small),
  .we_out(we_small),
  .dout (wrdata_small)
);

ram_buffer u_ram_buffer(
    .clk(clk_vga),
    .we(1'b1),
    .gray_input(gray_wire),
    .input_rgb_address(address_center_small),
    .address_center(address_center_small),
    .address_left_up(address_left_up_small), 
    .address_left(address_left_small),
    .address_left_down(address_left_down_small),
    .address_up(address_up_small),
    .address_down(address_down_small),
    .address_right_up(address_right_up_small),
    .address_right(address_right_small),
    .address_righ_down(address_right_down_small),
    .gray_center(gray_center), 
    .gray_left_up(gray_left_up), 
    .gray_left(gray_left),
    .gray_left_down(gray_left_down),
    .gray_up(gray_up),
    .gray_down(gray_down),
    .gray_right_up(gray_right_up),
    .gray_right(gray_right),
    .gray_right_down(gray_right_down)
);

// 주소폭이 15비트(0..159*120-1)로 줄어듭니다.

// QQVGA 주소 생성기: Hcount_in/Vcount_in을 >>2로 축소해 160x120 주소 산출
Address_Generator #(.IMG_W(160), .IMG_H(120)) my_Address_Generator (
  .CLK25(clk_vga),
  .reset(reset_locked),
  .enable(activeArea),
  .vsync(vSync),
  .address_C (address_center_small),
  .address_N (address_up_small),
  .address_NE(address_right_up_small),
  .address_E (address_right_small),
  .address_SE(address_right_down_small),
  .address_S (address_down_small),
  .address_SW(address_left_down_small),
  .address_W (address_left_small),
  .address_NW(address_left_up_small),
  .Hcount_in(hcount_vga_filtering),
  .Vcount_in(vcount_vga_filtering)
);
wire [3:0] red_char, green_char,blue_char;

filtering u_filtering(
    .clock(clk_vga),
    .reset(reset_locked),
    .sel_module(sw),
    .rgb_C(RGB_C),
    .gray_center(gray_center), 
    .gray_left_up(gray_left_up), 
    .gray_left(gray_left),
    .gray_left_down(gray_left_down),
    .gray_up(gray_up),
    .gray_down(gray_down),
    .gray_right_up(gray_right_up),
    .gray_right(gray_right),
    .gray_right_down(gray_right_down),
    .red(red_char),
    .green(green_char),
    .blue(blue_char),   
    .Nblank(activeArea),
    .hc(hcount_f),
    .vc(vcount_f),
    .Hcount_in(hcount_vga_filtering),
    .Vcount_in(vcount_vga_filtering)
    
);

wire [6:0] char_code, char_code_distance;
wire [3:0] char_line, char_line_distance;
wire [7:0] char_pixel,   char_pixel_distance;
wire [4:0] char_xy, char_distance_xy;
wire [11:0] rgb_rect2distance;
wire [10:0] vcount_rect2distance, hcount_rect2distance;
wire [11:0] rgb_final; // 위에서 rgb_out에 연결
wire vsync_rect2distance, hsync_rect2distance, hblnk_rect2distance, vblnk_rect2distance;

draw_rect_char u_draw_rect_char(
      .vcount_in(vcount_f),
      .hcount_in(hcount_f),
      .char_pixels(8'd0),
      .rgb_in({red_char,green_char,blue_char}),
      .vcount_out(vcount_rect2distance),
      .hcount_out(hcount_rect2distance),
      .rgb_out(rgb_rect2distance),
      .char_xy(),
      .char_line(),
      .pclk(clk_vga),
      .rst(reset_locked)

);

draw_distance_char u_draw_distance_char(
      .vcount_in(vcount_rect2distance),
      .hcount_in(hcount_rect2distance),
      .char_pixels(8'd0),
      .rgb_in(rgb_rect2distance),
    
      .rgb_out(rgb_final),
      .char_xy(),
      .char_line(),
      .pclk(clk_vga),
      .rst(reset_locked)

);


font_rom u_font_rom(        
      .char_line_pixels(char_pixel),  
      .addr({char_code[6:0],char_line[3:0]}),
      .clk(clk_vga)

);

font_rom u_font_rom_1(
    .char_line_pixels(char_pixel_distance),  
    .addr({char_code_distance[6:0],char_line_distance[3:0]}),
    .clk(clk_vga)
);

char_rom u_char_rom(
   
    .char_code(char_code),
    .char_xy(char_xy),
    .sw(sw)

);

char_rom_dist_meter u_char_rom_dist_meter(
   
    .char_code(char_code_distance),
    .char_xy(char_distance_xy),
    .distance(distance_cm)
);

//assign vga_r = red_char;
//assign vga_g = green_char;
//assign vga_b = blue_char;



assign vga_vsync = vSync;
assign vga_r = activeArea ? rgb_final[11:8] : 4'd0;
assign vga_g = activeArea ? rgb_final[7:4]  : 4'd0;
assign vga_b = activeArea ? rgb_final[3:0]  : 4'd0;

endmodule

