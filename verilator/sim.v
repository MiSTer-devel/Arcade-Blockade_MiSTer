`timescale 1ns/1ns
// top end ff for verilator

module emu(

   input clk_sys /*verilator public_flat*/,
   input reset/*verilator public_flat*/,
   input [8:0]  inputs/*verilator public_flat*/,

   output [7:0] VGA_R/*verilator public_flat*/,
   output [7:0] VGA_G/*verilator public_flat*/,
   output [7:0] VGA_B/*verilator public_flat*/,
   
   output VGA_HS,
   output VGA_VS,
   output VGA_HB,
   output VGA_VB,

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

   reg RED;
   reg GREEN;
   reg BLUE;

   // Convert output to 8bpp
   assign VGA_R = {8{RED}};
   assign VGA_G = {8{GREEN}};
   assign VGA_B = {8{BLUE}};

   // Inputs
   wire p1_right = inputs[0];
   wire p1_left = inputs[1];
   wire p1_down = inputs[2];
   wire p1_up = inputs[3];
   wire p2_right = inputs[4];
   wire p2_left = inputs[5];
   wire p2_down = inputs[6];
   wire p2_up = inputs[7];
   wire btn_coin = inputs[8];
   wire btn_boom = 1'b1;

   localparam dip_lives_6 = 3'b000;
   localparam dip_lives_5 = 3'b100;
   localparam dip_lives_4 = 3'b110;
   localparam dip_lives_3 = 3'b011;

   blockade blockade (
      .clk(clk_sys),
      .reset(reset || ioctl_download),
      .ce_pix(ce_pix),
      .r(RED),
      .g(GREEN),
      .b(BLUE),
      .in0(~{8'b00000000}),
      .in1(~{btn_coin, dip_lives_5, 1'b0, btn_boom, 2'b00}), // Coin + DIPS?
      .in2(~{p2_left, p2_down, p2_right, p2_up, p1_left, p1_down, p1_right, p1_up}), // Controls
      .hsync(VGA_HS),
      .vsync(VGA_VS),
      .hblank(VGA_HB),
      .vblank(VGA_VB),
      .dn_addr(ioctl_addr[13:0]),
      .dn_data(ioctl_dout),
      .dn_wr(ioctl_wr)
   );

endmodule
