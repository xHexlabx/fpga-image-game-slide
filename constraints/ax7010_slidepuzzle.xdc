set_property PACKAGE_PIN U18 [get_ports {sys_clk}]
set_property IOSTANDARD LVCMOS33 [get_ports {sys_clk}]
create_clock -period 20.000 -waveform {0.000 10.000} [get_ports sys_clk]

set_property PACKAGE_PIN N15 [get_ports {key[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {key[0]}]

set_property PACKAGE_PIN N16 [get_ports {key[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {key[1]}]

set_property PACKAGE_PIN T17 [get_ports {key[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {key[2]}]

set_property PACKAGE_PIN R17 [get_ports {key[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {key[3]}]

set_property PACKAGE_PIN W19 [get_ports {ext_key[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_key[0]}]
set_property PULLUP true [get_ports {ext_key[0]}]

set_property PACKAGE_PIN W18 [get_ports {ext_key[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_key[1]}]
set_property PULLUP true [get_ports {ext_key[1]}]

set_property PACKAGE_PIN R14 [get_ports {ext_key[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_key[2]}]
set_property PULLUP true [get_ports {ext_key[2]}]

set_property PACKAGE_PIN P14 [get_ports {ext_key[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_key[3]}]
set_property PULLUP true [get_ports {ext_key[3]}]

set_property PACKAGE_PIN Y17 [get_ports {ext_key[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_key[4]}]
set_property PULLUP true [get_ports {ext_key[4]}]

set_property PACKAGE_PIN V16 [get_ports {hdmi_oen}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_oen}]

set_property PACKAGE_PIN N18 [get_ports {TMDS_clk_p}]
set_property IOSTANDARD TMDS_33 [get_ports {TMDS_clk_p}]
set_property IOSTANDARD TMDS_33 [get_ports {TMDS_clk_n}]

set_property PACKAGE_PIN V20 [get_ports {TMDS_data_p[0]}]
set_property IOSTANDARD TMDS_33 [get_ports {TMDS_data_p[0]}]
set_property IOSTANDARD TMDS_33 [get_ports {TMDS_data_n[0]}]

set_property PACKAGE_PIN T20 [get_ports {TMDS_data_p[1]}]
set_property IOSTANDARD TMDS_33 [get_ports {TMDS_data_p[1]}]
set_property IOSTANDARD TMDS_33 [get_ports {TMDS_data_n[1]}]

set_property PACKAGE_PIN N20 [get_ports {TMDS_data_p[2]}]
set_property IOSTANDARD TMDS_33 [get_ports {TMDS_data_p[2]}]
set_property IOSTANDARD TMDS_33 [get_ports {TMDS_data_n[2]}]
