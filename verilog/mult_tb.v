module mult_tb();

	//Instantiate the DUT
	reg clk, rst_n, strt_mult;
	reg [11:0] multiplier, multiplicand;
	wire [23:0] result;
	wire done;
	mult multDUT(.clk(clk), .rst_n(rst_n), .multiplier(multiplier), .multiplicand(multiplicand),
	             .result(result), .done(done), .strt_mult(strt_mult));

	wire add = multDUT.add;
	wire sub = multDUT.sub;
	wire shft = multDUT.shft;
	wire [24:0] p_reg = multDUT.p_reg;
	wire state = multDUT.state;
	wire next_state = multDUT.nxt_state;
	wire [3:0] count = multDUT.count;
	wire count_eq12 = multDUT.count_eq_12;
	wire ld = multDUT.ld;
	wire [12:0] multcomp = multDUT.multiplicand_comp;

	//Generate clk
	initial clk = 0;
	always@(clk)
		#1 clk <= ~clk;
	reg fail;
	initial begin
		fail = 0;
    	rst_n = 0; strt_mult = 0; multiplier = 0; multiplicand = 0;
    	#5
		rst_n = 1;
		for(multiplicand = 2047; multiplicand < 3000; multiplicand = multiplicand +1) begin
			for(multiplier = 7; multiplier < 1023; multiplier = multiplier +1) begin
				strt_mult = 1;
				#2 strt_mult = 0;
				#36;
				if(result != (multiplier*multiplicand))begin
					$display("ERROR"); fail = 1;
				end
				//$display("Result of booth: %d. Expected: %d",result,(multiplier*multiplicand));
			end
		end
		if(!fail)
			$display("SUCCESS.");
		$stop;
	end

endmodule
