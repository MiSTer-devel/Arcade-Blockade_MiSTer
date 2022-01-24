
module blockade (
	input clk,
	input reset,

	output ce_pix,
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

// U31 - 74160 decade counter
wire u31_qa;
wire u31_qb;
wire u31_qc;
wire u31_qd;
ttl_74160 u31
(
	.Clk(clk),
	.Clear_bar(1'b1),
	.Load_bar(1'b1),
	.ENP(1'b1),
	.ENT(1'b1),
	.D(),
	.RCO(),
	.QA(u31_qa),
	.QB(u31_qb),
	.QC(u31_qc),
	.QD(u31_qd)
);

// Output pixel clock
assign ce_pix = u31_qa;
reg ce_pix_last;
always @(posedge clk) begin
	ce_pix_last <= ce_pix;
end

// U17 - 7442 BCD to decimal decoder
wire [9:0] u17_q;
ttl_7442 u17
(
	.a(u31_qa),
	.b(u31_qb),
	.c(u31_qc),
	.d(u31_qd),
	.o(u17_q)
);

// U18 2x NAND
/* verilator lint_off UNOPTFLAT */
wire u18_1 = ~(u17_q[0] && u18_2);
wire u18_2 = ~(u17_q[2] && u18_1);
/* verilator lint_on UNOPTFLAT */

// U8 2x NAND
/* verilator lint_off UNOPTFLAT */
wire u8_1 = ~(u17_q[3] && u8_2);
wire u8_2 = ~(u17_q[9] && u8_1);
/* verilator lint_on UNOPTFLAT */

// U45 AND
wire u45 = u18_1 && SYNC;

// U21_2
// wire u56_reset = (u58_count == 9'd261);
// always @(posedge clk) begin

// end
// reg u56_2_n = 
// reg READY = ~(a12_n_a15 && u56_2_n);

// U9 D flip-flop
reg u9_q;
always @(posedge clk) begin
	if(reset) 
	begin
		u9_q <= 1'b0;
	end
	else
	begin
		if(!VBLANK_N && VBLANK_N_last)
		begin
			u9_q <= 1'b1;
			$display("READY LATCH");
		end 
		
		if(VBLANK_N && !VBLANK_N_last)
		begin
			u9_q <= 1'b0;
			$display("READY UNLATCH");
		end 
	end
end

// Address decode
wire rom_cs = (!ADDR[15] && !ADDR[11] && !ADDR[10]);
wire ram_cs = ADDR[15] && !ADDR[12];
wire sram_cs = ADDR[15] && ADDR[12];

//wire ram_we = ram_cs && !ram_WR_n;
wire ram_we = ram_cs && !WR_N;
wire sram_we = sram_cs && !WR_N;

wire [7:0] inp_data_out =	(ADDR[1:0] == 2'd0) ? 8'hFF : // IN0
							(ADDR[1:0] == 2'd1) ? 8'hFF : // IN1
							(ADDR[1:0] == 2'd2) ? 8'hFF : // IN2
							8'h00;

// CPU
wire [7:0] cpu_data_in = INP ? inp_data_out : 
						 rom_cs ? rom_data_out :
						 ram_cs ? ram_data_out : 
						 sram_cs ? sram_data_out : 
						 8'h00;

reg [7:0] cpu_data_out;

wire PHI_1 = ~u18_2;
wire PHI_2 = ~u8_2;
wire [15:0] ADDR;
wire [7:0] DATA;
wire DBIN;
wire WR_N;
wire SYNC /*verilator public_flat*/;
wire HLD_A;
vm80a cpu
(
	.pin_clk(clk),
	.pin_f1(PHI_1),
	.pin_f2(PHI_2),
	.pin_reset(reset),
	.pin_a(ADDR),
	.pin_d(DATA),
	.pin_hold(1'b0),
	.pin_hlda(),
	.pin_ready(u9_q),
	.pin_wait(),
	.pin_int(1'b0),
	.pin_inte(),
	.pin_sync(SYNC),
	.pin_dbin(DBIN),
	.pin_wr_n(WR_N)
);
assign DATA = DBIN ? cpu_data_in: 8'hZZ;
always @(posedge clk) begin
	if(!WR_N)
	begin
		cpu_data_out <= DATA;
	end
end

// U52 - Dual binary counters
reg [8:0] u52_count;
reg u53_rco_last;
reg s_64H_last;
wire s_1H = u52_count[0];
wire s_2H = u52_count[1];
wire s_4H = u52_count[2];
wire s_8H = u52_count[3];
wire s_16H = u52_count[4];
wire s_32H = u52_count[5];
wire s_64H = u52_count[6];
wire s_128H = u52_count[7];
wire s_256H = u52_count[8];
localparam HBLANK_START = 9'd255;
localparam HSYNC_START = 9'd272;
localparam HSYNC_END = 9'd300;
wire HRESET_N = ~(u52_count == 9'd329);
reg HBLANK_N;
reg HSYNC_N;

always @(posedge clk)
begin
	// U52 1
	if(ce_pix && !ce_pix_last)
	begin
		if (!HRESET_N) 
		begin
			u52_count <= 9'b0000;
			HBLANK_N <= 1'b1;
		end
		else
		begin
			u52_count <= u52_count + 8'b1;
			if(u52_count == HBLANK_START) HBLANK_N <= 1'b0;
			if(u52_count == HSYNC_START) HSYNC_N <= 1'b0;
			if(u52_count == HSYNC_END) HSYNC_N <= 1'b1;
		end
	end
end

// U63 - AND + NOT?!
wire u63 = ~(s_16H && s_256H);

// U58 - Dual binary counters
reg [8:0] u58_count;
reg HSYNC_N_last;
reg VRESET_N;
reg VSYNC_N;
wire s_1V = u58_count[0];
wire s_2V = u58_count[1];
wire s_4V = u58_count[2];
wire s_8V = u58_count[3];
wire s_16V = u58_count[4];
wire s_32V = u58_count[5];
wire s_64V = u58_count[6];
wire s_128V = u58_count[7];
wire s_256V = u58_count[8];

reg VBLANK_N_last;
wire VBLANK_N = u58_count < 9'd224;

always @(posedge clk)
begin
	VBLANK_N_last <= VBLANK_N;
	// U58 1
	HSYNC_N_last <= HSYNC_N;
	if(HSYNC_N && !HSYNC_N_last)
	begin
		if (!VRESET_N) 
		begin
			u58_count <= 9'b0000;
		end
		else
		begin
			u58_count <= u58_count + 9'b1;
		end
		//$display("u58_count=%d  VSYNC_N=%b  VBLANK_N=%b  VRESET_N=%b", u58_count, VSYNC_N, VBLANK_N, VRESET_N);
		VSYNC_N <= ~(u58_count > 9'd254);
		VRESET_N <= ~(u58_count == 9'd261);
	end
end

// U51 latch
reg l_D7;
reg l_D6;
reg l_D4;
reg l_D3;
always @(posedge clk) begin
	if(u45)
	begin
		//$display("Latching data to U51: D=%b D7=%b D6=%b D4=%b D3=%b", DATA, l_D7, l_D6, l_D4, l_D3);
		l_D7 <= DATA[7];
		l_D6 <= DATA[6];
		l_D4 <= DATA[4];
		l_D3 <= DATA[3];
	end
end

// U45_1
reg OUTP = l_D4 && ~WR_N;
// U44_1
reg MEMW = (l_D3 && ~WR_N);
// U45_2
reg INP = (l_D6 && DBIN);
// U44_2
reg MEMR = (l_D7 && DBIN);

// U21
wire a12_n_a15 = ADDR[15] && ~ADDR[12];
reg ram_WR_n = ~(MEMW && a12_n_a15);

assign hsync = ~HSYNC_N;
assign hblank = ~HBLANK_N;
assign vblank = ~VBLANK_N;
assign vsync = ~VSYNC_N;

assign g = prom_data_out[{ s_4H, s_2H, s_1H }];

always @(posedge clk) begin
	if(!reset)
	begin
		if(!rom_cs)
		begin
			$display("ADDR=%x DATA=%b rom=%b ram=%b sram=%b MEMW=%b WR_N=%b DBIN=%b RAMA=%x VBL=%b", ADDR, DATA, rom_cs, ram_cs, sram_cs, MEMW, WR_N, DBIN, ram_addr, vblank);
		end
		// if(!WR_N)
		// begin
		// 	$display("CPUWR > ADDR=%x DATA=%x a12_n_a15=%b ram_WR_n=%b MEMW=%b ram_cs=%b", ADDR, DATA, a12_n_a15, ram_WR_n, MEMW, ram_cs);
		// 	$display("ADDR=%x DATA=%x rom=%b ram=%b sram=%b", ADDR, cpu_data_in, rom_cs, ram_cs, sram_cs);
		// end
		//  if(DBIN)
		//  begin

		//  end
	end
end

// U1 - 7442 BCD to decimal decoder
wire [9:0] u1_q;
ttl_7442 u1
(
	.a(ADDR[10]),
	.b(ADDR[11]),
	.c(ADDR[15]),
	.d(~MEMR),
	.o(u1_q)
);
wire CS0_N = u1_q[0];


// MEMORY
// ------
wire [3:0] rom_data_out_lsb;
wire [3:0] rom_data_out_msb;
wire [7:0] rom_data_out = { rom_data_out_msb, rom_data_out_lsb } ;

// Program ROM - 0x0000-0x2000
dpram #(10,4, "316-0003.u3.hex") rom_lsb
(
	.clock_a(clk),
	.address_a(ADDR[9:0]),
	.wren_a(1'b0),
	.data_a(),
	.q_a(rom_data_out_lsb),

	.clock_b(clk),
	.address_b(),
	.wren_b(),
	.data_b(),
	.q_b()
);
dpram #(10,4, "316-0004.u2.hex") rom_msb
(
	.clock_a(clk),
	.address_a(ADDR[9:0]),
	.wren_a(1'b0),
	.data_a(),
	.q_a(rom_data_out_msb),

	.clock_b(clk),
	.address_b(),
	.wren_b(),
	.data_b(),
	.q_b()
);

// RAM
wire [7:0]	ram_data_out;
wire [7:0]	ram_data_in = cpu_data_out;
wire [9:0]  vram_read_addr = { s_128V, s_64V, s_32V, s_16V, s_8V, s_128H, s_64H, s_32H, s_16H, s_8H };
wire [9:0]  ram_addr = vblank ? ADDR[9:0] : vram_read_addr;

dpram #(10,8) ram
(
	.clock_a(clk),
	.address_a(ram_addr),
	.wren_a(ram_we),
	.data_a(ram_data_in),
	.q_a(ram_data_out),

	.clock_b(clk),
	.address_b(),
	.wren_b(),
	.data_b(),
	.q_b()
);

// 2111 static RAM
wire [7:0]	sram_data_out;
wire [7:0]	sram_data_in = cpu_data_out;
wire [7:0]  sram_addr = ADDR[7:0];
dpram #(8,8) sram
(
	.clock_a(clk),
	.address_a(sram_addr),
	.wren_a(sram_we),
	.data_a(sram_data_in),
	.q_a(sram_data_out),

	.clock_b(clk),
	.address_b(),
	.wren_b(),
	.data_b(),
	.q_b()
);

// PROMS
wire [3:0] prom_data_out_lsb;
wire [3:0] prom_data_out_msb;
wire [7:0] prom_data_out = { prom_data_out_msb, prom_data_out_lsb } ;
/* verilator lint_off SELRANGE */
wire [7:0] prom_addr = { ram_data_out[0:4], s_4V, s_2V, s_1V };
/* verilator lint_on SELRANGE */
dpram #(8,4, "316-0001.u43.hex") prom_lsb
(
	.clock_a(clk),
	.address_a(prom_addr),
	.wren_a(1'b0),
	.data_a(),
	.q_a(prom_data_out_lsb),

	.clock_b(clk),
	.address_b(),
	.wren_b(),
	.data_b(),
	.q_b()
);
dpram #(8,4, "316-0002.u29.hex") prom_msb
(
	.clock_a(clk),
	.address_a(prom_addr),
	.wren_a(1'b0),
	.data_a(),
	.q_a(prom_data_out_msb),

	.clock_b(clk),
	.address_b(),
	.wren_b(),
	.data_b(),
	.q_b()
);

endmodule
