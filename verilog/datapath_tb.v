// Test bench for datapath and main state machine
//
module datapath_tb();

	reg clk, rst_n;
	reg [15:0]SPI_in = 0; //Not used yet
	reg cnv_cmplt;
	wire [2:0] src1sel, src0sel;
	wire [1:0] booth_sel;
	reg signed [11:0] EEP_rd_data; //Input from eeprom
	reg signed [11:0] SinSAR, CosSAR; // Input from a2d
	wire [11:0] dst;
	//clock generation
	initial clk = 0;
	always@(clk)
		#1 clk <= ~clk;

	//Instantiate the state machine
	core_sm smDUT(
		//Inputs
		.clk(clk), .rst_n(rst_n), .SPI_in(SPI_in[15:12]), .cnv_cmplt(cnv_cmplt), 
		 .booth_sel(booth_sel), .cos_sign(1'b0), .sin_sign(1'b0),  
		.cmd_rdy(cmd_rdy), 
		//Outputs
		.wrt_SPI(), .strt_cnv(), 
		.src1sel(src1sel), .src0sel(src0sel),
		.ld_sin(ld_sin), .ld_cos(ld_cos), .strt_mult(srt_mult), .cmplmnt(cmplmnt),
		.eep_addr(), .chrg_pmp_en(), .eep_cs_n(), .eep_r_w_n(), 
		.barrel_sel(), .ld_angle_accum(), .ld_cordic_tmp(), .cordic_iter()
		);



	//Instantiate the datapath
	datapath dpDUT(
		//Inputs
		.clk(clk), .rst_n(rst_n), .cmplmnt(cmplmnt), .EEP_rd_data(EEP_rd_data),
		.CosSAR(CosSAR), .SinSAR(SinSAR), .ld_cos(ld_cos), .ld_sin(ld_sin),
		.src1sel(src1sel), .src0sel(src0sel), .init_mult(srt_mult), .cmd_data(SPI_in[11:0]),
		.ld_angle_accum(1'b0), .barrel_sel(1'b0), .cordic_iter(4'b0), .ld_cordic_tmp(1'b0), 
		//Outputs
		.booth_sel(booth_sel), .dst(dst), .sin_sign(), .cos_sign());

	localparam STR_COS = 15;
	localparam STR_SIN = 16;
	reg signed [23:0] calc;
	reg signed [11:0] goal;
	reg signed [11:0] addGoal;
	reg fail;
	reg signed [12:0] SinSAR_test;
	initial begin
		//Test multiplication
		$display("TEST 1");
		$display("Testing additon and multiplication for cosine and sine");
		$display("Takes about 12 min.");
		rst_n = 0; cnv_cmplt = 0;
		fail = 0;
		#4 rst_n = 1;
		for (EEP_rd_data = 0; EEP_rd_data < 2047; EEP_rd_data = EEP_rd_data + 1)
			for (SinSAR_test = -2048; SinSAR_test < 2047; SinSAR_test = SinSAR_test + 1) begin
				SinSAR = SinSAR_test[11:0];
				CosSAR = SinSAR;
				force smDUT.state = 1; // WAIT_FOR_CNV
				#2;

				addGoal = CosSAR + EEP_rd_data;
				if(addGoal[11] & ~CosSAR[11] & ~EEP_rd_data[11])
					addGoal = 12'h7ff;
				else if(~addGoal[11] & CosSAR[11] & EEP_rd_data[11])
					addGoal = 12'h800;
				calc = ((addGoal)*EEP_rd_data);
				goal = calc[22:11];

				cnv_cmplt = 1;
				release smDUT.state;
				wait(smDUT.state == STR_COS)
					if(dpDUT.cosCorr != goal) begin
						$display("ERROR. EEP_rd_data: %d, CosSAR: %d, expected: %d, got: %d",
							EEP_rd_data, CosSAR, goal, dpDUT.cosCorr);
						fail = 1;
					end

				addGoal = SinSAR + EEP_rd_data;
				if(addGoal[11] & ~SinSAR[11] & ~EEP_rd_data[11])
					addGoal = 12'h7ff;
				else if(~addGoal[11] & SinSAR[11] & EEP_rd_data[11])
					addGoal = 12'h800;
				calc = ((addGoal)*EEP_rd_data);
				goal = calc[22:11];

				wait(smDUT.state == STR_SIN)
					if(dpDUT.sinCorr != goal) begin
						$display("ERROR. EEP_rd_data: %d, SinSAR: %d, expected: %d, got: %d",
							EEP_rd_data, SinSAR, goal, dpDUT.sinCorr);
						fail = 1;
					end
				cnv_cmplt = 0;
				
				#2;
		end
		$display("Test 1 complete");
		if(!fail)
			$display("SUCCESS!! :)");
		else
			$display("FAIL!! :(");

		$stop;
	end

endmodule
