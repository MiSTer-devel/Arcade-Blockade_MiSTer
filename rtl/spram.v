`timescale 1 ps / 1 ps

/*============================================================================
	Generic single-port RAM module

	Author: Jim Gregory - https://github.com/JimmyStones/
	Version: 1.0
	Date: 2022-01-28

	This program is free software; you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the Free
	Software Foundation; either version 3 of the License, or (at your option)
	any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program. If not, see <http://www.gnu.org/licenses/>.
===========================================================================*/

module spram # (
	parameter data_width = 8,
	parameter address_width = 8,
	parameter init_file= ""
)
(
	input 							clk,
	input [(address_width-1):0]		address,
	input [(data_width-1):0]		data,
	output reg [(data_width-1):0]	q,
	input							wren
);

	localparam ramLength = (2**address_width);

	reg [(data_width-1):0] mem [ramLength-1:0];

	initial begin
		if (init_file>0) $readmemh(init_file, mem);
	end

`ifdef SIMULATION
	integer    j;
	initial
	begin
		for (j = 0; j < ramLength; j = j + 1)
		begin
			mem[j] = 0;
		end
	end
`endif

	always @(posedge clk)
	begin
		if (wren)
		begin
			mem[address] <= data;
			q <= data;
		end
		else
		begin
			q <= mem[address];
		end
	end

endmodule