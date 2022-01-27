module spram # (
	parameter data_width = 8,
	parameter address_width = 8
)
(
	input clock,
	input [(address_width-1):0] address,
	input [(data_width-1):0]  data,
	output reg [(data_width-1):0] q,
	input we
);

localparam ramLength = (2**address_width);

reg [(data_width-1):0] ram [ramLength-1:0];

`ifdef SIMULATION
	integer    j;
	initial
	begin
		for (j = 0; j < ramLength; j = j + 1)
		begin
			ram[j] = 0;
		end
	end
`endif

	always @(posedge clock)
	begin
		if (we)
		begin
			ram[address] <= data;
			q <= data;
		end
		else
		begin
			q <= ram[address];
		end
	end

endmodule
