
module blockade (
	input clk,
	input reset,
	output r,
	output g,
	output b,
	output vsync,
	output hsync,
	output vblank,
	output hblank,

	input [7:0] buttons,
	input [13:0] dn_addr,
	input 		 dn_wr,
	input [7:0]  dn_data
);



endmodule
