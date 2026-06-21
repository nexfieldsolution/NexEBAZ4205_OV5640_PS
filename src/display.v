`timescale 1ns / 1ps

module display(
    input clk25,
    output [3:0] vga_red,
    output [3:0] vga_green,
    output [3:0] vga_blue,
    output vga_hsync,
    output vga_vsync,
    output vga_de,              // data enable for rgb2dvi (high during active pixels)
    output [18:0] frame_addr,
    input  [11:0] frame_pixel,
    input         camera_active
);
    // VGA 640x480 @ 60Hz timing
    parameter hRez       = 640;
    parameter hStartSync = 640 + 16;
    parameter hEndSync   = 640 + 16 + 96;
    parameter hMaxCount  = 800;

    parameter vRez       = 480;
    parameter vStartSync = 480 + 10;
    parameter vEndSync   = 480 + 10 + 2;
    parameter vMaxCount  = 525;

    // 카메라 320x240 → VGA 640x480 2x2 업스케일 (combinatorial 주소)
    // BRAM 레이턴시 1사이클: (hCounter+1, vCounter)로 1클럭 선행 주소 계산

    reg [9:0]  hCounter = 10'd0;
    reg [9:0]  vCounter = 10'd0;

    reg [3:0] r_out, g_out, b_out;
    reg hs_out, vs_out, de_out;

    wire [9:0] hNext = (hCounter == hMaxCount - 1) ? 10'd0 : hCounter + 1;
    wire [9:0] vNext = (hCounter == hMaxCount - 1) ?
                       ((vCounter == vMaxCount - 1) ? 10'd0 : vCounter + 1) : vCounter;

    // 2x2 upscale: VGA(0..639) → cam(0..319), VGA(0..479) → cam(0..239)
    wire [8:0] cam_col = hNext[9:1];
    wire [7:0] cam_row = vNext[8:1];
    // cam_addr = cam_row * 320 + cam_col = cam_row*256 + cam_row*64 + cam_col
    wire [16:0] cam_addr = ({1'b0, cam_row, 8'b0} + {3'b0, cam_row, 6'b0} + {8'b0, cam_col});

    assign frame_addr = {2'b0, cam_addr};

    // ----------------------------------------------------------
    // 컬러바 테스트 패턴 (카메라 없을 때 표시)
    // ----------------------------------------------------------
    wire [2:0] bar_idx = hCounter[9:7];
    reg [3:0] bar_r, bar_g, bar_b;
    always @(*) begin
        case (bar_idx)
            3'd0: {bar_r, bar_g, bar_b} = {4'hF, 4'hF, 4'hF}; // 흰색
            3'd1: {bar_r, bar_g, bar_b} = {4'hF, 4'hF, 4'h0}; // 노랑
            3'd2: {bar_r, bar_g, bar_b} = {4'h0, 4'hF, 4'hF}; // 청록
            3'd3: {bar_r, bar_g, bar_b} = {4'h0, 4'hF, 4'h0}; // 초록
            3'd4: {bar_r, bar_g, bar_b} = {4'hF, 4'h0, 4'hF}; // 자홍
            3'd5: {bar_r, bar_g, bar_b} = {4'hF, 4'h0, 4'h0}; // 빨강
            3'd6: {bar_r, bar_g, bar_b} = {4'h0, 4'h0, 4'hF}; // 파랑
            3'd7: {bar_r, bar_g, bar_b} = {4'h0, 4'h0, 4'h0}; // 검정
        endcase
    end

    always @(posedge clk25) begin
        if (hCounter == hMaxCount - 1) begin
            hCounter <= 10'd0;
            if (vCounter == vMaxCount - 1)
                vCounter <= 10'd0;
            else
                vCounter <= vCounter + 1;
        end else begin
            hCounter <= hCounter + 1;
        end

        hs_out <= ~((hCounter >= hStartSync) && (hCounter < hEndSync));
        vs_out <= ~((vCounter >= vStartSync) && (vCounter < vEndSync));
        // de_out <= (hCounter < hRez) && (vCounter < vRez);  // 원본: HDMI에서 1클럭 오프셋 발생
        de_out <= (hCounter < hRez - 1) && (vCounter < vRez);

        if (hCounter < hRez && vCounter < vRez) begin
            if (!camera_active) begin
                r_out <= bar_r;
                g_out <= bar_g;
                b_out <= bar_b;
            end else begin
                r_out <= frame_pixel[11:8];
                g_out <= frame_pixel[7:4];
                b_out <= frame_pixel[3:0];
            end
        end else begin
            r_out <= 4'h0;
            g_out <= 4'h0;
            b_out <= 4'h0;
        end
    end

    assign vga_red    = r_out;
    assign vga_green  = g_out;
    assign vga_blue   = b_out;
    assign vga_hsync  = hs_out;
    assign vga_vsync  = vs_out;
    assign vga_de     = de_out;

endmodule
