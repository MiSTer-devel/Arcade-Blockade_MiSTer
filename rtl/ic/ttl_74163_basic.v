// 74163 Binary counter module

module ttl_74163_basic(
	input wire a, b, c, d, _load, _clear, clk, ce,
	output wire qa, qb, qc, qd,
	output wire rco 
);

	reg[3:0] q;
	assign qa = q[0];
	assign qb = q[1];
	assign qc = q[2];
	assign qd = q[3];

	always @(posedge clk)
	begin
		if(ce)
		begin
			// $display("ttl_74163_basic - count=%x q=%x rco=%b", {qd, qc, qb, qa}, q, rco);

			//start the count on the rising clock edge
			if (!_clear)
			begin
				//if clear is low, set the count outputs to 0
				q <= 4'b0;
			end
			if (_clear &&!_load)
			begin 
				//if load is set low, set count output to match the input
				q <= {d, c, b, a};
			end
			if (_clear && _load)
			begin
				//if clear, load are set high, increment the count by one
				q <= q + 4'b1;
			end
		end
	end

	assign rco = q == 4'd15; // if the count has reached 15 set rco high

endmodule