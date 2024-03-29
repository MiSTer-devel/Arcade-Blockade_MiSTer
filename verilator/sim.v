`timescale 1ns/1ns
// top end ff for verilator

module emu(

	input clk_sys /*verilator public_flat*/,
	input RESET /*verilator public_flat*/,
	input [12:0]  inputs/*verilator public_flat*/,

	output [7:0] VGA_R/*verilator public_flat*/,
	output [7:0] VGA_G/*verilator public_flat*/,
	output [7:0] VGA_B/*verilator public_flat*/,
	
	output VGA_HS,
	output VGA_VS,
	output VGA_HB,
	output VGA_VB,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,

	input        ioctl_download,
	input        ioctl_upload,
	input        ioctl_wr,
	input [24:0] ioctl_addr,
	input [7:0]  ioctl_dout,
	input [7:0]  ioctl_din,
	input [7:0]  ioctl_index,
	output  reg  ioctl_wait=1'b0

);

	wire ce_pix /*verilator public_flat*/;

	reg pause_cpu /*verilator public_flat*/;

	reg [1:0] game_mode /*verilator public_flat*/;
	localparam GAME_BLOCKADE = 0;
	localparam GAME_COMOTION = 1;
	localparam GAME_HUSTLE = 2;
	localparam GAME_BLASTO = 3;
	
	reg [7:0] IN_1;
	reg [7:0] IN_2;
	reg [7:0] IN_4;

	// Inputs
	wire p1_right = inputs[0];
	wire p1_left = inputs[1];
	wire p1_down = inputs[2];
	wire p1_up = inputs[3];
	wire p2_right = inputs[4];
	wire p2_left = inputs[5];
	wire p2_down = inputs[6];
	wire p2_up = inputs[7];
	wire p3_right = inputs[0];
	wire p3_left = inputs[1];
	wire p3_down = inputs[2];
	wire p3_up = inputs[3];
	wire p4_right = inputs[4];
	wire p4_left = inputs[5];
	wire p4_down = inputs[6];
	wire p4_up = inputs[7];
	wire btn_coin = inputs[8];
	wire btn_start1 = inputs[9];
	wire btn_start2 = inputs[10];
	wire btn_fire1 = inputs[11];
	wire btn_fire2 = inputs[12];
	wire btn_boom = 1'b0;

	localparam blockade_dip_lives_6 = 3'b000;
	localparam blockade_dip_lives_5 = 3'b100;
	localparam blockade_dip_lives_4 = 3'b110;
	localparam blockade_dip_lives_3 = 3'b011;

	localparam comotion_dip_lives_4 = 1'b0;
	localparam comotion_dip_lives_3 = 1'b1;

	localparam hustle_dip_time_90 = 1'b0;
	localparam hustle_dip_time_120 = 1'b1;

	localparam hustle_dip_coin_4C1C = 2'd3;
	localparam hustle_dip_coin_3C1C = 2'd2;
	localparam hustle_dip_coin_2C1C = 2'd1;
	localparam hustle_dip_coin_1C1C = 2'd0;

	localparam hustle_dip_freegame_11000 = 8'b01110001;
	localparam hustle_dip_freegame_13000 = 8'b10110001;
	localparam hustle_dip_freegame_15000 = 8'b11010001;
	localparam hustle_dip_freegame_17000 = 8'b11100001;
	localparam hustle_dip_freegame_none = 8'b11110000;

	localparam blasto_dip_time_90 = 1'b0;
	localparam blasto_dip_time_70 = 1'b1;

	localparam blasto_dip_demosounds_on = 1'b0;
	localparam blasto_dip_demosounds_off = 1'b1;

	localparam blasto_dip_coin_4C1C = 2'd3;
	localparam blasto_dip_coin_3C1C = 2'd2;
	localparam blasto_dip_coin_2C1C = 2'd1;
	localparam blasto_dip_coin_1C1C = 2'd0;

	// Setup hardware inputs for each game mode
	always @(posedge clk_sys) begin
		case (game_mode)
		GAME_BLOCKADE: begin 
			IN_1 <= ~{btn_coin, blockade_dip_lives_4, 1'b0, btn_boom, 2'b00}; // Coin + DIPS
			IN_2 <= ~{p1_left, p1_down, p1_right, p1_up, p2_left, p2_down, p2_right, p2_up}; // P1 + P2 Controls
			IN_4 <= ~{8'b00000000}; // Unused
		end
		GAME_COMOTION: begin 
			IN_1 <= ~{btn_coin, 2'b0, btn_start1||btn_start2, comotion_dip_lives_3, btn_boom, 2'b00}; // Coin, Starts, DIPS
			IN_2 <= ~{p3_left, p3_down, p3_right, p3_up, p1_left, p1_down, p1_right, p1_up}; // P3 + P1 Controls
			IN_4 <= ~{p4_left, p4_down, p4_right, p4_up, p2_left, p2_down, p2_right, p2_up}; // P4 + P2 Controls
		end
		GAME_HUSTLE: begin 
			IN_1 <= ~{btn_coin, 2'b0, btn_start2, btn_start1, hustle_dip_time_120, hustle_dip_coin_1C1C}; // Coin, Starts, DIPS
			IN_2 <= ~{p1_left, p1_down, p1_right, p1_up, p2_left, p2_down, p2_right, p2_up}; // P1 + P2 Controls
			IN_4 <= hustle_dip_freegame_15000; // Extra DIPS
		end
		GAME_BLASTO: begin 
			IN_1 <= ~{btn_coin, 3'b0, blasto_dip_time_70, blasto_dip_demosounds_off, blasto_dip_coin_1C1C}; // Coin, Starts, DIPS
			IN_2 <= ~{btn_fire1, btn_start2, btn_start1, 4'b0000, btn_fire2}; 
			IN_4 <= ~{p1_up, p1_left, p1_down, p1_right, p2_up, p2_left, p2_down, p2_right}; // P1 + P2 Controls
		end
		endcase
	end

	reg [1:0] overlay_type /*verilator public_flat*/;
	reg [2:0] overlay_mask;
	// - Overlay 0 = B/W
	// - Overlay 1 = Green
	// - Overlay 2 = Yellow
	// - Overlay 4 = Red
	wire video;

	always @(posedge clk_sys) begin
		// Generate overlay colour mask
		case(overlay_type)
		2'd0: overlay_mask <= 3'b010; // Green
		2'd1: overlay_mask <= 3'b111; // White
		2'd2: overlay_mask <= 3'b011; // Yellow
		2'd3: overlay_mask <= 3'b001; // Red
		endcase
	end
	wire [2:0] video_rgb = {3{video}} & overlay_mask;
	wire [23:0] rgb = {{8{video_rgb[0]}},{8{video_rgb[1]}},{8{video_rgb[2]}}};

	// Apply selected mask and convert to 8bpp RGB
	assign VGA_R = {8{video_rgb[0]}};
	assign VGA_G = {8{video_rgb[1]}};
	assign VGA_B = {8{video_rgb[2]}};

	// Audio
	wire [15:0] audio_l;
	wire [15:0] audio_r;
	assign AUDIO_L = audio_l;
	assign AUDIO_R = audio_r;

	reg rom_downloaded = 0;
	wire rom_download = ioctl_download && ioctl_index == 8'b0;
	wire reset = (RESET | rom_download | !rom_downloaded);
	always @(posedge clk_sys) if(rom_download) rom_downloaded <= 1'b1; // Latch downloaded rom state to release reset

	blockade blockade (
		.clk(clk_sys),
		.reset(reset),
		.pause(pause_cpu),
		.game_mode(game_mode),
		.ce_pix(ce_pix),
		.video(video),
		.in_1(IN_1),
		.in_2(IN_2),
		.in_4(IN_4),
		.coin(btn_coin),
		.hsync(VGA_HS),
		.vsync(VGA_VS),
		.hblank(VGA_HB),
		.vblank(VGA_VB),
		.dn_addr(ioctl_addr[13:0]),
		.dn_data(ioctl_dout),
		.dn_wr(ioctl_wr),
		.audio_l(audio_l),
		.audio_r(audio_r)
	);

endmodule
