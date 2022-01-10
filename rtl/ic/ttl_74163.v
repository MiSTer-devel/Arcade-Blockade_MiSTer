// 74163 Binary counter module

module ttl_74163(
	input wire a, b, c, d, enp, ent, _load, _clear, clk, ce,
	output reg qa, qb, qc, qd,
	output wire rco 
);

	always @(posedge clk)
	begin
		if(ce)
		begin
			$display("ttl74163 - count=%x rco=%b", {qd, qc, qb, qa}, rco);

			//start the count on the rising clock edge
			if (!_clear)
			begin
				{qd, qc, qb, qa} <=4'b0; //if clear is low, set the count outputs to 0
			end
			if (_clear &&!_load)
			begin //if load is set low, set count output to match the input
				{qd, qc, qb, qa} <= {d, c, b, a};
			end
			if (_clear && _load && enp && ent)
			begin//if clear, load, ent and enp are set high, increment the count by one
				{qd, qc, qb, qa} <= {qd, qc, qb, qa} + 4'b1;
			end
		end
	end

	assign rco = ent ? qa && qb && qc && qd : 1'b0; // if the count has reached 15 and ent set high set rco high

endmodule