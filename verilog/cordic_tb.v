// CORDIC testbench.
// TODO: Merge into datapath_tb later?
module cordic_tb();

	reg clk, rst_n;
	reg [15:0]SPI_in = 0; //Not used yet
	reg cnv_cmplt;
	wire [2:0] src1sel, src0sel;
	wire [1:0] booth_sel;
	reg signed [11:0] EEP_rd_data; //Input from eeprom
	reg signed [11:0] SinSAR, CosSAR; // Input from a2d
	wire [11:0] dst;
	wire barrel_sel;
	wire ld_angle_accum, ld_cordic_tmp;
	wire cos_sign, sin_sign;
	wire [3:0] cordic_iter;

	//clock generation
	initial clk = 0;
	always@(clk)
		#1 clk <= ~clk;

	// States
	localparam INIT = 0;
	localparam WAIT_FOR_CNV = 1;
	localparam ADD_COS = 2;
	localparam ADD_SIN = 3;
	localparam MUL_COS = 4;
	localparam MUL_SIN = 5;
	localparam EX_CMD = 6;
	localparam CORDIC_SET_ACCUM = 7;
	localparam CORDIC_FLIP_COS = 8;
	localparam CORDIC_FLIP_SIN = 9;
	localparam CORDIC_INC_ACCUM = 10;
	localparam CORDIC_STORE_TMP = 11;
	localparam CORDIC_UPDATE_SIN = 12;
	localparam CORDIC_UPDATE_COS = 13;
	localparam SEND_ANGLE = 14;
	localparam WRITE_EEP = 15;
	localparam STR_COS = 16;
	localparam STR_SIN = 17;

	//Interconnects datapath and sm

	//Instantiate the state machine
	core_sm smDUT(
		//Inputs
		.clk(clk), .rst_n(rst_n), .SPI_in(), .cnv_cmplt(cnv_cmplt), .src1sel(src1sel), .src0sel(src0sel),
		.cmplmnt(cmplmnt), .booth_sel(booth_sel), .ld_sin(ld_sin),
		.ld_cos(ld_cos), .cmd_rdy(cmd_rdy), .cos_sign(cos_sign), .sin_sign(sin_sign),
		//Outputs
		.strt_cnv(strt_cnv), .strt_mult(srt_mult), .eep_addr(), .chrg_pmp_en(chrg_pmp_en),
		.eep_cs_n(eep_cs_n), .eep_r_w_n(eep_r_w_n), .wrt_SPI(wrt_SPI),
		.barrel_sel(barrel_sel), .ld_angle_accum(ld_angle_accum), .ld_cordic_tmp(ld_cordic_tmp), .cordic_iter(cordic_iter));

	//Instantiate the datapath
	datapath dpDUT(
		//Inputs
		.clk(clk), .rst_n(rst_n), .cmplmnt(cmplmnt), .EEP_rd_data(),
		.CosSAR(), .SinSAR(), .ld_cos(ld_cos), .ld_sin(ld_sin),
		.src1sel(src1sel), .src0sel(src0sel), .init_mult(srt_mult), .cmd_data(),
		.barrel_sel(barrel_sel), .ld_angle_accum(ld_angle_accum), .ld_cordic_tmp(ld_cordic_tmp), .cordic_iter(cordic_iter),
		//Outputs
		.booth_sel(booth_sel), .dst(dst), .cos_sign(cos_sign), .sin_sign(sin_sign));

	reg [35:0] mem [0:4095];
	integer i;

	initial begin
		$readmemh("cordic.mem", mem);
		rst_n = 0;
		#4 rst_n = 1;
		for (i = 0; i < 4095; i = i + 1) begin
			smDUT.state = CORDIC_SET_ACCUM;
			dpDUT.cosCorr = mem[i][35:24];
			dpDUT.sinCorr = mem[i][23:12];
			/*
			$display("C: %x S: %x", mem[i][35:24], mem[i][23:12]);
			$monitor("State: %d, iter: %d, cos: %x, sin: %x, tmp: %x, accum: %x",
					 smDUT.state, cordic_iter, dpDUT.cosCorr, dpDUT.sinCorr, dpDUT.temp, dpDUT.angleAccum);
			*/
			wait (smDUT.state === WAIT_FOR_CNV) begin
				if (mem[i][11:0] !== dpDUT.dst) begin
			$display("C: %x S: %x", mem[i][35:24], mem[i][23:12]);
					$display("ERROR: Angle %d, Expected CORDIC: %h, got: %h", i, mem[i][11:0], dpDUT.dst);
					$stop;
				end
			end
		end
		$finish;
	end
endmodule
