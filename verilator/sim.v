`timescale 1ns/1ns
// top end ff for verilator

module emu(

	input clk_sys /*verilator public_flat*/,
	input reset/*verilator public_flat*/,
	input [9:0]  inputs/*verilator public_flat*/,

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

	reg [1:0] game_mode /*verilator public_flat*/;
	localparam GAME_BLOCKADE = 0;
	localparam GAME_COMOTION = 1;

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
	wire btn_start = inputs[9];
	wire btn_boom = 1'b0;

	localparam blockade_dip_lives_6 = 3'b000;
	localparam blockade_dip_lives_5 = 3'b100;
	localparam blockade_dip_lives_4 = 3'b110;
	localparam blockade_dip_lives_3 = 3'b011;

	localparam comotion_dip_lives_4 = 1'b0;
	localparam comotion_dip_lives_3 = 1'b1;


	// Setup hardware inputs for each game mode
	always @(posedge clk_sys) begin
		case (game_mode)
		GAME_BLOCKADE: begin 
			IN_1 <= ~{1'b0, blockade_dip_lives_5, 1'b0, btn_boom, 2'b00}; // Coin + DIPS
			IN_2 <= ~{p2_left, p2_down, p2_right, p2_up, p1_left, p1_down, p1_right, p1_up}; // P1 + P2 Controls
			IN_4 <= ~{8'b00000000}; // Unused
		end
		GAME_COMOTION: begin 
			//IN_1 <= ~{btn_coin, comotion_dip_lives_4, 1'b0, btn_start, 1'b0, btn_boom, 2'b00}; // Coin + DIPS
			IN_1 <= ~{p4_left, p4_down, p4_right, p4_up, p3_left, p3_down, p3_right, p3_up}; // P3 + P4 Controls
			// IN_1 <= {8'b0};
			//IN_2 <= ~{btn_coin, 2'b00, btn_start, comotion_dip_lives_3, btn_boom, 2'b00};
			IN_2 <= ~{3'b0, btn_start, comotion_dip_lives_3, btn_boom, 2'b00};
			//IN_2 <= ~{p2_left, p2_down, p2_right, p2_up, p1_left, p1_down, p1_right, p1_up}; // P1 + P2 Controls
			IN_4 <= ~{p2_left, p2_down, p2_right, p2_up, p1_left, p1_down, p1_right, p1_up}; // P1 + P2 Controls
		end
		endcase
	end

	reg RED;
	reg GREEN;
	reg BLUE;

	// Convert output to 8bpp
	assign VGA_R = {8{RED}};
	assign VGA_G = {8{GREEN}};
	assign VGA_B = {8{BLUE}};

	// Audio
	wire [15:0] audio_l;
	wire [15:0] audio_r;
	assign AUDIO_L = audio_l;
	assign AUDIO_R = audio_r;

	blockade blockade (
		.clk(clk_sys),
		.reset(reset || ioctl_download),
		.game_mode(game_mode),
		.ce_pix(ce_pix),
		.r(RED),
		.g(GREEN),
		.b(BLUE),
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
