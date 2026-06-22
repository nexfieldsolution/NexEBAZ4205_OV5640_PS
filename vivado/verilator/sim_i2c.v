`timescale 1ns/1ps

// I2C config simulation wrapper
// - i2c_config의 tristate(inout) 대신 pad 신호 분리
// - 슬레이브 없음: SDA pullup만 있어 ACK 없으므로 error 신호 뜸
// - 목적: SCL/SDA 파형, config_done, error, lut_index 확인

module sim_i2c (
    input  clk,
    input  rst,
    output config_done,
    output error,
    output i2c_scl,
    output i2c_sda
);

    wire [31:0] lut_data;
    wire [9:0]  lut_index;

    lut_ov5640_rgb565_1280_720 u_lut (
        .lut_index (lut_index),
        .lut_data  (lut_data)
    );

    // i2c_master_top pad 신호 (tristate 없이 분리)
    wire scl_pad_o, scl_padoen_o;
    wire sda_pad_o, sda_padoen_o;
    wire i2c_write_req_ack;
    wire i2c_read_req_ack;
    wire [7:0] i2c_read_data;
    wire err;

    // 슬레이브 없음: 풀업만 (ACK 안 옴 → error 발생하지만 파형은 볼 수 있음)
    wire scl_pad_i = ~scl_padoen_o ? scl_pad_o : 1'b1;
    wire sda_pad_i = ~sda_padoen_o ? sda_pad_o : 1'b1;

    assign i2c_scl = scl_pad_i;
    assign i2c_sda = sda_pad_i;

    // i2c_config와 동일한 상태머신
    reg [2:0] state = 0;
    reg [9:0] lut_index_r = 0;
    reg i2c_write_req = 0;
    reg error_r = 0;

    localparam S_IDLE  = 0;
    localparam S_CHECK = 1;
    localparam S_WRITE = 2;
    localparam S_DONE  = 3;

    assign lut_index = lut_index_r;
    assign config_done = (state == S_DONE);
    assign error       = error_r;

    wire [7:0]  dev_addr = lut_data[31:24];
    wire [15:0] reg_addr = lut_data[23:8];
    wire [7:0]  reg_data = lut_data[7:0];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state         <= S_IDLE;
            lut_index_r   <= 0;
            i2c_write_req <= 0;
            error_r       <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    state       <= S_CHECK;
                    lut_index_r <= 0;
                    error_r     <= 0;
                end
                S_CHECK: begin
                    if (dev_addr != 8'hff) begin
                        i2c_write_req <= 1;
                        state         <= S_WRITE;
                    end else begin
                        state <= S_DONE;
                    end
                end
                S_WRITE: begin
                    if (i2c_write_req_ack) begin
                        error_r       <= err ? 1'b1 : error_r;
                        lut_index_r   <= lut_index_r + 1;
                        i2c_write_req <= 0;
                        state         <= S_CHECK;
                    end
                end
                S_DONE: state <= S_DONE;
            endcase
        end
    end

    i2c_master_top u_i2c_master (
        .rst               (rst),
        .clk               (clk),
        .clk_div_cnt       (16'd63),
        .scl_pad_i         (scl_pad_i),
        .scl_pad_o         (scl_pad_o),
        .scl_padoen_o      (scl_padoen_o),
        .sda_pad_i         (sda_pad_i),
        .sda_pad_o         (sda_pad_o),
        .sda_padoen_o      (sda_padoen_o),
        .i2c_addr_2byte    (1'b1),
        .i2c_read_req      (1'b0),
        .i2c_read_req_ack  (i2c_read_req_ack),
        .i2c_write_req     (i2c_write_req),
        .i2c_write_req_ack (i2c_write_req_ack),
        .i2c_slave_dev_addr(dev_addr),
        .i2c_slave_reg_addr(reg_addr),
        .i2c_write_data    (reg_data),
        .i2c_read_data     (i2c_read_data),
        .error             (err)
    );

endmodule
