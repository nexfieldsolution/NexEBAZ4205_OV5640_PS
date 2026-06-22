// Clock generation: 50MHz -> 74.157MHz (pixel) + 25MHz (config)
// VCO = 50 * 16.5 = 825MHz
//   CLKOUT0 / 11.125 = 74.157MHz (~74.25MHz, 0.125% error, within HDMI tolerance)
//   CLKOUT1 / 33     = 25.000MHz (I2C config clock)
module clocking (
    input  CLK_50,
    output CLK_74M25,
    output CLK_25
);
    wire clkfb;
    wire clk74_buf;
    wire clk25_buf;

    MMCME2_BASE #(
        .CLKIN1_PERIOD    (20.0),   // 50 MHz input
        .CLKFBOUT_MULT_F  (16.5),   // VCO = 50 * 16.5 = 825 MHz
        .DIVCLK_DIVIDE    (1),
        .CLKOUT0_DIVIDE_F (11.125), // 825 / 11.125 = 74.157 MHz (pixel clock)
        .CLKOUT1_DIVIDE   (33)      // 825 / 33     = 25.000 MHz (config clock)
    ) mmcm_inst (
        .CLKIN1   (CLK_50),
        .CLKFBIN  (clkfb),
        .CLKFBOUT (clkfb),
        .CLKOUT0  (clk74_buf),
        .CLKOUT1  (clk25_buf),
        .PWRDWN   (1'b0),
        .RST      (1'b0)
    );

    BUFG buf74 (.I(clk74_buf), .O(CLK_74M25));
    BUFG buf25 (.I(clk25_buf), .O(CLK_25));

endmodule
