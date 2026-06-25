`timescale 1ns / 1ps
//
// axi_hp1_reader.v  —  DDR3 프레임버퍼 → AXI HP1 → 디스플레이 라인 버퍼
//
// 320x240 픽셀 중 요청된 소스 행(src_row)을 DDR3에서 버스트 읽어
// 320×16 라인 버퍼에 저장. disp_clk 도메인에서 src_col로 1사이클 레이턴시로 출력.
//
// 버스트: arlen=15 (16beat) × arsize=011 (8B) = 128B = 64픽셀
//   행당 5버스트 → 320픽셀. aclk(50MHz)에서 ≈1.9μs / 행 표시시간 ≈63μs
//   → 마진 30배 이상 확보
//
// CDC: src_row 변화를 토글+2FF 동기화로 aclk 도메인에 전달
//   리셋 후 pending=1/pending_row=0으로 초기화 → 행 0 즉시 선행 패치
//

module axi_hp1_reader #(
    parameter [31:0] DDR3_BASE = 32'h1000_0000
)(
    // ── 디스플레이 인터페이스 (disp_clk = 25 MHz) ──────────────
    input             disp_clk,
    input      [7:0]  src_row,      // 현재 요청 소스 행 0..239 (1사이클 선행)
    input      [8:0]  src_col,      // 현재 요청 소스 열 0..319 (1사이클 선행)
    output reg [11:0] frame_pixel,  // 1사이클 레이턴시 픽셀 출력

    // ── AXI HP1 읽기 마스터 (aclk = 50 MHz) ────────────────────
    input             aclk,
    input             aresetn,
    // AR 채널
    output reg [31:0] araddr,
    output     [5:0]  arid,
    output     [3:0]  arlen,
    output     [2:0]  arsize,
    output     [1:0]  arburst,
    output     [1:0]  arlock,
    output     [3:0]  arcache,
    output     [2:0]  arprot,
    output     [3:0]  arqos,
    output reg        arvalid,
    input             arready,
    // R 채널
    input      [63:0] rdata,
    input      [5:0]  rid,
    input      [1:0]  rresp,
    input             rlast,
    input             rvalid,
    output            rready
);

// ── 고정 AXI 신호 ──────────────────────────────────────────────
assign arid    = 6'd0;
assign arlen   = 4'd15;      // 16 beats per burst
assign arsize  = 3'b011;     // 8 bytes (64-bit bus)
assign arburst = 2'b01;      // INCR
assign arlock  = 2'b00;
assign arcache = 4'b0011;    // Bufferable
assign arprot  = 3'b000;
assign arqos   = 4'd0;
assign rready  = 1'b1;       // 읽기 데이터 항상 수락

// ── 라인 버퍼: 320×16-bit BRAM (Xilinx 듀얼 포트 추론) ─────────
// 포트 A (aclk):     AXI R채널 수신 데이터 쓰기
// 포트 B (disp_clk): src_col 인덱스로 픽셀 읽기
(* RAM_STYLE = "block" *)
reg [15:0] line_buf [0:319];

// disp_clk: 동기 읽기 (1사이클 레이턴시)
always @(posedge disp_clk)
    frame_pixel <= line_buf[src_col][11:0];

// ── CDC: src_row 변화 → aclk 도메인 전달 (토글 + 2FF) ──────────
reg [7:0] src_row_d = 8'd0;
reg       req_tog   = 1'b0;
reg [7:0] req_row   = 8'd0;

always @(posedge disp_clk) begin
    src_row_d <= src_row;
    if (src_row != src_row_d) begin
        req_row <= src_row;
        req_tog <= ~req_tog;
    end
end

reg [1:0] tog_sync = 2'b00;
reg [7:0] row_sync = 8'd0;
always @(posedge aclk) begin
    tog_sync <= {tog_sync[0], req_tog};
    row_sync <= req_row;
end

wire       fetch_req = tog_sync[0] ^ tog_sync[1];
wire [7:0] fetch_row = row_sync;

// ── AXI 읽기 상태기 (aclk) ─────────────────────────────────────
localparam ST_IDLE = 2'd0;
localparam ST_AR   = 2'd1;
localparam ST_R    = 2'd2;

reg [1:0]  state     = ST_IDLE;
reg [7:0]  rd_row    = 8'd0;
reg [2:0]  burst_cnt = 3'd0;
reg [8:0]  wr_col    = 9'd0;

// 새 요청 래치 (busy 중 도착한 요청을 최신 행으로 갱신)
reg        pending     = 1'b1;   // 리셋 후 행 0 즉시 패치
reg [7:0]  pending_row = 8'd0;

// row_base = DDR3_BASE + rd_row × 640  (640 = 512 + 128)
// 행 640바이트는 128B의 배수 → 버스트 정렬 ✓
wire [31:0] row_base = DDR3_BASE
    + {15'd0, rd_row, 9'd0}      // rd_row × 512
    + {17'd0, rd_row, 7'd0};     // rd_row × 128

// burst_off = burst_cnt × 128
wire [31:0] burst_off = {22'd0, burst_cnt, 7'd0};

always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        state       <= ST_IDLE;
        arvalid     <= 1'b0;
        burst_cnt   <= 3'd0;
        wr_col      <= 9'd0;
        pending     <= 1'b1;   // 리셋 후 행 0 즉시 패치
        pending_row <= 8'd0;
    end else begin
        // 새 fetch 요청: 최신 행으로 pending 갱신
        if (fetch_req) begin
            pending     <= 1'b1;
            pending_row <= fetch_row;
        end

        case (state)

        // ── IDLE: pending 요청 확인 ──────────────────────────────
        ST_IDLE: begin
            if (pending) begin
                rd_row    <= pending_row;
                pending   <= 1'b0;
                burst_cnt <= 3'd0;
                wr_col    <= 9'd0;
                state     <= ST_AR;
            end
        end

        // ── AR: 읽기 주소 채널 ───────────────────────────────────
        ST_AR: begin
            araddr  <= row_base + burst_off;
            arvalid <= 1'b1;
            if (arvalid && arready) begin
                arvalid <= 1'b0;
                state   <= ST_R;
            end
        end

        // ── R: 읽기 데이터 채널 → 라인 버퍼 기록 ────────────────
        ST_R: begin
            if (rvalid) begin
                // 64비트 워드 = 4픽셀 (픽셀당 2바이트, 상위 4비트 = 0 패딩)
                line_buf[wr_col    ] <= rdata[15:0];
                line_buf[wr_col + 1] <= rdata[31:16];
                line_buf[wr_col + 2] <= rdata[47:32];
                line_buf[wr_col + 3] <= rdata[63:48];
                wr_col <= wr_col + 9'd4;
                if (rlast) begin
                    if (burst_cnt == 3'd4)
                        state <= ST_IDLE;
                    else begin
                        burst_cnt <= burst_cnt + 3'd1;
                        state     <= ST_AR;
                    end
                end
            end
        end

        default: state <= ST_IDLE;
        endcase
    end
end

endmodule
