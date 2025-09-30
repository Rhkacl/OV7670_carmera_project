// LCD top
module ili9341_top #(
    parameter X0 = 16'd40,
    parameter X1 = 16'd199,  // 160x120  
    parameter Y0 = 16'd100,
    parameter Y1 = 16'd219   
    )(
    input clk, reset_p, 
    output wire lcd_sck,
    output wire lcd_mosi, 
    output wire lcd_cs,
    output wire lcd_dc,
    output reg lcd_reset,
    output [15:0] led
    );

    // 총 픽셀 수 (160x120 = 19,200)
    localparam integer PIXELS = (X1 - X0 + 1) * (Y1 - Y0 + 1);
 
    reg start;
    reg [7:0] data_in;
    reg dc_in;
    reg burst_mode;
    wire busy;

    ili9341_cntr u_cntr(
        .clk(clk), 
        .reset_p(reset_p),
        .start(start),
        .data_in(data_in),          // 보낼 데이터 
        .dc_in(dc_in),              // 0 = command, 1 = data
        .burst_mode(burst_mode),
        .busy(busy),                // 전송 중 flag
        .sck(lcd_sck),              // SPI clock
        .mosi(lcd_mosi),        
        .cs(lcd_cs),
        .dc(lcd_dc)
        );

    // 이미지 메모리 (160x120 = 19,200픽셀) 
     (* rom_style = "block" *)
     reg [15:0] image_mem [0:PIXELS-1];

    initial begin
        // .mem 파일 읽기 
        $readmemh("Hdog.mem", image_mem);
    end

    // 동기식 read : 주소 넣고 1클럭 뒤에 데이터 유효
    reg [14:0] rd_addr;     // 19,200 필요(image2.mem) 
    reg [15:0] rd_data;
    always @(posedge clk) begin
        if(rd_addr < PIXELS) rd_data <= image_mem[rd_addr];
        else rd_data <= 16'hF800;   // 범위 밖은 red
    end

    // FSM 상태정의
    localparam IDLE         = 4'd0;
    localparam INIT_RESET   = 4'd1;
    localparam INIT_SEQ     = 4'd2;
    localparam SET_WINDOW   = 4'd3;
    localparam MEMWR_CMD    = 4'd4;
    localparam MEMWR_DELAY  = 4'd5;
    localparam RD_WAIT      = 4'd6;
    localparam FILL_PIXEL_H = 4'd7;
    localparam FILL_PIXEL_L = 4'd8;
    localparam PIXEL_DONE   = 4'd9;
    localparam ALL_DONE     = 4'd10;

    reg [3:0] state;
    reg [25:0] delay_cnt; 
    reg [14:0] pixel_cnt;   // 19,200 픽셀 카운터 
    reg [5:0] init_step;    // 초기화 단계 

    // LED 상태 표시 
    assign led[3:0] = state;
    assign led[7:4] = init_step[3:0];
    assign led[15:8] = pixel_cnt[14:7];  // 상위 8bit 표시

    always @(posedge clk or posedge reset_p) begin
        if(reset_p) begin
            state <= IDLE;
            start <= 0;
            data_in <= 0;
            dc_in <= 0;
            burst_mode <= 0;
            lcd_reset <= 1;
            delay_cnt <= 0;
            pixel_cnt <= 0;
            rd_addr <= 0;
            init_step <= 0;
        end
        else begin
            start <= 0;

            case (state)
               IDLE         : begin
                    delay_cnt <= delay_cnt + 1;
                    if(delay_cnt >= 24'd1_000_000) begin    // 10ms 대기 
                        state <= INIT_RESET;
                        delay_cnt <= 0;
                    end
               end
               INIT_RESET   : begin
                    // 하드웨어 리셋 (10ms low + 10ms high)
                    if(delay_cnt < 24'd1_000_000) begin     // 10ms LOW
                        lcd_reset <= 0;
                        delay_cnt <= delay_cnt + 1;
                    end
                    else if(delay_cnt < 24'd12_000_000) begin  // 120ms HIGH
                        lcd_reset <= 1;
                        delay_cnt <= delay_cnt + 1;
                    end
                    else begin
                        delay_cnt <= 0;
                        init_step <= 0;
                        state <= INIT_SEQ;
                        burst_mode <= 1;    // 초기화 시퀀스 시작 시 burst_mode 활성화 
                    end
               end
               INIT_SEQ     : begin
                    if(delay_cnt != 0) begin
                        delay_cnt <= delay_cnt - 1;
                    end
                    else if(!busy && !start) begin
                        if(init_step >= 24) begin
                            state <= SET_WINDOW;
                            init_step <= 0;
                            delay_cnt <= 0;
                            burst_mode <= 0;    // 초기화 완료 후 burst_mode 비활성화
                        end
                        else begin 
                            start <= 1;
                            case (init_step)
                                // softreset
                                0 : begin data_in <= 8'h01; dc_in <= 0; delay_cnt <= 24'd5_000_000; burst_mode <= 1; end            
                                // Display off
                                1 : begin data_in <= 8'h28; dc_in <= 0; burst_mode <= 1; end                                   
                                // Power Control 1
                                2 : begin data_in <= 8'hC0; dc_in <= 0; burst_mode <= 1; end
                                3 : begin data_in <= 8'h23; dc_in <= 1; end // VRH[5:0] = 4.6V
                                // Power Control 2
                                4 : begin data_in <= 8'hC1; dc_in <= 0; burst_mode <= 1; end
                                5 : begin data_in <= 8'h10; dc_in <= 1; end // SAP[2:0], BT[3:0]
                                // VCOM Control 1
                                6 : begin data_in <= 8'hC5; dc_in <= 0; burst_mode <= 1; end
                                7 : begin data_in <= 8'h2B; dc_in <= 1; end // VMH=3.775V
                                8 : begin data_in <= 8'h2B; dc_in <= 1; end // VML=-1.425V
                                // VCOM Control 2
                                9 : begin data_in <= 8'hC7; dc_in <= 0; burst_mode <= 1; end
                                10 : begin data_in <= 8'hC0; dc_in <= 1; end
                                // Memory Access Control
                                11 : begin data_in <= 8'h36; dc_in <= 0; burst_mode <= 0; end                              
                                // MADCTL
                                12 : begin data_in <= 8'h48; dc_in <= 0; burst_mode <= 1; end   // MY=0,MX=1,MV=0,BGR=1,MH=0
                                // Pixel Format
                                13 : begin data_in <= 8'h3A; dc_in <= 0; burst_mode <= 1; end
                                14 : begin data_in <= 8'h55; dc_in <= 1; end    // 16bit
                                // Frame Rate Control (Normal Mode)
                                15 : begin data_in <= 8'hB1; dc_in <= 0; burst_mode <= 1; end
                                16 : begin data_in <= 8'h00; dc_in <= 1; end    // fosc
                                17 : begin data_in <= 8'h18; dc_in <= 1; end    // 79hz
                                // Entry Mode
                                18 : begin data_in <= 8'hB7; dc_in <= 0; burst_mode <= 1; end
                                19 : begin data_in <= 8'h07; dc_in <= 1; end
                                // Sleep out
                                20 : begin data_in <= 8'h11; dc_in <= 0; delay_cnt <= 24'd15_000_000; burst_mode <= 1; end
                                // Display on
                                21 : begin data_in <= 8'h29; dc_in <= 0; delay_cnt <= 24'd50_000_000; burst_mode <= 1; end
                                22 : begin data_in <= 8'h2A; dc_in <= 0; burst_mode <= 1; end                             
                                23 : begin data_in <= 8'h2B; dc_in <= 0; burst_mode <= 1; end

                                default: begin
                                    state <= SET_WINDOW;
                                    init_step <= 0;
                                    delay_cnt <= 0;
                                    burst_mode <= 0;
                                end
                            endcase
                        init_step <= init_step + 1;
                        end
                    end
                end
               SET_WINDOW   : begin
                    if(!busy && !start) begin
                        burst_mode <= 1;        // 설정 전체를 하나의 CS LOW로
                        case (init_step)
                            // Column Address Set (0x2A)
                            0: begin data_in <= 8'h2A; dc_in <= 0; end
                            1: begin data_in <= X0[15:8]; dc_in <= 1; end  // X start high
                            2: begin data_in <= X0[7:0]; dc_in <= 1; end   // X start low
                            3: begin data_in <= X1[15:8]; dc_in <= 1; end  // X end high
                            4: begin data_in <= X1[7:0]; dc_in <= 1; end   // X end low
                            // Page Address Set (0x2B)
                            5: begin data_in <= 8'h2B; dc_in <= 0; end
                            6: begin data_in <= Y0[15:8]; dc_in <= 1; end  // Y start high
                            7: begin data_in <= Y0[7:0]; dc_in <= 1; end   // Y start low
                            8: begin data_in <= Y1[15:8]; dc_in <= 1; end  // Y end high
                            9: begin data_in <= Y1[7:0]; dc_in <= 1; end   // Y end low
                            default: begin
                                state <= MEMWR_CMD;
                                init_step <= 0;
                                burst_mode <= 0;    // 설정 완료 
                            end 
                        endcase

                        if(init_step < 10) begin
                            start <= 1;
                            init_step <= init_step + 1;
                        end
                    end 
               end
               MEMWR_CMD    : begin
                    if(!busy && !start) begin
                        data_in <= 8'h2C;       // memory write
                        dc_in <= 0;
                        start <= 1;
                        burst_mode <= 1;        // 픽셀 데이터 전송을 위해 유지
                        pixel_cnt <= 0;
                        rd_addr <= 0;
                        delay_cnt <= 24'd1_000; // 10us 지연 
                        state <= MEMWR_DELAY;
                    end
               end
               MEMWR_DELAY  : begin
                    if(delay_cnt != 0) begin
                        delay_cnt <= delay_cnt - 1;
                    end
                    else begin
                        state <= RD_WAIT;
                    end
               end
               RD_WAIT      : begin
                    // BRAM 읽기 1클럭 대기 
                    state <= FILL_PIXEL_H;
               end
               FILL_PIXEL_H : begin
                    if(!busy && !start) begin
                        data_in <= rd_data[15:8];   // 이미지 데이터 상위
                        dc_in <= 1;
                        start <= 1;
                    end
                    else if(!busy && start) begin
                        start <= 0;
                        state <= FILL_PIXEL_L;
                    end
               end
               FILL_PIXEL_L : begin
                    if(!busy && !start) begin
                        data_in <= rd_data[7:0];    // 이미지 데이터 하위
                        dc_in <= 1;
                        start <= 1;
                    end
                    else if(!busy && start) begin
                        start <= 0;
                        state <= PIXEL_DONE;
                    end
               end
               PIXEL_DONE   : begin
                    if(!busy) begin
                        if(pixel_cnt < PIXELS - 1) begin    // 정확히 PIXELS개 전송
                            pixel_cnt <= pixel_cnt + 1;    
                            rd_addr <= rd_addr + 1;
                            state <= RD_WAIT;
                        end
                        else begin
                            burst_mode <= 0;
                            state <= ALL_DONE;
                            pixel_cnt <= PIXELS;
                        end
                    end
               end
               ALL_DONE     : begin
                    burst_mode <= 0;
                    // 완료 시 LED로 표시
               end
                default: state <= IDLE;
            endcase
        end 
    end
    
endmodule
---------------------------------------------------------------------------------------
// ILI9341 LCD cntr
module ili9341_cntr (
    input clk, reset_p,
    input start,
    input [7:0] data_in,    // 보낼 데이터 
    input dc_in,            // 0 = command, 1 = data
    input burst_mode,       // 1 = CS LOW 유지(연속 바이트 전송)
    output reg busy,        // 전송 중 flag
    output reg sck,         // SPI clock
    output reg mosi,        
    output reg cs,
    output reg dc
    );

    // FSM 상태정의 
    localparam IDLE     = 6'd000001;
    localparam CS_LOW   = 6'd000010;
    localparam LOAD     = 6'd000100;
    localparam SETUP    = 6'd001000;
    localparam SHIFT    = 6'd010000;
    localparam CS_HIGH  = 6'd100000;

    reg [5:0] state;
    reg [3:0] bit_cnt;
    reg [7:0] shifter;
    reg [15:0] cs_delay;

    // SPI 클럭 분주기 (200KHz) 
    reg [8:0] clk_div; 
    wire spi_tick = (clk_div == 9'd499);  // 100MHz / 500 = 200KHz
    reg [1:0] phase;

    always @(posedge clk or posedge reset_p) begin
        if(reset_p) clk_div <= 0;
        else if(clk_div >= 499) clk_div <= 0;    // 100분주 (1MHz)
        else clk_div <= clk_div + 1;
    end

    always @(posedge clk or posedge reset_p) begin
        if(reset_p) begin
            state <= IDLE;
            busy <= 0;
            sck <= 0;
            mosi <= 0;
            cs <= 1;
            dc <= 0;
            bit_cnt <= 0;
            shifter <= 0;
            phase <= 0;
            cs_delay <= 0;
        end
        else begin
            case (state)
               IDLE  : begin
                    busy <= 0;
                    sck <= 0;
                    cs <= (burst_mode ? 1'b0 : 1'b1);   // burst_mode시 CS유지
                    cs_delay <= 0;
                    if(start) begin
                        shifter <= data_in;
                        dc <= dc_in;
                        state <= CS_LOW;
                        busy <= 1;
                    end 
               end
               CS_LOW : begin
                    cs <= 0;
                    cs_delay <= cs_delay + 1;
                    if(cs_delay >= 500) begin    // 약 5us setup
                        cs_delay <= 0;
                        state <= LOAD;
                    end
               end
               LOAD  : begin
                    bit_cnt <= 7;
                    sck <= 0;
                    phase <= 0;
                    state <= SETUP;
               end
               SETUP : begin
                mosi <= shifter[7]; // MOSI 먼저 setting
                if(spi_tick) begin
                    state <= SHIFT;
                end
               end
               SHIFT : if(spi_tick) begin
                    case (phase)
                        2'd0 : begin
                            sck <= 0;   // LOW 유지 
                            phase <= 1;
                        end
                        2'd1 : begin
                            sck <= 1;   // clock 상승 엣지
                            phase <= 2;
                        end
                        2'd2 : begin
                            sck <= 0;   // 하강엣지 MOSI 변경
                            if(bit_cnt == 0) begin
                                cs_delay <= 0;
                                state <= CS_HIGH;
                            end
                            else begin
                                shifter <= {shifter[6:0], 1'b0};
                                bit_cnt <= bit_cnt - 1;
                                phase <= 0;
                                state <= SETUP; // MOSI 안정화 
                            end   
                        end
                        default: phase <= 0;
                    endcase
               end
               CS_HIGH  : begin
                    if(burst_mode) begin
                        busy <= 0;
                        state <= IDLE;
                    end
                    else begin
                        cs_delay <= cs_delay + 1;
                        if(cs_delay >= 500) begin    // 5us 유지 
                            cs <= 1;
                            busy <= 0;
                            state <= IDLE;
                        end
                    end
               end
                default: state <= IDLE; 
            endcase
        end
    end
    
endmodule
