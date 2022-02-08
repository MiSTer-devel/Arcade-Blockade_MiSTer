`timescale 1 ps / 1 ps

module ttl_74163
(
  input clk,
  input ce,       //  2 - Clock enable pulse
  input reset_n,  //  1 - Master Reset (active-low)
  input enp,      //  7 - Count enable parallel
  input ent,      // 10 - Count enable trickle
  input load_n,   //  9 - Parallel enable (active-low)
  input [3:0] p,  // 3,4,5,6 - Parallel inputs
  output [3:0] q, // 14,13,12,11 - Parallel outputs
  output tco      // 15 - Terminal count output
);

reg overflow = 1'b0;
reg [3:0] count = 0;

always @(posedge clk or negedge reset_n)
begin
    if(ce)
    begin
      if (~reset_n)
      begin
        count <= 4'b0000;
        overflow <= 1'b0;
      end
      else if (~load_n)
      begin
        $display("74163- load %b", p);
        count <= p;
        overflow <= 1'b0;
      end
      else if (enp & ent)
      begin
        count <= count + 1;
        overflow <= count[3] & count[2] & count[1] & ~count[0] & ent; // Counted till 14 ('b1110) and ent is active (high)
      end
    end
  end
  assign q = count;
  assign tco = overflow;

endmodule