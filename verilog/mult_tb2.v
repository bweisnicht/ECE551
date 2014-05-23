module mult_tb2();

	//Instantiate the DUT
	reg clk, rst_n;
	wire cmplmnt, addOne;
	reg signed [11:0] SinSAR, CosSAR;
	reg ld_cos, ld_sin;
	wire [2:0] src1sel, src0sel;
	reg init_mult;
	reg signed [11:0] EEP_data;
	wire [1:0] booth_Sel;
	reg [15:0] cmd_data;
	datapath multDUT(	.clk(clk), .rst_n(rst_n), .cmplmnt(cmplmnt),
							.EEP_rd_data(EEP_data), .CosSAR(CosSAR), .SinSAR(SinSAR), .ld_cos(ld_cos),
							.ld_sin(ld_sin), .src1sel(src1sel), .src0sel(src0sel), .init_mult(init_mult),
							.booth_sel(booth_Sel), .cmd_data(cmd_data));

	//Generate clk
	initial clk = 0;
	always@(clk)
		#1 clk <= ~clk;

	//Counter that counts the 12 cycles
	reg [3:0] count;
	reg rst_count;
	always@(posedge clk)
		if(rst_count)
			count <= 0;
		else
			count <= count + 1;
	assign count_eq_12 = (count == 4'b1100);


	wire [11:0] resultOut = multDUT.sinCorr;
	wire [11:0] theDST = multDUT.dst;
	wire [24:0] thePREG = multDUT.p_reg;
	wire [11:0] tempResult = multDUT.p_reg[23:12];

	reg booth_state;
	reg add_state;

	//Should add or sub?
	assign sub = (booth_Sel[1] & ~booth_Sel[0]) & ~add_state;
	assign add = (~booth_Sel[1] & booth_Sel[0]);

	// src decoding for ALU muxes //
	// src1sel //
	localparam upperPreg = 0;
	localparam result = 1;
	localparam SinSARsel = 2;
	localparam CosSARsel = 3;

	// src0sel //
	localparam EEP_rd = 0;
	localparam zero = 1;

	assign src1sel = 	(booth_state) ? upperPreg :
							(add_state) ? SinSARsel : 2'b00;

	assign src0sel = 	(add | sub | add_state) ? EEP_rd : zero;

	assign cmplmnt = sub;
	assign addOne = sub;
	assign shft = ~rst_count;

	//assign arit = sub ? {p_reg[24:13] + multiplicand_comp, p_reg[12:0]} :
	//					add ? {p_reg[24:13] + multiplicand, p_reg[12:0]} : 0;

	reg fail;
	reg test_fail;
	reg signed [12:0] EEP_test;
	reg signed [12:0] Sin_test;
	reg signed [23:0] goal;
	reg signed [11:0] addGoal;
	initial begin
		cmd_data = 0;
		fail = 0; // Raised if an individual test fails
		test_fail = 0; // Raised if the entire test has failed
    	rst_n = 0; init_mult = 0; SinSAR = 0; CosSAR = 0;
		ld_cos = 0; ld_sin = 0;
		EEP_data = 0;
		rst_count = 1;

		booth_state = 0;
		add_state = 0;

		#5 rst_n = 1;

		for(EEP_test = 2040; EEP_test < 2041; EEP_test = EEP_test + 1) begin
			for(Sin_test = 10; Sin_test < 11; Sin_test = Sin_test + 1) begin
				EEP_data = EEP_test[11:0];
				SinSAR = Sin_test[11:0];
				//goal = (SinSAR + EEP_data)*EEP_data;
				addGoal = SinSAR + EEP_data;
				if(addGoal[11] & ~SinSAR[11] & ~EEP_data[11])
					addGoal = 12'h7ff;
				else if(~addGoal[11] & SinSAR[11] & EEP_data[11])
					addGoal = 12'h800;
				goal = addGoal * EEP_data;


				//ADD STATE //
				add_state = 1;

				#2; //Should take one clock cycle: read eeprom and addition
				init_mult = 1;

				#2
				// Enter booth state!
				add_state = 0;
				booth_state = 1;
				init_mult = 0;
				rst_count = 0;

				wait (count_eq_12) begin
					ld_sin = 1;
				end
				rst_count = 1;
				booth_state = 0;
				add_state = 0;
				if(goal[22:11] !== tempResult) begin
					$display("ERROR. EEP_test: %d, Sin_test: %d, expected: %d, got: %d",
					         EEP_test, Sin_test, goal, tempResult);
					test_fail = 1;
					fail = 1;
				end
				#2;
				ld_sin = 0;

				//Give some room - debug
				#1;
				fail = 0;
				//$stop;
			end
		end

		if(!test_fail)
			$display("SUCCESS.");
		else
			$display("FAIL.");
		$stop;
	end

endmodule
