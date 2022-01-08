module dpram #(
	parameter data_width=8,
	parameter address_width=8
)(
	input								clock_a,
	input								clock_b,

	input			[address_width-1:0]	address_a,
	input			[data_width-1:0]	data_a,
	input								enable_a,
	input								wren_a,
	output reg	[data_width-1:0]	q_a,

	input			[address_width-1:0]	address_b,
	input			[data_width-1:0]	data_b,
	input								enable_b,
	input								wren_b,
	output reg	[data_width-1:0]	q_b
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

always @(posedge clock_a) begin
	if (enable_a) begin
		if (wren_a) begin 
			ram[address_a] <= data_a;
			q_a <= data_a;
		end
		else
		begin
			q_a <= ram[address_a];
		end
	end
end

always @(posedge clock_b) begin
	if (enable_b) begin
		if (wren_b) begin 
			ram[address_b] <= data_b;
			q_b <= data_b;
		end
		else
		begin
			q_b <= ram[address_b];
		end
	end
end

endmodule