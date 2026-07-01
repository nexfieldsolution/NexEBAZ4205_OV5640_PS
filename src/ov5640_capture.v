`timescale 1ns / 1ps

module ov5640_capture(
    input pclk,
    input vsync,
    input href,
    input [7:0] d,
    output [18:0] addr,
    output [11:0] dout,
    output we
  );
  // Camera: 1280x720 출력
  // 가운데 크롭: 양옆 160px씩 제거 → 960x720 (4:3 비율)
  // H 3:1 서브샘플, V 3:1 서브샘플 → 320x240 BRAM 저장
  // VGA에서 2x2 업스케일 → 640x480, 원이 원으로 나옴

  parameter H_CROP_START = 11'd160;   // 좌측 버릴 픽셀 수
  parameter H_CROP_END   = 11'd1120;  // 160 + 960

  reg [15:0] d_latch  = 16'd0;
  reg [10:0] h_pixel  = 11'd0;   // 픽셀 카운터 (0..1279)
  reg [1:0]  h_sub    =  2'd0;   // H 3:1 서브샘플 카운터 (0..2)
  reg [1:0]  v_sub    =  2'd0;   // V 3:1 서브샘플 카운터 (0..2)
  reg        byte_cnt =  1'b0;
  reg [16:0] addr_reg   = 17'd0;   // 최대 76799 (320x240-1)
  reg [16:0] addr_latch = 17'd0;   // addr_reg 증가 전 값 (1클럭 지연 보정)
  reg [11:0] dout_reg = 12'd0;
  reg        we_reg   = 1'b0;

  // vsync edge detection already defined above

  reg        vsync_d   = 1'b0;
  wire vsync_edge = (vsync ^ vsync_d);



  assign addr = {2'b0, addr_latch};
  assign dout = dout_reg;
  assign we   = we_reg;

  wire in_crop = (h_pixel >= H_CROP_START) && (h_pixel < H_CROP_END);

  // BGR565 HIGH-byte-first: 카메라가 HIGH(BBBBBGGG) 먼저, LOW(GGGRRRRR) 나중 전송
  // Cycle A(byte_cnt=0): d=HIGH → d_latch[15:8]에 보관
  // Cycle B(byte_cnt=1): pix16={HIGH,LOW}={BBBBBGGG,GGGRRRRR}
  //   R=[4:1](LOW bits), G=[10:7](HIGH[2:0]+LOW[7]), B=[15:12](HIGH bits)
  // D[2](J20=XADC VAUXP[5], 1고착) — G MSB 항상 1 = 녹색 편향 (보정 포기)
  wire [15:0] pix16 = {d_latch[15:8], d};

  // always @(posedge pclk)
 always @(posedge pclk)
  begin
    if (vsync)
    begin  // vsync HIGH = blanking → reset counters
      h_pixel  <= 11'd0;
      h_sub    <=  2'd0;
      v_sub    <=  2'd0;
      byte_cnt <=  1'b0;
      addr_reg   <= 17'd0;
      addr_latch <= 17'd0;
      we_reg     <=  1'b0;
    end
    else if (href)
    begin
      byte_cnt <= ~byte_cnt;
      d_latch  <= {d, d_latch[15:8]}; //d (새 바이트) → [15:8] 상위로

      if (byte_cnt == 1'b1)
      begin
        // 2바이트 수신 완료 → 픽셀 완성
        if (in_crop && h_sub == 2'd0 && v_sub == 2'd0)
        begin
          dout_reg <= {pix16[4:1], pix16[10:7], pix16[15:12]};  // R=[4:1], G=[10:7], B=[15:12]
          // dout_reg <= 12'hF00;
          we_reg     <= 1'b1;
          addr_latch <= addr_reg;          // 증가 전 주소 래치 (1클럭 지연 보정)
          addr_reg   <= addr_reg + 1'b1;
        end
        else
        begin
          we_reg <= 1'b0;
        end

        // 크롭 영역 안에서만 H 서브샘플 카운터 진행
        if (in_crop)
          h_sub <= (h_sub == 2'd2) ? 2'd0 : h_sub + 1'b1;

        h_pixel <= h_pixel + 1'b1;
      end
      else
      begin
        we_reg <= 1'b0;
      end
    end
    else
    begin
      // href 비활성: 라인 끝
      we_reg <= 1'b0;
      if (h_pixel != 11'd0)
      begin
        h_pixel  <= 11'd0;
        byte_cnt <=  1'b0;
        h_sub    <=  2'd0;
        v_sub    <= (v_sub == 2'd2) ? 2'd0 : v_sub + 1'b1;
      end
    end
  end

endmodule
