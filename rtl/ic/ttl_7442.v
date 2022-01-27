`timescale 1 ps / 1 ps

// 7442 - BCD to decimal decoder
// -------------------------------
module ttl_7442
(
	input wire  a, b, c, d,
	output wire [9:0] o
);

assign o[0] = ~(~a && ~b && ~c && ~d);
assign o[1] = ~(a && ~b && ~c && ~d);
assign o[2] = ~(~a && b && ~c && ~d);
assign o[3] = ~(a && b && ~c && ~d);
assign o[4] = ~(~a && ~b && c && ~d);
assign o[5] = ~(a && ~b && c && ~d);
assign o[6] = ~(~a && b && c && ~d);
assign o[7] = ~(a && b && c && ~d);
assign o[8] = ~(~a && ~b && ~c && d);
assign o[9] = ~(a && ~b && ~c && d);

endmodule