module cpu_z80(
	input CLK,
	input nRESET,
	input wire [7:0] DATA_IN,
	output wire [7:0] DATA_OUT,
	output [15:0] ADDRESS,
	output reg nIORQ, nMREQ,
	output reg nRD, nWR,
	input nINT, nNMI
);
	reg [7:0] DATA_IN_REG;
	wire [6:0] T_STATE;
	wire [6:0] M_CYCLE;
	wire nINTCYCLE;
	wire NO_READ;
	wire WRITE;
	wire IORQ;
	
	tv80_core #(.MODE(2)) TV80( , IORQ, NO_READ, WRITE, , , , ADDRESS, DATA_OUT, M_CYCLE,
							T_STATE, nINTCYCLE, , , nRESET, CLK, 1'b1, 1'b1,
							nINT, nNMI, 1'b1, DATA_IN, DATA_IN_REG);
	
	always @(posedge CLK)
	begin
		if (!nRESET)
		begin
			nRD <= #1 1'b1;
			nWR <= #1 1'b1;
			nIORQ <= #1 1'b1;
			nMREQ <= #1 1'b1;
			DATA_IN_REG <= #1 8'b00000000;
		end
		else
		begin
			nRD <= #1 1'b1;
			nWR <= #1 1'b1;
			nIORQ <= #1 1'b1;
			nMREQ <= #1 1'b1;
			if (M_CYCLE[0])
			begin
				if (T_STATE[1])
				begin
					nRD <= #1 ~nINTCYCLE;
					nMREQ <= #1 ~nINTCYCLE;
					nIORQ <= #1 nINTCYCLE;
				end
			end
			else
			begin
				if ((T_STATE[1]) && NO_READ == 1'b0 && WRITE == 1'b0)
				begin
					nRD <= #1 1'b0;
					nIORQ <= #1 ~IORQ;
					nMREQ <= #1 IORQ;
				end
				if ((T_STATE[1]) && WRITE == 1'b1)
				begin
					nWR <= #1 1'b0;
					nIORQ <= #1 ~IORQ;
					nMREQ <= #1 IORQ;
				end
			end
			if (T_STATE[2]) DATA_IN_REG <= #1 DATA_IN;
		end
	end
	
endmodule
