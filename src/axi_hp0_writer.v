`timescale 1ns / 1ps
//
// axi_hp0_writer.v  —  OV5640 capture → AXI HP0 → DDR3 frame buffer
//
// 픽셀당 2바이트 narrow write (awsize=001, 64비트 버스 중 2바이트 선택)
// DDR3 주소: DDR3_BASE + pix_addr * 2
// 클럭 도메인 분리: PCLK(54MHz) → async FIFO → ACLK(FCLK_CLK0 50MHz)
//

module axi_hp0_writer #(
    parameter [31:0] DDR3_BASE = 32'h1000_0000   // 프레임버퍼 시작 주소
)(
    // ── Pixel input (PCLK ~54MHz) ──────────────────────────
    input             pclk,
    input      [16:0] pix_addr,   // ov5640_capture.addr (0..76799)
    input      [11:0] pix_data,   // ov5640_capture.dout (RGB444)
    input             pix_we,     // ov5640_capture.we

    // ── AXI HP0 master (FCLK_CLK0 50MHz) ──────────────────
    input             aclk,
    input             aresetn,    // active-low reset

    // AW 채널
    output reg [31:0] awaddr,
    output     [5:0]  awid,
    output     [3:0]  awlen,
    output     [2:0]  awsize,
    output     [1:0]  awburst,
    output     [1:0]  awlock,
    output     [3:0]  awcache,
    output     [2:0]  awprot,
    output     [3:0]  awqos,
    output reg        awvalid,
    input             awready,

    // W 채널
    output reg [63:0] wdata,
    output     [5:0]  wid,
    output reg [7:0]  wstrb,
    output            wlast,
    output reg        wvalid,
    input             wready,

    // B 채널
    input      [5:0]  bid,
    input      [1:0]  bresp,
    input             bvalid,
    output            bready
);

// ── 고정 AXI 신호 ──────────────────────────────────────────
assign awid    = 6'd0;
assign awlen   = 4'd0;       // 1 beat
assign awsize  = 3'b001;     // 2 bytes (narrow transfer)
assign awburst = 2'b01;      // INCR
assign awlock  = 2'b00;
assign awcache = 4'b0011;    // Bufferable
assign awprot  = 3'b000;
assign awqos   = 4'b0000;
assign wid     = 6'd0;
assign wlast   = 1'b1;       // single beat → 항상 last
assign bready  = 1'b1;       // 응답 항상 수락

// ── Async FIFO (PCLK write / ACLK read) ──────────────────
// 29bit: {pix_addr[16:0], pix_data[11:0]}  Depth: 32
localparam FDEPTH = 32;
localparam FAWID  = 5;        // log2(FDEPTH)
localparam FDWID  = 29;       // 17 + 12

reg [FDWID-1:0] fifo_mem [0:FDEPTH-1];

// 바이너리/그레이 포인터 (각 클럭 도메인)
reg [FAWID:0] wbin  = 0, wgray  = 0;   // PCLK 도메인
reg [FAWID:0] rbin  = 0, rgray  = 0;   // ACLK 도메인

// 2FF 동기화: gray 포인터를 반대 도메인으로 전달
reg [FAWID:0] wgray_s1 = 0, wgray_s2 = 0;  // ACLK 도메인으로 동기화
reg [FAWID:0] rgray_s1 = 0, rgray_s2 = 0;  // PCLK 도메인으로 동기화

always @(posedge aclk) {wgray_s2, wgray_s1} <= {wgray_s1, wgray};
always @(posedge pclk) {rgray_s2, rgray_s1} <= {rgray_s1, rgray};

// Full/Empty 판정
wire fifo_full  = (wgray == {~rgray_s2[FAWID:FAWID-1], rgray_s2[FAWID-2:0]});
wire fifo_empty = (rgray == wgray_s2);

// PCLK: write
always @(posedge pclk) begin
    if (pix_we && !fifo_full) begin
        fifo_mem[wbin[FAWID-1:0]] <= {pix_addr, pix_data};
        wbin  <= wbin  + 1;
        wgray <= (wbin + 1) ^ ((wbin + 1) >> 1);
    end
end

// ACLK: read (combinatorial read, sequential pointer update)
wire [FDWID-1:0] fifo_rdata = fifo_mem[rbin[FAWID-1:0]];
wire [16:0] f_addr = fifo_rdata[28:12];
wire [11:0] f_pix  = fifo_rdata[11:0];

reg fifo_pop = 0;
always @(posedge aclk) begin
    if (fifo_pop) begin
        rbin  <= rbin  + 1;
        rgray <= (rbin + 1) ^ ((rbin + 1) >> 1);
    end
end

// ── AXI Write State Machine (ACLK) ───────────────────────
localparam ST_IDLE = 2'd0;
localparam ST_AW   = 2'd1;
localparam ST_W    = 2'd2;
localparam ST_B    = 2'd3;

reg [1:0]  state    = ST_IDLE;
reg [16:0] lat_addr = 0;      // FIFO에서 꺼낸 픽셀 주소 래치
reg [11:0] lat_pix  = 0;      // FIFO에서 꺼낸 픽셀 데이터 래치

always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        state    <= ST_IDLE;
        awvalid  <= 1'b0;
        wvalid   <= 1'b0;
        fifo_pop <= 1'b0;
    end else begin
        fifo_pop <= 1'b0;   // 기본 0, 필요 시 1

        case (state)

        // ── IDLE: FIFO에서 픽셀 하나 꺼내기 ──────────────
        ST_IDLE: begin
            if (!fifo_empty) begin
                lat_addr <= f_addr;
                lat_pix  <= f_pix;
                fifo_pop <= 1'b1;
                state    <= ST_AW;
            end
        end

        // ── AW: 주소 채널 전송 ────────────────────────────
        ST_AW: begin
            // DDR3 바이트 주소 = BASE + addr*2
            awaddr  <= DDR3_BASE + {14'b0, lat_addr, 1'b0};
            awvalid <= 1'b1;

            // 픽셀(16bit)을 64비트 버스의 올바른 바이트 레인에 배치
            // lat_addr[1:0] → 버스 내 2바이트 위치 (0,2,4,6번 바이트)
            case (lat_addr[1:0])
                2'b00: begin wdata <= {48'b0, 4'b0, lat_pix};             wstrb <= 8'b0000_0011; end
                2'b01: begin wdata <= {32'b0, 4'b0, lat_pix, 16'b0};      wstrb <= 8'b0000_1100; end
                2'b10: begin wdata <= {16'b0, 4'b0, lat_pix, 32'b0};      wstrb <= 8'b0011_0000; end
                2'b11: begin wdata <= {       4'b0, lat_pix, 48'b0};      wstrb <= 8'b1100_0000; end
            endcase

            if (awvalid && awready) begin
                awvalid <= 1'b0;
                state   <= ST_W;
            end
        end

        // ── W: 데이터 채널 전송 ───────────────────────────
        ST_W: begin
            wvalid <= 1'b1;
            if (wvalid && wready) begin
                wvalid <= 1'b0;
                state  <= ST_B;
            end
        end

        // ── B: 응답 대기 ──────────────────────────────────
        ST_B: begin
            if (bvalid)
                state <= ST_IDLE;
        end

        endcase
    end
end

endmodule
