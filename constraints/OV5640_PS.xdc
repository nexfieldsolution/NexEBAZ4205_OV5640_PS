# NexEBAZ4205_OV5640_HDMI constraints
# EBAZ4205 + hellofpga IO board 20-pin camera connector

# Clock: 50MHz PL oscillator
set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVCMOS33} [get_ports CLK]
create_clock -period 20.000 -name sys_clk -waveform {0.000 10.000} [get_ports CLK]

# UART TX (hellofpga Type-C CH340, H17)
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports UART_TX]

# HDMI (TMDS, hellofpga IO board)
set_property -dict {PACKAGE_PIN F20 IOSTANDARD TMDS_33} [get_ports HDMI_CLK_N]
set_property -dict {PACKAGE_PIN F19 IOSTANDARD TMDS_33} [get_ports HDMI_CLK_P]
set_property -dict {PACKAGE_PIN D20 IOSTANDARD TMDS_33} [get_ports {HDMI_N[0]}]
set_property -dict {PACKAGE_PIN D19 IOSTANDARD TMDS_33} [get_ports {HDMI_P[0]}]
set_property -dict {PACKAGE_PIN B20 IOSTANDARD TMDS_33} [get_ports {HDMI_N[1]}]
set_property -dict {PACKAGE_PIN C20 IOSTANDARD TMDS_33} [get_ports {HDMI_P[1]}]
set_property -dict {PACKAGE_PIN A20 IOSTANDARD TMDS_33} [get_ports {HDMI_N[2]}]
set_property -dict {PACKAGE_PIN B19 IOSTANDARD TMDS_33} [get_ports {HDMI_P[2]}]

# OV5640 - hellofpga IO board 20-pin camera connector
# connector(FPGA) ↔ camera signal
set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVCMOS33} [get_ports ov5640_vsync]

set_property -dict {PACKAGE_PIN N20 IOSTANDARD LVCMOS33} [get_ports ov5640_href]
#set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVCMOS33} [get_ports ov5640_reset]
# camera RST → J20 점퍼 (XADC핀이지만 출력으로는 정상 동작)
set_property -dict {PACKAGE_PIN J20 IOSTANDARD LVCMOS33} [get_ports ov5640_reset]
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33 PULLUP true} [get_ports ov5640_sioc]
set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVCMOS33 PULLUP true} [get_ports ov5640_siod]
# D[0]: M20(AD2N XADC→불가) → G19 (구 PWDN핀, 카메라 PWDN은 GND 직결)
set_property -dict {PACKAGE_PIN G19 IOSTANDARD LVCMOS33} [get_ports {ov5640_data[0]}]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD LVCMOS33} [get_ports {ov5640_data[1]}]
# D[2]: J20(XADC, 포기) → G20 (구 RST핀 재활용, 카메라 RST=J20 점퍼)
set_property -dict {PACKAGE_PIN G20 IOSTANDARD LVCMOS33} [get_ports {ov5640_data[2]}]
set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS33} [get_ports {ov5640_data[3]}]
# D[4]: L20(AD3N XADC→불가) → K18 (MRCC N-type, 데이터핀으로 사용)
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS33} [get_ports {ov5640_data[4]}]
set_property -dict {PACKAGE_PIN J19 IOSTANDARD LVCMOS33} [get_ports {ov5640_data[5]}]
set_property -dict {PACKAGE_PIN K19 IOSTANDARD LVCMOS33} [get_ports {ov5640_data[6]}]
set_property -dict {PACKAGE_PIN H20 IOSTANDARD LVCMOS33} [get_ports {ov5640_data[7]}]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS33} [get_ports ov5640_pclk]
# PWDN: 카메라 모듈 GND 직결 → FPGA 출력은 dummy (L17에 할당)
set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVCMOS33} [get_ports ov5640_pwdn]

# G20: D[2] (구 RST핀 재활용, 카메라 D[2] 점퍼)
# J18: PCLK (MRCC P-type. 카메라 모듈 내부 오실레이터 54MHz)
# J20: ov5640_reset (XADC핀이지만 출력으로 사용, 카메라 RST 점퍼)
# K18: D[4] (MRCC N-type, 클럭 아닌 데이터 입력으로 사용)
# G19: D[0] (구 PWDN 자리. 카메라 PWDN은 GND 직결)
# M20/L17/L20: XADC 또는 stuck 핀 → 미사용 (D[0,2,4] 재배선)

# PCLK: MRCC P-type 핀(J18), BUFG 라우팅 가능 (CLOCK_DEDICATED_ROUTE 불필요)
# create_clock이 없으면 pclk 도메인 FF이 unconstrained → 타이밍 미검사
create_clock -period 18.519 -name pclk [get_ports ov5640_pclk]

set_clock_groups -asynchronous \
    -group [get_clocks clk_fpga_0] \
    -group [get_clocks pclk]
    
# pclk ↔ clk25: 비동기 클럭 도메인, CDC 경로 timing 검사 제외
set_clock_groups -asynchronous -group [get_clocks pclk] -group [get_clocks clk25_buf]
