`timescale 1ns / 1ps
`define DEBUG
// NexEBAZ4205_OV5640_HDMI
// EBAZ4205 + hellofpga IO board + OV5640 DVP → HDMI output
// CLK: 50MHz (N18), Display: 640x480 @25MHz → rgb2dvi → HDMI
// OV5640: 1280x720 RGB565 → 3:1 subsample → 320x240 BRAM → 2x upscale

module top_ov5640_hdmi (
    input           CLK,           // 50MHz PL clock (N18)

    // OV5640 DVP interface
    input           ov5640_pclk,   // pixel clock from camera
    input           ov5640_vsync,
    input           ov5640_href,
    input  [7:0]    ov5640_data,
    inout           ov5640_sioc,   // I2C SCL
    inout           ov5640_siod,   // I2C SDA
    output          ov5640_pwdn,   // power down (active high → 0 = normal)
    output          ov5640_reset,  // reset (active low → 1 = normal)

    // HDMI output (rgb2dvi, TMDS)
    output          HDMI_CLK_N, HDMI_CLK_P,
    output [2:0]    HDMI_N, HDMI_P,

    // UART debug (optional)
    output          UART_TX
);

    wire clk_25;
    (* MARK_DEBUG = "true" *) wire config_done;
    assign UART_TX   = 1'b1;   // idle
    assign ov5640_xclk = clk_25;  // 25MHz master clock to OV5640

    // Clock: 50MHz → 25MHz
    clocking u_clocking (
        .CLK_50 (CLK),
        .CLK_25 (clk_25)
    );

    // BUFG: J20(non-SRCC) pclk를 global clock network으로 승격
    wire pclk_buf;
    BUFG u_pclk_buf (.I(ov5640_pclk), .O(pclk_buf));

 `ifdef DEBUG
    (* MARK_DEBUG = "true" *) reg clk12_5_dbg = 0;
    always @(posedge clk_25) clk12_5_dbg <= ~clk12_5_dbg;

    // pclk 주파수 측정: clk25 ILA에서 두 시점의 값 차이로 역산
    // 예) 1초 간격 두 캡처에서 차이가 N이면 pclk = N Hz
    // 예) 25M clk25 사이클 동안 카운터 변화량 M이면 pclk = M × 25M/25M = M Hz
    (* KEEP = "true" *) reg [25:0] pclk_cnt = 26'd0;
    always @(posedge pclk_buf) pclk_cnt <= pclk_cnt + 1;
    (* KEEP = "true" *) wire [25:0] dbg_pclk_cnt = pclk_cnt;
 `endif
    // Camera active detection (vsync timeout ~2.68s @ 25MHz)
    reg vsync_s1 = 0, vsync_s2 = 0, vsync_s3 = 0;
    always @(posedge clk_25) begin
        vsync_s1 <= ov5640_vsync;
        vsync_s2 <= vsync_s1;
        vsync_s3 <= vsync_s2;
    end
    wire vsync_posedge = vsync_s2 & ~vsync_s3;

    reg [25:0] cam_timeout = 26'd0;
    always @(posedge clk_25) begin
        if (vsync_posedge)
            cam_timeout <= 26'd0;
        else if (!cam_timeout[25])
            cam_timeout <= cam_timeout + 1;
    end
    (* MARK_DEBUG = "true" *) wire camera_active = ~cam_timeout[25];

    // OV5640 power-up sequence (25MHz)
    // PWDN: active HIGH  (1=powerdown,  0=normal)
    // RESET: active LOW  (0=in-reset,   1=normal)
    //   0~ 1ms : PWDN=1, RESET=0  — full shutdown
    //   1~ 2ms : PWDN=0, RESET=0  — exit powerdown, reset held
    //   2~16ms : PWDN=0, RESET=1  — camera boots (needs >8192 XCLK ≈ 0.34ms @ 24MHz)
    //   16ms+  : I2C starts
    reg [19:0] pwrseq_cnt = 20'd0;
`ifdef DEBUG
    (* MARK_DEBUG = "true" *) wire dbg_soft_reset;
    vio_0 u_vio (
        .clk       (clk_25),
        .probe_out0(dbg_soft_reset)
    );
    // VIO soft reset: pwrseq_cnt를 0으로 되돌려 PWDN/RESET 타이밍 포함 전체 재시작
    always @(posedge clk_25) begin
        if (dbg_soft_reset)
            pwrseq_cnt <= 20'd0;
        else if (pwrseq_cnt != 20'hFFFFF)
            pwrseq_cnt <= pwrseq_cnt + 1;
    end
`else
    always @(posedge clk_25)
        if (pwrseq_cnt != 20'hFFFFF) pwrseq_cnt <= pwrseq_cnt + 1;
`endif

`ifdef DEBUG
    assign ov5640_pwdn  = 1'b0;  // 카메라 PWDN GND 직결 → 항상 0 (dummy 출력)
    //assign ov5640_pwdn  = (pwrseq_cnt < 20'd25000);
    //assign ov5640_reset = ~dbg_soft_reset;
    assign ov5640_reset = (pwrseq_cnt >= 20'd50000);  // VIO→pwrseq_cnt 리셋으로 시퀀스 재실행
`else
    assign ov5640_pwdn  = 1'b0;  // 카메라 PWDN GND 직결 → 항상 0 (dummy 출력)
    //assign ov5640_pwdn  = (pwrseq_cnt < 20'd25000);
    assign ov5640_reset = (pwrseq_cnt >= 20'd50000);
`endif
    wire   pwrseq_done  = (pwrseq_cnt >= 20'd400000);  // done after ~16ms

    // I2C reset: held HIGH during power-up, then pulses HIGH for 128 cycles
    reg [7:0] i2c_rst_cnt = 8'd0;
    always @(posedge clk_25) begin
        if (!pwrseq_done)
            i2c_rst_cnt <= 8'd0;
        else if (!i2c_rst_cnt[7])
            i2c_rst_cnt <= i2c_rst_cnt + 1;
    end
    wire i2c_rst = !pwrseq_done | !i2c_rst_cnt[7];

    // I2C config (OV5640 register init)
    wire [9:0]  lut_index;
    wire [31:0] lut_data;

    i2c_config u_i2c_config (
        .rst            (i2c_rst),
        .clk            (clk_25),
        .clk_div_cnt    (16'd63),   // SCL ≈ 100kHz @ 25MHz
        .i2c_addr_2byte (1'b1),
        .lut_index      (lut_index),
        .lut_dev_addr   (lut_data[31:24]),
        .lut_reg_addr   (lut_data[23:8]),
        .lut_reg_data   (lut_data[7:0]),
        .error          (),
        .done           (config_done),
        .i2c_scl        (ov5640_sioc),
        .i2c_sda        (ov5640_siod)
    );

    lut_ov5640_rgb565_1280_720 u_lut (
        .lut_index (lut_index),
        .lut_data  (lut_data)
    );

    // OV5640 capture: 1280x720 → 320x240 (3:1 subsample, center crop)
    wire [18:0] wr_addr;
    wire [11:0] wr_data;  // RGB444: [11:8]=R [7:4]=G [3:0]=B
    wire        wren;

`ifdef DEBUG
    (* MARK_DEBUG = "true" *) wire dbg_wren  = wren;           // BRAM write enable — never HIGH → capture 불량
    (* MARK_DEBUG = "true" *) wire dbg_href  = ov5640_href;    // 라인 활성 — never HIGH → 카메라 신호 없음
    //(* MARK_DEBUG = "true" *) wire dbg_vsync = ov5640_vsync;   // 이전: 주석 처리 → net 이름 ov5640_vsync_IBUF 유지 (ila_insert.tcl과 매칭)
    (* MARK_DEBUG = "true" *) wire dbg_vsync = ov5640_vsync;   // 실험: MARK_DEBUG 활성 → net 이름 dbg_vsync → ov5640_vsync_IBUF 소실
    (* MARK_DEBUG = "true" *)(* KEEP = "true" *) wire [7:0] dbg_data = ov5640_data;
`endif

    ov5640_capture u_capture (
        .pclk  (pclk_buf),
        .vsync (ov5640_vsync),
        .href  (ov5640_href),
        .d     (ov5640_data),
        .addr  (wr_addr),
        .dout  (wr_data),
        .we    (wren)
    );

    // Frame buffer: 320x240 dual-port BRAM (BRAM inference)
    wire [18:0] rd_addr;
    wire [11:0] rd_data;

    frame_buffer u_frame_buffer (
        .clka  (pclk_buf),
        .wea   (wren),
        .addra (wr_addr[16:0]),
        .dina  (wr_data),
        .clkb  (clk_25),
        .addrb (rd_addr[16:0]),
        .doutb (rd_data)
    );

    // Display: VGA 640x480 timing, 2x upscale from 320x240 frame buffer
    wire [3:0] disp_r, disp_g, disp_b;
    wire       disp_hs, disp_vs, disp_de;

    display u_display (
        .clk25         (clk_25),
        .vga_red       (disp_r),
        .vga_green     (disp_g),
        .vga_blue      (disp_b),
        .vga_hsync     (disp_hs),
        .vga_vsync     (disp_vs),
        .vga_de        (disp_de),
        .frame_addr    (rd_addr),
        .frame_pixel   (rd_data),
        .camera_active (camera_active)
    );

    // HDMI encode: rgb2dvi (25MHz pixel clock → TMDS)
    // vid_pData ordering from pattern_hdmi.v: {R[7:0], B[7:0], G[7:0]}
    // Our frame_pixel: [11:8]=R, [7:4]=G, [3:0]=B → expand 4→8 bits each
    wire [7:0] hdmi_r = {disp_r, disp_r};
    wire [7:0] hdmi_g = {disp_g, disp_g};
    wire [7:0] hdmi_b = {disp_b, disp_b};

    rgb2dvi #(
        .kClkPrimitive ("MMCM"),
        .kClkRange     (5)       // 25MHz: kClkRange=5 (25~30MHz range)
    ) u_rgb2dvi (
        .PixelClk    (clk_25),
        .TMDS_Clk_n  (HDMI_CLK_N),
        .TMDS_Clk_p  (HDMI_CLK_P),
        .TMDS_Data_n (HDMI_N),
        .TMDS_Data_p (HDMI_P),
        .aRst        (1'b0),
        .vid_pData   ({hdmi_r, hdmi_b, hdmi_g}),
        .vid_pHSync  (disp_hs),
        .vid_pVDE    (disp_de),
        .vid_pVSync  (disp_vs)
    );

endmodule
