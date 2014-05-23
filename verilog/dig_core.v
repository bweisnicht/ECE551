module dig_core(clk, rst_n, cmd_rdy, cmd_rcvd, wrt_SPI, dst, eep_rd_data, eep_cs_n,
		eep_r_w_n, eep_addr, chrg_pmp_en, strt_cnv, cnv_cmplt,
		///// A2D_digital returns sinSAR & cosSAR as unsigned, so convert to signed here //////
		sinSAR, cosSAR);

	// Inputs
	input clk, rst_n;
	input cmd_rdy;
	input [11:0] sinSAR, cosSAR;
	input [11:0] eep_rd_data;
	input cnv_cmplt;
	input [15:0] cmd_rcvd;

	// Outputs
	output strt_cnv;
	output wrt_SPI;
	output [11:0] dst;
	output [1:0] eep_addr;
	output eep_cs_n, eep_r_w_n;
	output chrg_pmp_en;

	//Interconnects datapath and sm
	wire [2:0] src1sel, src0sel;
	wire [1:0] booth_sel;
	wire barrel_sel;
	wire ld_angle_accum, ld_cordic_tmp;
	wire cos_sign, sin_sign;
	wire [3:0] cordic_iter;

	//Instantiate the state machine
	core_sm smDUT(
		//Inputs
		.clk(clk), .rst_n(rst_n), .SPI_in(cmd_rcvd[15:12 ]), .cnv_cmplt(cnv_cmplt), .src1sel(src1sel), .src0sel(src0sel),
		.cmplmnt(cmplmnt), .booth_sel(booth_sel), .ld_sin(ld_sin),
		.ld_cos(ld_cos), .cmd_rdy(cmd_rdy), .cos_sign(cos_sign), .sin_sign(sin_sign),
		//Outputs
		.strt_cnv(strt_cnv), .strt_mult(srt_mult), .eep_addr(eep_addr), .chrg_pmp_en(chrg_pmp_en),
		.eep_cs_n(eep_cs_n), .eep_r_w_n(eep_r_w_n), .wrt_SPI(wrt_SPI),
		.barrel_sel(barrel_sel), .ld_angle_accum(ld_angle_accum), .ld_cordic_tmp(ld_cordic_tmp), .cordic_iter(cordic_iter));

	//Instantiate the datapath
	datapath dpDUT(
		//Inputs
		.clk(clk), .rst_n(rst_n), .cmplmnt(cmplmnt), .EEP_rd_data(eep_rd_data),
		.CosSAR(cosSAR), .SinSAR(sinSAR), .ld_cos(ld_cos), .ld_sin(ld_sin),
		.src1sel(src1sel), .src0sel(src0sel), .init_mult(srt_mult), .cmd_data(cmd_rcvd[11:0]),
		.barrel_sel(barrel_sel), .ld_angle_accum(ld_angle_accum), .ld_cordic_tmp(ld_cordic_tmp), .cordic_iter(cordic_iter),
		//Outputs
		.booth_sel(booth_sel), .dst(dst), .cos_sign(cos_sign), .sin_sign(sin_sign));

endmodule
