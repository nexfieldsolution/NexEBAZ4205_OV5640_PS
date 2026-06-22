`timescale 1ns / 1ps

module top_ov5640_ps (
    // PS7 DDR
    inout  [14:0]   DDR_addr,
    inout  [2:0]    DDR_ba,
    inout           DDR_cas_n,
    inout           DDR_ck_n,
    inout           DDR_ck_p,
    inout           DDR_cke,
    inout           DDR_cs_n,
    inout  [3:0]    DDR_dm,
    inout  [31:0]   DDR_dq,
    inout  [3:0]    DDR_dqs_n,
    inout  [3:0]    DDR_dqs_p,
    inout           DDR_odt,
    inout           DDR_ras_n,
    inout           DDR_reset_n,
    inout           DDR_we_n,
    // PS7 FIXED_IO
    inout           FIXED_IO_ddr_vrn,
    inout           FIXED_IO_ddr_vrp,
    inout  [53:0]   FIXED_IO_mio,
    inout           FIXED_IO_ps_clk,
    inout           FIXED_IO_ps_porb,
    inout           FIXED_IO_ps_srstb,
    // PS7 clock output
    output          FCLK_CLK0,

    // OV5640 DVP interface
    input           ov5640_pclk,
    input           ov5640_vsync,
    input           ov5640_href,
    input  [7:0]    ov5640_data,
    inout           ov5640_sioc,
    inout           ov5640_siod,
    output          ov5640_pwdn,
    output          ov5640_reset,

    // HDMI output (TMDS)
    output          HDMI_CLK_N,
    output          HDMI_CLK_P,
    output [2:0]    HDMI_N,
    output [2:0]    HDMI_P
);

    // ----------------------------------------------------------------
    // AXI HP0 wires (OV5640 capture → DDR3 write)
    // ----------------------------------------------------------------
    wire [31:0] hp0_awaddr;  wire [5:0] hp0_awid;   wire [3:0] hp0_awlen;
    wire [2:0]  hp0_awsize;  wire [1:0] hp0_awburst; wire [1:0] hp0_awlock;
    wire [3:0]  hp0_awcache; wire [2:0] hp0_awprot;  wire [3:0] hp0_awqos;
    wire        hp0_awvalid; wire       hp0_awready;
    wire [63:0] hp0_wdata;   wire [5:0] hp0_wid;     wire [7:0] hp0_wstrb;
    wire        hp0_wlast;   wire       hp0_wvalid;   wire       hp0_wready;
    wire [5:0]  hp0_bid;     wire [1:0] hp0_bresp;    wire       hp0_bvalid;
    wire        hp0_bready;
    wire [31:0] hp0_araddr;  wire [5:0] hp0_arid;    wire [3:0] hp0_arlen;
    wire [2:0]  hp0_arsize;  wire [1:0] hp0_arburst;  wire [1:0] hp0_arlock;
    wire [3:0]  hp0_arcache; wire [2:0] hp0_arprot;   wire [3:0] hp0_arqos;
    wire        hp0_arvalid; wire       hp0_arready;
    wire [63:0] hp0_rdata;   wire [5:0] hp0_rid;      wire [1:0] hp0_rresp;
    wire        hp0_rlast;   wire       hp0_rvalid;    wire       hp0_rready;

    // ----------------------------------------------------------------
    // AXI HP1 wires (DDR3 read → display)
    // ----------------------------------------------------------------
    wire [31:0] hp1_awaddr;  wire [5:0] hp1_awid;   wire [3:0] hp1_awlen;
    wire [2:0]  hp1_awsize;  wire [1:0] hp1_awburst; wire [1:0] hp1_awlock;
    wire [3:0]  hp1_awcache; wire [2:0] hp1_awprot;  wire [3:0] hp1_awqos;
    wire        hp1_awvalid; wire       hp1_awready;
    wire [63:0] hp1_wdata;   wire [5:0] hp1_wid;     wire [7:0] hp1_wstrb;
    wire        hp1_wlast;   wire       hp1_wvalid;   wire       hp1_wready;
    wire [5:0]  hp1_bid;     wire [1:0] hp1_bresp;    wire       hp1_bvalid;
    wire        hp1_bready;
    wire [31:0] hp1_araddr;  wire [5:0] hp1_arid;    wire [3:0] hp1_arlen;
    wire [2:0]  hp1_arsize;  wire [1:0] hp1_arburst;  wire [1:0] hp1_arlock;
    wire [3:0]  hp1_arcache; wire [2:0] hp1_arprot;   wire [3:0] hp1_arqos;
    wire        hp1_arvalid; wire       hp1_arready;
    wire [63:0] hp1_rdata;   wire [5:0] hp1_rid;      wire [1:0] hp1_rresp;
    wire        hp1_rlast;   wire       hp1_rvalid;    wire       hp1_rready;

    // ----------------------------------------------------------------
    // PS7 block design instance
    // ----------------------------------------------------------------
    design_1_wrapper u_ps7 (
        .DDR_addr           (DDR_addr),
        .DDR_ba             (DDR_ba),
        .DDR_cas_n          (DDR_cas_n),
        .DDR_ck_n           (DDR_ck_n),
        .DDR_ck_p           (DDR_ck_p),
        .DDR_cke            (DDR_cke),
        .DDR_cs_n           (DDR_cs_n),
        .DDR_dm             (DDR_dm),
        .DDR_dq             (DDR_dq),
        .DDR_dqs_n          (DDR_dqs_n),
        .DDR_dqs_p          (DDR_dqs_p),
        .DDR_odt            (DDR_odt),
        .DDR_ras_n          (DDR_ras_n),
        .DDR_reset_n        (DDR_reset_n),
        .DDR_we_n           (DDR_we_n),
        .FIXED_IO_ddr_vrn   (FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp   (FIXED_IO_ddr_vrp),
        .FIXED_IO_mio       (FIXED_IO_mio),
        .FIXED_IO_ps_clk    (FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb   (FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb  (FIXED_IO_ps_srstb),
        .FCLK_CLK0          (FCLK_CLK0),
        // AXI HP0
        .S_AXI_HP0_0_awaddr  (hp0_awaddr),  .S_AXI_HP0_0_awid    (hp0_awid),
        .S_AXI_HP0_0_awlen   (hp0_awlen),   .S_AXI_HP0_0_awsize  (hp0_awsize),
        .S_AXI_HP0_0_awburst (hp0_awburst), .S_AXI_HP0_0_awlock  (hp0_awlock),
        .S_AXI_HP0_0_awcache (hp0_awcache), .S_AXI_HP0_0_awprot  (hp0_awprot),
        .S_AXI_HP0_0_awqos   (hp0_awqos),   .S_AXI_HP0_0_awvalid (hp0_awvalid),
        .S_AXI_HP0_0_awready (hp0_awready),
        .S_AXI_HP0_0_wdata   (hp0_wdata),   .S_AXI_HP0_0_wid     (hp0_wid),
        .S_AXI_HP0_0_wstrb   (hp0_wstrb),   .S_AXI_HP0_0_wlast   (hp0_wlast),
        .S_AXI_HP0_0_wvalid  (hp0_wvalid),  .S_AXI_HP0_0_wready  (hp0_wready),
        .S_AXI_HP0_0_bid     (hp0_bid),     .S_AXI_HP0_0_bresp   (hp0_bresp),
        .S_AXI_HP0_0_bvalid  (hp0_bvalid),  .S_AXI_HP0_0_bready  (hp0_bready),
        .S_AXI_HP0_0_araddr  (hp0_araddr),  .S_AXI_HP0_0_arid    (hp0_arid),
        .S_AXI_HP0_0_arlen   (hp0_arlen),   .S_AXI_HP0_0_arsize  (hp0_arsize),
        .S_AXI_HP0_0_arburst (hp0_arburst), .S_AXI_HP0_0_arlock  (hp0_arlock),
        .S_AXI_HP0_0_arcache (hp0_arcache), .S_AXI_HP0_0_arprot  (hp0_arprot),
        .S_AXI_HP0_0_arqos   (hp0_arqos),   .S_AXI_HP0_0_arvalid (hp0_arvalid),
        .S_AXI_HP0_0_arready (hp0_arready),
        .S_AXI_HP0_0_rdata   (hp0_rdata),   .S_AXI_HP0_0_rid     (hp0_rid),
        .S_AXI_HP0_0_rresp   (hp0_rresp),   .S_AXI_HP0_0_rlast   (hp0_rlast),
        .S_AXI_HP0_0_rvalid  (hp0_rvalid),  .S_AXI_HP0_0_rready  (hp0_rready),
        // AXI HP1
        .S_AXI_HP1_0_awaddr  (hp1_awaddr),  .S_AXI_HP1_0_awid    (hp1_awid),
        .S_AXI_HP1_0_awlen   (hp1_awlen),   .S_AXI_HP1_0_awsize  (hp1_awsize),
        .S_AXI_HP1_0_awburst (hp1_awburst), .S_AXI_HP1_0_awlock  (hp1_awlock),
        .S_AXI_HP1_0_awcache (hp1_awcache), .S_AXI_HP1_0_awprot  (hp1_awprot),
        .S_AXI_HP1_0_awqos   (hp1_awqos),   .S_AXI_HP1_0_awvalid (hp1_awvalid),
        .S_AXI_HP1_0_awready (hp1_awready),
        .S_AXI_HP1_0_wdata   (hp1_wdata),   .S_AXI_HP1_0_wid     (hp1_wid),
        .S_AXI_HP1_0_wstrb   (hp1_wstrb),   .S_AXI_HP1_0_wlast   (hp1_wlast),
        .S_AXI_HP1_0_wvalid  (hp1_wvalid),  .S_AXI_HP1_0_wready  (hp1_wready),
        .S_AXI_HP1_0_bid     (hp1_bid),     .S_AXI_HP1_0_bresp   (hp1_bresp),
        .S_AXI_HP1_0_bvalid  (hp1_bvalid),  .S_AXI_HP1_0_bready  (hp1_bready),
        .S_AXI_HP1_0_araddr  (hp1_araddr),  .S_AXI_HP1_0_arid    (hp1_arid),
        .S_AXI_HP1_0_arlen   (hp1_arlen),   .S_AXI_HP1_0_arsize  (hp1_arsize),
        .S_AXI_HP1_0_arburst (hp1_arburst), .S_AXI_HP1_0_arlock  (hp1_arlock),
        .S_AXI_HP1_0_arcache (hp1_arcache), .S_AXI_HP1_0_arprot  (hp1_arprot),
        .S_AXI_HP1_0_arqos   (hp1_arqos),   .S_AXI_HP1_0_arvalid (hp1_arvalid),
        .S_AXI_HP1_0_arready (hp1_arready),
        .S_AXI_HP1_0_rdata   (hp1_rdata),   .S_AXI_HP1_0_rid     (hp1_rid),
        .S_AXI_HP1_0_rresp   (hp1_rresp),   .S_AXI_HP1_0_rlast   (hp1_rlast),
        .S_AXI_HP1_0_rvalid  (hp1_rvalid),  .S_AXI_HP1_0_rready  (hp1_rready)
    );

   

    wire clk_74m25;  // pixel clock (~74.25MHz) → HDMI 720p
    wire clk_25;     // config clock (25MHz)    → I2C, power-up
    (* MARK_DEBUG = "true" *) wire config_done;

    // Clock: 50MHz → 74.157MHz (pixel) + 25MHz (config)
    clocking u_clocking (
        .CLK_50   (FCLK_CLK0),
        .CLK_74M25(clk_74m25),
        .CLK_25   (clk_25)
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

    // // Frame buffer: 320x240 dual-port BRAM (BRAM inference)
    // wire [18:0] rd_addr;
    // wire [11:0] rd_data;

    // frame_buffer u_frame_buffer (
    //     .clka  (pclk_buf),
    //     .wea   (wren),
    //     .addra (wr_addr[16:0]),
    //     .dina  (wr_data),
    //     .clkb  (clk_25),
    //     .addrb (rd_addr[16:0]),
    //     .doutb (rd_data)
    // );

    // // Display: VGA 640x480 timing, 2x upscale from 320x240 frame buffer
    // wire [3:0] disp_r, disp_g, disp_b;
    // wire       disp_hs, disp_vs, disp_de;

    // display u_display (
    //     .clk25         (clk_25),
    //     .vga_red       (disp_r),
    //     .vga_green     (disp_g),
    //     .vga_blue      (disp_b),
    //     .vga_hsync     (disp_hs),
    //     .vga_vsync     (disp_vs),
    //     .vga_de        (disp_de),
    //     .frame_addr    (rd_addr),
    //     .frame_pixel   (rd_data),
    //     .camera_active (camera_active)
    // );

    // // HDMI encode: rgb2dvi (25MHz pixel clock → TMDS)
    // // vid_pData ordering from pattern_hdmi.v: {R[7:0], B[7:0], G[7:0]}
    // // Our frame_pixel: [11:8]=R, [7:4]=G, [3:0]=B → expand 4→8 bits each
    // wire [7:0] hdmi_r = {disp_r, disp_r};
    // wire [7:0] hdmi_g = {disp_g, disp_g};
    // wire [7:0] hdmi_b = {disp_b, disp_b};

    // rgb2dvi #(
    //     .kClkPrimitive ("MMCM"),
    //     .kClkRange     (5)       // 25MHz: kClkRange=5 (25~30MHz range)
    // ) u_rgb2dvi (
    //     .PixelClk    (clk_25),
    //     .TMDS_Clk_n  (HDMI_CLK_N),
    //     .TMDS_Clk_p  (HDMI_CLK_P),
    //     .TMDS_Data_n (HDMI_N),
    //     .TMDS_Data_p (HDMI_P),
    //     .aRst        (1'b0),
    //     .vid_pData   ({hdmi_r, hdmi_b, hdmi_g}),
    //     .vid_pHSync  (disp_hs),
    //     .vid_pVDE    (disp_de),
    //     .vid_pVSync  (disp_vs)
    // );
 

endmodule