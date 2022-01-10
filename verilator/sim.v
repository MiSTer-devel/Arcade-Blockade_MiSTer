`timescale 1ns/1ns
// top end ff for verilator

module emu(

   input clk_sys /*verilator public_flat*/,
   input reset/*verilator public_flat*/,
   input [11:0]  inputs/*verilator public_flat*/,

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

   wire btn_start = inputs[6];
   wire btn_coin = inputs[8];
   wire m_bomb = inputs[5];
   wire m_fire = inputs[4];
   wire m_right = inputs[0];
   wire m_left = inputs[1];
   wire m_down = inputs[2];
   wire m_up = inputs[3];

   blockade blockade (
      .clk(clk_sys),
      .reset(reset || ioctl_download),
      .ce_pix(ce_pix),
      .r(RED),
      .g(GREEN),
      .b(BLUE),
      .buttons(~{btn_coin, btn_start, m_bomb, m_fire, m_right, m_left, m_down, m_up}),
      .hsync(VGA_HS),
      .vsync(VGA_VS),
      .hblank(VGA_HB),
      .vblank(VGA_VB),
      .dn_addr(ioctl_addr[13:0]),
      .dn_data(ioctl_dout),
      .dn_wr(ioctl_wr)
   );

endmodule
