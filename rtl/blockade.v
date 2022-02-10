`timescale 1 ps / 1 ps

module blockade (
	input clk,
	input reset,
	input [1:0] game_mode,

	output ce_pix,
	output r,
	output g,
	output b,
	output vsync,
	output hsync,
	output vblank,
	output hblank,

	output signed [15:0] audio_l,
	output signed [15:0] audio_r,

	input [7:0] in_1,
	input [7:0] in_2,
	input [7:0] in_4,
	input coin,

	input [13:0] dn_addr,
	input 		 dn_wr,
	input [7:0]  dn_data
);

// Game mode constants
localparam GAME_BLOCKADE = 0;
localparam GAME_COMOTION = 1;

// CPU reset can come from reset signal or coin start signal
wire RESET = reset || (game_mode == GAME_COMOTION && coin_start > 6'b0);

// Generate video and CPU enables
// - Replaces U31, U17, U8, U18 section of circuit
reg [3:0] phi_count;
reg [1:0] vid_count;
always @(posedge clk) begin
	// Phi counter is 0-9, generates PHI_1 and PHI_2 enable signals for CPU
	phi_count <= (phi_count == 4'd9) ? 4'b0 : phi_count + 1'b1;

	// Video counter is 0-3, generates ce_vid and ce_pix signals for video circuit
	vid_count <= vid_count + 2'b1;
end
wire ce_vid = (vid_count == 2'd0);
assign ce_pix = (vid_count == 2'd3);
wire PHI_1 = phi_count[3:1] == 3'b000;
wire PHI_2 = phi_count >= 4'd3 && phi_count <= 4'd8;

// U21 - Video RAM address select
wire a12_n_a15 = ADDR[15] && ~ADDR[12];

// U9 D flip-flop - Disables CPU using READY signal when attempting to write VRAM during vblank
reg u9_q;
reg PHI_2_last;
always @(posedge clk) begin
	if(reset)
	begin
	 	u9_q <= 1'b1;
	end
	else
	begin
		PHI_2_last <= PHI_2;
		if(PHI_2 && !PHI_2_last)
		begin
			if(VBLANK_N && a12_n_a15)
				u9_q <= 1'b0;
			else
				u9_q <= 1'b1;
		end
	end
end

// Address decode
wire rom1_cs = (!ADDR[15] && !ADDR[11] && !ADDR[10] && MEMR);
wire rom2_cs = (!ADDR[15] && !ADDR[11] && ADDR[10] && MEMR);

// Input data selector
reg [7:0] IN_1;
reg [7:0] IN_2;
reg [7:0] IN_4;
always @(posedge clk) begin
	IN_1 <= in_1;
	IN_2 <= in_2;
	IN_4 <= in_4;
	case(game_mode)
	GAME_BLOCKADE: IN_1[7] <= coin_latch;
	GAME_COMOTION: IN_1[7] <= coin_latch;
	endcase

	if(INP && ADDR[0])
	begin
		$display("INP: IN_1=%b IN_2=%b IN_4=%b", ADDR[0], ADDR[1], ADDR[2]);
	end
end
wire [7:0] inp_data_out =	ADDR[0] ? IN_1 : // IN_1
							ADDR[1] ? IN_2 : // IN_2
							ADDR[2] ? IN_4 : // IN_4 - Not connected in Blockade
							8'h00;

// CPU data selector
wire [7:0] cpu_data_in = INP ? inp_data_out :
						 rom1_cs ? rom1_data_out :
						 rom2_cs ? rom2_data_out :
						 vram_cs ? vram_data_out_cpu :
						 sram_cs ? sram_data_out :
						 8'h00;

wire [15:0] ADDR;
wire [7:0] DATA;
wire DBIN;
wire WR_N;
wire SYNC /*verilator public_flat*/;
vm80a cpu
(
	.pin_clk(clk),
	.pin_f1(PHI_1),
	.pin_f2(PHI_2),
	.pin_reset(RESET),
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
reg [7:0] cpu_data_out;
always @(posedge clk) begin
	if(!WR_N)
	begin
		cpu_data_out <= DATA;
	end
end


// Video timing circuit

// - Constants
localparam HBLANK_START = 9'd255;
localparam HSYNC_START = 9'd272;
localparam HSYNC_END = 9'd300;
localparam HRESET_LINE = 9'd329;
localparam VSYNC_START = 9'd256;
localparam VSYNC_END = 9'd258;
localparam VBLANK_START = 9'd224;
localparam VBLANK_END = 9'd261;
localparam VRESET_LINE = 9'd261;

// Video counters
reg [8:0] hcnt;
reg [8:0] vcnt;

// Signals
reg HBLANK_N = 1'b1;
reg HSYNC_N = 1'b1;
reg HSYNC_N_last = 1'b1;
wire VBLANK_N = ~(vcnt >= VBLANK_START);
wire VSYNC_N = ~(vcnt >= VSYNC_START && vcnt <= VSYNC_END);

// Video read addresses
reg [2:0] prom_col;
wire [9:0] vram_read_addr = { vcnt[7:3], hcnt[7:3] }; // Generate VRAM read address from h/v counters { 128V, 64V, 32V, 16V, 8V, 128H, 64H, 32H, 16H, 8H };

always @(posedge clk)
begin
	if(ce_vid)
	begin
		HSYNC_N_last <= HSYNC_N; // Track last cycle hsync value

		if (hcnt == HRESET_LINE) // Horizontal reset point reached
		begin
			hcnt <= 9'b0000;   // Reset horizontal counter
			prom_col = 3'b111; // Set prom column to zero
			HBLANK_N <= 1'b1;  // Leave hblank
		end
		else
		begin
			hcnt <= hcnt + 9'b1;                       // Increment horizontal counter
			if(hcnt == HBLANK_START) HBLANK_N <= 1'b0; // Enter hblank when HBLANK_START reached
			if(hcnt == HSYNC_START) HSYNC_N <= 1'b0;   // Enter hsync when HSYNC_START reached
			if(hcnt == HSYNC_END) HSYNC_N <= 1'b1;     // Leave hsync when HSYNC_END reached
			prom_col = 3'b111 - { hcnt[2:0] + 3'b1};   // Set prom column to reverse of {H1,H2,H4} + 1
		end

		if(HSYNC_N && !HSYNC_N_last) // Leaving hysnc
		begin
			if (vcnt == VRESET_LINE) // Vertical reset point reached
			begin
				vcnt <= 9'b0;        // Reset vertical counter
			end
			else
			begin
				vcnt <= vcnt + 9'b1; // Increment vertical counter
			end
		end
	end
end

// Set video output signals
assign r = 1'b0;
assign g = prom_data_out[prom_col];
assign b = 1'b0;
assign hsync = ~HSYNC_N;
assign hblank = ~HBLANK_N;
assign vblank = ~VBLANK_N;
assign vsync = ~VSYNC_N;

// U45 AND - Enable for U51 latch
wire u45 = PHI_1 && SYNC;
// U51 latch
reg [3:0] u51_latch;
always @(posedge clk) begin
	if(u45) u51_latch <= { DATA[7:6], DATA[4:3] };
end

// U45_1
wire OUTP = u51_latch[1] && ~WR_N;
// U44_1
wire MEMW = (u51_latch[0] && ~WR_N);
// U45_2
wire INP = (u51_latch[2] && DBIN);
// U44_2
wire MEMR = (u51_latch[3] && DBIN);


// AUDIO
wire u68_out;
reg u68_out_last;
ttl_555 #(
	.HIGH_COUNTS(140),
	.LOW_COUNTS(51)
) u68 (
	.clk(clk),
	.reset(RESET),
	.out(u68_out)
);

reg [7:0] u6766_count;
reg u6766_out;
reg u6766_out_last;

always @(posedge clk)
begin
	u68_out_last <= u68_out;
	if(RESET)
	begin
		u6766_count <= 8'b0;
		u6766_out <= 1'b0;
		u6766_out_last <= 1'b0;
	end
	else
	begin
		u6766_out_last <= u6766_out;
		if(u68_out && !u68_out_last)
		begin
			if(u6766_out) // Load new inputs when counter overflows
			begin
				 // load parallel inputs
				//$display("Loading u6766: %b", { u66_p, u67_p });
				u6766_count <= u6766_p;
				u6766_out <= 1'b0;
			end
			else
			begin
				// count up
				u6766_count <= u6766_count + 8'b1;
				u6766_out <= (u6766_count == 8'd255);
			end
		end
	end
end

reg [7:0] u6766_p;
wire u60_1_ce = ~u6766_out;
reg u60_1_q;

// U60_1 flip flop
always @(posedge clk)
begin
	if(RESET)
		u60_1_q <= 1'b0;
	else
		if(u60_1_ce) u60_1_q <= 1'b1;
end

// U60_2 flip flop
reg u60_2_q;
always @(posedge clk)
begin
	if(~u60_1_q)
	begin
		u60_2_q <= 1'b0;
	end
	else
	begin
		if(u6766_out && !u6766_out_last)
		begin
			u60_2_q <= ~u60_2_q;
		end
	end
end
// SOUND SAMPLE

//assign audio_l = { 2'b0, u66_q, 10'b0 };
// assign audio_r = { 2'b0, u66_q, 10'b0 };
//wire signed [15:0] sound_out = (u6766_p == 8'hFF) ? 0 : (!u60_2_q ? -30000 : 30000);
wire signed [15:0] sound_out = (!u60_2_q ? -30000 : 30000);

// Low-pass filter the audio output
wire signed [15:0] sound_filtered;
blockade_lpf lpf
(
	.clk(clk),
	.reset(RESET),
	.in(sound_out),
	.out(sound_filtered)
);
// Invert the 
assign audio_l = 16'hFFFF - sound_filtered;
assign audio_r = sound_out;


///// OUTPUT CONTROL

wire u50_1 = ~(OUTP && ADDR[3]);
wire u50_2 = ~(OUTP && ADDR[2]);
/* verilator lint_off UNOPTFLAT */
wire u50_3 = ~(u50_1 && u50_4);
wire u50_4 = ~(u50_2 && u50_3);
/* verilator lint_on UNOPTFLAT */

// OUTP1 - Coin latch
wire OUTP1 = OUTP && ADDR[0];
wire OUTP2 = OUTP && ADDR[1];
reg u14_3qn;
reg coin_last;
reg [5:0] coin_start;
reg coin_latch;

always @(posedge clk) begin

	if(reset) coin_latch <= 1'b1;

	if(coin_start > 6'b0) coin_start <= coin_start - 6'b1;
	
	if(OUTP2) u6766_p <= DATA; // OUTP2 - Movement sound latch

	if(OUTP1)
	begin
		$display("OUTP1 %b", ~DATA[7]);
		u14_3qn <= ~DATA[7];
	end
	
	if(u14_3qn)
	begin
		//if(!coin_latch) $display("u14_3qn coin_latch = 0");
		//coin_latch <= 1'b1;
	end

	coin_last <= coin;
	if(coin && !coin_last)
	begin
		// $display("u14_3qn coin_latch = 1");
		$display("coin pulse started");
		coin_latch <= ~coin_latch;
		if(coin_latch) coin_start <= 6'b1;
	end

	// end
	// if(u50_4)
	// begin
	// 	$display("ENV");
	// end
end



// U2, U3 - Program ROM
// --------------------
// Each ROM is 1024 x 4 bytes.  Each pair is combined to 8 bytes:
// - U2 as most significant bits, U3 as least significant bits
// - U4 as most significant bits, U5 as least significant bits (not used by Blockade)

// Program ROM data outs
wire [3:0] rom1_data_out_lsb;
wire [3:0] rom1_data_out_msb;
wire [7:0] rom1_data_out = { rom1_data_out_msb, rom1_data_out_lsb };
wire [3:0] rom2_data_out_lsb;
wire [3:0] rom2_data_out_msb;
wire [7:0] rom2_data_out = { rom2_data_out_msb, rom2_data_out_lsb };

// Program ROM download write enables
wire rom1_msb_wr = dn_addr[12:10] == 3'b000 && dn_wr;
wire rom1_lsb_wr = dn_addr[12:10] == 3'b001 && dn_wr;
wire rom2_msb_wr = dn_addr[12:10] == 3'b010 && dn_wr;
wire rom2_lsb_wr = dn_addr[12:10] == 3'b011 && dn_wr;

// Program ROM - U2 - Most-significant bits
dpram #(10,4) rom1_msb
(
	.clock_a(clk),
	.address_a(ADDR[9:0]),
	.wren_a(1'b0),
	.data_a(),
	.q_a(rom1_data_out_msb),

	.clock_b(clk),
	.address_b(dn_addr[9:0]),
	.wren_b(rom1_msb_wr),
	.data_b(dn_data[3:0]),
	.q_b()
);
// Program ROM - U3 - Least-significant bits
dpram #(10,4) rom1_lsb
(
	.clock_a(clk),
	.address_a(ADDR[9:0]),
	.wren_a(1'b0),
	.data_a(),
	.q_a(rom1_data_out_lsb),

	.clock_b(clk),
	.address_b(dn_addr[9:0]),
	.wren_b(rom1_lsb_wr),
	.data_b(dn_data[3:0]),
	.q_b()
);
// Program ROM - U4 - Most-significant bits
dpram #(10,4) rom2_msb
(
	.clock_a(clk),
	.address_a(ADDR[9:0]),
	.wren_a(1'b0),
	.data_a(),
	.q_a(rom2_data_out_msb),

	.clock_b(clk),
	.address_b(dn_addr[9:0]),
	.wren_b(rom2_msb_wr),
	.data_b(dn_data[3:0]),
	.q_b()
);
// Program ROM - U5 - Least-significant bits
dpram #(10,4) rom2_lsb
(
	.clock_a(clk),
	.address_a(ADDR[9:0]),
	.wren_a(1'b0),
	.data_a(),
	.q_a(rom2_data_out_lsb),

	.clock_b(clk),
	.address_b(dn_addr[9:0]),
	.wren_b(rom2_lsb_wr),
	.data_b(dn_data[3:0]),
	.q_b()
);

// U38, U39, U40, U41, U42 - 2102 - Video RAM
// ------------------------------------------
// The original board used logic to allow CPU to write during VBLANK and the video system to read otherwise - I have used dual port RAM for simplicity
// In Blockade only 5-bits per address is used, but Comotion and others use 8-bits

// Data outs
wire [7:0] vram_data_out_cpu;	// Data read by CPU
wire [7:0] vram_data_out;		// Data read by video system

// Video RAM address select and write enable
wire vram_cs = ADDR[15] && !ADDR[12];
wire vram_we = vram_cs && !WR_N;

// U38, U39, U40, U41, U42 combined
dpram #(10,8) ram
(
	.clock_a(clk),
	.address_a(vram_read_addr),
	.wren_a(),
	.data_a(),
	.q_a(vram_data_out),

	.clock_b(clk),
	.address_b(ADDR[9:0]),
	.wren_b(vram_we),
	.data_b(cpu_data_out),
	.q_b(vram_data_out_cpu)
);


// U6, U7 - 2111 - Static RAM
// --------------------------

// Static RAM Data out
wire [7:0]	sram_data_out;

// Static RAM address select and write enable
wire sram_cs = ADDR[15] && ADDR[12];
wire sram_we = sram_cs && !WR_N;

// U6, U7 combined
spram #(8,8) sram
(
	.clk(clk),
	.address(ADDR[7:0]),
	.wren(sram_we),
	.data(cpu_data_out),
	.q(sram_data_out)
);

// U29, U43 - Graphics PROMs
// --------------------
// Each ROM is 256 x 4 bytes.  Combined to 8 bytes with U29 as most significant bits, U43 as least significant bits

// Graphics PROM data outs
wire [3:0] prom_data_out_lsb;
wire [3:0] prom_data_out_msb;
wire [7:0] prom_data_out = { prom_data_out_msb, prom_data_out_lsb } ;

// Graphics PROM read adress
wire [7:0] prom_addr = { vram_data_out[4:0], vcnt[2:0] };

// Graphics ROM download write enables
wire prom_msb_wr = dn_addr[12:8] == 5'b10000 && dn_wr;
wire prom_lsb_wr = dn_addr[12:8] == 5'b10001 && dn_wr;

// Graphics PROM - U29 - Most-significant bits
dpram #(8,4) prom_msb
(
	.clock_a(clk),
	.address_a(prom_addr),
	.wren_a(1'b0),
	.data_a(),
	.q_a(prom_data_out_msb),

	.clock_b(clk),
	.address_b(dn_addr[7:0]),
	.wren_b(prom_msb_wr),
	.data_b(dn_data[3:0]),
	.q_b()
);
// Graphics ROM - U43 - Least-significant bits
dpram #(8,4) prom_lsb
(
	.clock_a(clk),
	.address_a(prom_addr),
	.wren_a(1'b0),
	.data_a(),
	.q_a(prom_data_out_lsb),

	.clock_b(clk),
	.address_b(dn_addr[7:0]),
	.wren_b(prom_lsb_wr),
	.data_b(dn_data[3:0]),
	.q_b()
);


reg [15:0] sound_rom_addr;
wire [7:0] sound_rom_data_out;
// Sound samples
spram #(16,8, "sound.hex") sound_rom
(
	.clk(clk),
	.address(sound_rom_addr),
	.wren(1'b0),
	.data(),
	.q(sound_rom_data_out)
);

endmodule
