`timescale 1 ps / 1 ps

/*
 * Emulates 555 timer astable circuit by counting clock
 */
module ttl_555 (
  input  clk,    // clock for counting
  input  reset,  // reset high
  output out     // output
);

	parameter HIGH_COUNTS = 1000;
	parameter LOW_COUNTS  = 1000;

	localparam BIT_WIDTH_HIGH = $clog2(HIGH_COUNTS);
	localparam BIT_WIDTH_LOW  = $clog2(LOW_COUNTS);

	// State constants
	localparam STATE_RESET = 0;
	localparam STATE_HIGH_COUNT = 1;
	localparam STATE_LOW_COUNT = 2;

	reg [1:0] state;
	reg [1:0] next_state;

	//
	// Counter
	//
	reg [BIT_WIDTH_HIGH-1 : 0] high_counter;
	reg [BIT_WIDTH_LOW-1 : 0]  low_counter;
	wire high_count_end = (high_counter == HIGH_COUNTS - 1);
	wire low_count_end  = (low_counter  == LOW_COUNTS  - 1);
	assign out = (state == STATE_HIGH_COUNT) ? 1'b1 : 1'b0;

	always @(posedge clk) 
	begin

		if (reset) state <= STATE_RESET;

		// Increment relevant counters
		case(state)
		STATE_RESET:
		begin
			high_counter <= 'd0;
			low_counter  <= 'd0;
			state <= STATE_HIGH_COUNT;
		end
		STATE_HIGH_COUNT:
		begin
			high_counter <= high_counter + 'd1;
			if (high_count_end) state <= STATE_LOW_COUNT;
		end
		STATE_LOW_COUNT:
		begin
			low_counter  <= low_counter  + 'd1;
			if (low_count_end) state <= STATE_HIGH_COUNT;
		end
		endcase

		// $display("state:%x low_counter: %d high_counter: %d", state, low_counter, high_counter);

		// Move to next state
		

	end

endmodule