// Clock generation: 50MHz -> 25MHz (EBAZ4205 PL clock = N18 = 50MHz)
// Uses Zynq-7000 MMCME2_BASE primitive (same as Artix-7)
module clocking (
    input  CLK_50,
    output CLK_25
);
    wire clkfb;
    wire clk25_buf;

    MMCME2_BASE #(
        .CLKIN1_PERIOD   (20.0),  // 50 MHz input
        .CLKFBOUT_MULT_F (20.0),  // VCO = 50 * 20 = 1000 MHz
        .CLKOUT0_DIVIDE_F(40.0),  // 1000 / 40 = 25 MHz
        .DIVCLK_DIVIDE   (1)
    ) mmcm_inst (
        .CLKIN1   (CLK_50),
        .CLKFBIN  (clkfb),
        .CLKFBOUT (clkfb),
        .CLKOUT0  (clk25_buf),
        .PWRDWN   (1'b0),
        .RST      (1'b0)
    );

    BUFG buf25 (.I(clk25_buf), .O(CLK_25));

endmodule
