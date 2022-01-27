
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

	input [7:0] in0,
	input [7:0] in1,
	input [7:0] in2,

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

assign ce_pix = VIDEO_CLOCK;
reg VIDEO_CLOCK;
reg VIDEO_CLOCK_last;

reg [3:0] ce_count;

//reg ce_pix_last;
always @(posedge clk) begin
	//ce_pix_last <= ce_pix;

	if(ce_count == 4'd9)
		ce_count <= 4'b0;
	else
		ce_count <= ce_count + 1'b1;

	VIDEO_CLOCK <= ce_count[1:0] == 2'b00;

	VIDEO_CLOCK_last <= VIDEO_CLOCK;
	//$display("%d - d: %b, c: %b, b: %b, a: %b  p1: %b p2: %b", {u31_qd, u31_qc, u31_qb, u31_qa}, u31_qd, u31_qc, u31_qb, u31_qa, PHI_1, PHI_2);
	//$display("CE_COUNT: %b  p1: %b p2: %b vc: %b  u18_1: %b u18_2: %b u8_1: %b u8_2: %b", ce_count, PHI_1, PHI_2, VIDEO_CLOCK, u18_1, u18_2, u8_1, u8_2);
	// $display("CE_COUNT: %b  p1: %b p2: %b vc: %b  u8_1: %b u8_2: %b", ce_count, PHI_1, PHI_2, VIDEO_CLOCK, u8_1, u8_2);
end
wire PHI_1 = ce_count[3:1] == 3'b000;
wire PHI_2 = ce_count >= 4'd3 && ce_count <= 4'd8;

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
// wire u18_1 = ~(u17_q[0] && u18_2);
// wire u18_2 = ~(u17_q[2] && u18_1);
/* verilator lint_on UNOPTFLAT */

// U8 2x NAND
/* verilator lint_off UNOPTFLAT */
// wire u8_1 = ~(u17_q[3] && u8_2);
// wire u8_2 = ~(u17_q[9] && u8_1);
/* verilator lint_on UNOPTFLAT */

// U45 AND
//wire u45 = u18_1 && SYNC;
wire u45 = PHI_1 && SYNC;

// U9 D flip-flop
// wire u9_d = (~VBLANK_N || !a12_n_a15);
wire u9_d = (~VBLANK_N);
reg u9_q;
//reg u56_q_n;
//wire READY = ~(u56_q_n && a12_n_a15);
//reg u8_1_last;
reg VRESET_N_last;
reg PHI_2_last;

reg a12_n_a15_last;

always @(posedge clk) begin

	if(reset)
	begin
	 	u9_q <= 1'b1;
//		u56_q_n <= 1'b0;
	end
	else
	begin
		PHI_2_last <= PHI_2;
		if(PHI_2 && !PHI_2_last)
		begin
			u9_q <= u9_d;
		end
		// a12_n_a15_last <= a12_n_a15;
		// if(a12_n_a15 != a12_n_a15_last)
		// begin
		// 	$display("a12_n_a15: %b  vcnt=%d", a12_n_a15, vcnt);
		// end

		// if(a12_n_a15 && VBLANK_N)
		// begin
		// 	$display("a12_n_a15 IN VBLANK  u9_q=%b", u9_q);
		// end

	 	// if(!VBLANK_N && VBLANK_N_last)
		// begin
		// 	u56_q_n <= 1'b0;
	 	// 	$display("READY going low: vcnt=%d", vcnt);
		// end

		// VRESET_N_last <= VRESET_N;
		// if(!VRESET_N && VRESET_N_last)
		// begin
		// 	u56_q_n <= 1'b1;
		// 	$display("READY going high: vcnt=%d", vcnt);
		// end

		// u8_1_last <= u8_1;
		// if(u8_1 && !u8_1_last)
		// begin
		// 	u9_q <= !VBLANK_N;
		// 	// u9_q <= READY;
		// end

		// if(u21_2)
		// begin
		// 	u9_q <= 1'b1;
		// end
		// if(VIDEO_CLOCK && !VIDEO_CLOCK_last)
		// begin
		// 	if(!VBLANK_N && VBLANK_N_last)
		// 	begin
		// 		u9_q <= 1'b1;
		// 		$display("Entering VBLANK: hcnt=%d  vcnt=%d", hcnt, vcnt);
		// 	end

		// 	if(VBLANK_N && !VBLANK_N_last)
		// 	begin
		// 		u9_q <= 1'b0;
		// 		$display("Leaving VBLANK: hcnt=%d  vcnt=%d", hcnt, vcnt);
		// 	end
		// end
		// if(!VBLANK_N)
		// begin
		// 	//$display("hcnt=%d  vcnt=%d   hblank=%b a12_n_a15=%b u21_2=%b u9_q=%b", hcnt, vcnt, hblank, a12_n_a15, u21_2, u9_q);
		// end
	end
end

// Address decode
wire rom_cs = (!ADDR[15] && !ADDR[11] && !ADDR[10]);
wire ram_cs = ADDR[15] && !ADDR[12];
wire sram_cs = ADDR[15] && ADDR[12];

//wire ram_we = ram_cs && !ram_WR_n;
wire ram_we = ram_cs && !WR_N;
wire sram_we = sram_cs && !WR_N;

wire [7:0] inp_data_out =	(ADDR[1:0] == 2'd0) ? in0 : // IN0
							(ADDR[1:0] == 2'd1) ? in1 : // IN1
							(ADDR[1:0] == 2'd2) ? in2 : // IN2
							8'h00;

// CPU
wire [7:0] cpu_data_in = INP ? inp_data_out :
						 rom_cs ? rom_data_out :
						 ram_cs ? ram_data_out :
						 sram_cs ? sram_data_out :
						 8'h00;

reg [7:0] cpu_data_out;

// wire PHI_1 = ~u18_2;
// wire PHI_2 = ~u8_2;
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


localparam HBLANK_START = 9'd255;
localparam HSYNC_START = 9'd272;
localparam HSYNC_END = 9'd300;
localparam HRESET_LINE = 9'd329;
localparam VBLANK_START = 9'd224;
localparam VSYNC_START = 9'd254;
localparam VRESET_LINE = 9'd261;

//wire [8:0] hcnt = (u52_count == HSYNC_END) ? 9'b0 : u52_count + 9'd1;
wire [8:0] hcnt = (u52_count == HSYNC_END - 9'b1) ? 9'b0 : u52_count;

wire s_1H = hcnt[0];
wire s_2H = hcnt[1];
wire s_4H = hcnt[2];
wire s_8H = hcnt[3];
wire s_16H = hcnt[4];
wire s_32H = hcnt[5];
wire s_64H = hcnt[6];
wire s_128H = hcnt[7];
wire s_256H = hcnt[8];
wire HRESET_N = ~(u52_count == HRESET_LINE);
reg HBLANK_N = 1'b1;
reg HSYNC_N_last = 1'b1;
reg HSYNC_N = 1'b1;

always @(posedge clk)
begin
	// U52 1
	if(VIDEO_CLOCK && !VIDEO_CLOCK_last)
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

wire [8:0] vcnt = u58_count;// - 9'd2;

wire s_1V = vcnt[0];
wire s_2V = vcnt[1];
wire s_4V = vcnt[2];
wire s_8V = vcnt[3];
wire s_16V = vcnt[4];
wire s_32V = vcnt[5];
wire s_64V = vcnt[6];
wire s_128V = vcnt[7];
wire s_256V = vcnt[8];

reg VBLANK_N_last = 1'b1;
reg VBLANK_N = 1'b1;
reg VSYNC_N = 1'b1;
wire VRESET_N = ~(u58_count == VRESET_LINE);

always @(posedge clk)
begin
	if(VIDEO_CLOCK && !VIDEO_CLOCK_last)
	begin
		// U58 1
		VBLANK_N_last <= VBLANK_N;
		HSYNC_N_last <= HSYNC_N;
		if(HSYNC_N && !HSYNC_N_last)
		begin
			//VRESET_N <= ~(u58_count == 9'd261);
			if (!VRESET_N)
			begin
				u58_count <= 9'b0;
			end
			else
			begin
				u58_count <= u58_count + 9'b1;
			end
			VBLANK_N <= ~(u58_count >= VBLANK_START);
			VSYNC_N <= ~(u58_count >= VSYNC_START );
		end
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
		l_D7 <= DATA[7];
		l_D6 <= DATA[6];
		l_D4 <= DATA[4];
		l_D3 <= DATA[3];
	end
end

// U45_1
wire OUTP = l_D4 && ~WR_N;
// U44_1
wire MEMW = (l_D3 && ~WR_N);
// U45_2
wire INP = (l_D6 && DBIN);
// U44_2
wire MEMR = (l_D7 && DBIN);

// U21
wire a12_n_a15 = ADDR[15] && ~ADDR[12];
wire ram_WR_n = ~(MEMW && a12_n_a15);

assign hsync = ~HSYNC_N;
assign hblank = ~HBLANK_N;
assign vblank = ~VBLANK_N;
assign vsync = ~VSYNC_N;

wire [2:0] prom_col = 3'b111-{ s_4H, s_2H, s_1H };
assign r = s_8H;
assign g = prom_data_out[prom_col];
//assign g = s_1V;
assign b = s_8V;

// always @(posedge clk)
// begin
// 	if(VBLANK_N)
// 	begin
// 		g <= prom_data_out[prom_col];
// 	end
// end

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
wire [7:0] prom_addr = { ram_data_out[4:0], s_4V, s_2V, s_1V };
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
