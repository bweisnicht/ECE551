/////////////////////////////////////
// inputs:
//		cmplmnt         -- for 2's complement
//		EEP_rd_data     -- input from eeprom, used for offset and gain
//		CosSAR          -- raw cosine from A2D_digital
//		SinSAR          -- raw sine from A2D_digital
//		ld_sin/cos      -- Loads dst into SinSAR/CosSAR, respectively
//		src1sel         -- selects the src 1 mux feeding into the ALU
//		src0sel         -- selects the src 2 mux
//		init_mult       -- loads the p_reg so it's ready for booth algorithm
//		cmd_data        -- input from the SPI
//		cordic_iter     -- Cordic iteration, used to index the arctan constant table and set the barrel shift amount
//		barrel_sel      -- Source select for the barrel shifter. 1 for cosine, 0 for sine
//		ld_angle_accum  -- Loads dst into angle_accum
//		ld_cordic_tmp   -- Loads dst into the CORDIC temporary register
//
// outputs:
//		booth_sel   -- the two msbs of p_reg. used to determine if the booth alg should add, sub or do nothing
//		cos_sign    -- Sign bit of cosCorr
//		sin_sign    -- Sign bit of sinCorr
//		dst         -- output from the ALU
/////////////////////////////////////

// TODO: Put these in some rational order
module datapath(clk, rst_n, cmplmnt, EEP_rd_data, CosSAR, SinSAR, dst,
	ld_cos, ld_sin, src1sel, src0sel, init_mult, booth_sel, cmd_data,
	cordic_iter, barrel_sel, ld_angle_accum, ld_cordic_tmp,
	cos_sign, sin_sign);

	// TODO: Reorganize these params?
	reg [24:0] p_reg;//Register used for booth

	input [11:0] cmd_data;
	input clk, rst_n;
	input cmplmnt;
	input ld_sin, ld_cos;
	input init_mult;

	// TODO: Should EEP_rd_data be unsigned?
	// TODO: Double check on the implications of "signed".
	//       Can a signed value feed an unsigned reg, etc?
	input signed [11:0] EEP_rd_data, CosSAR, SinSAR;

	input [2:0] src1sel, src0sel;

	input [3:0] cordic_iter;
	input barrel_sel;
	input ld_angle_accum;
	input ld_cordic_tmp;

	output [11:0] dst;
	output [1:0] booth_sel;
	output cos_sign, sin_sign;
	assign booth_sel = p_reg[1:0];

	// src decoding for ALU muxes //

	localparam SRC0_ZERO = 0;
	localparam SRC0_ANGLE_ACCUM = 1;
	localparam SRC0_SIN_CORR = 2;
	localparam SRC0_COS_CORR = 3;
	localparam SRC0_CMD_DATA = 4;
	localparam SRC0_PREG = 5;
	localparam SRC0_SIN_SAR = 6;
	localparam SRC0_COS_SAR = 7;

	localparam SRC1_BARREL = 0;
	localparam SRC1_7FF = 1;
	localparam SRC1_A5A = 2;
	localparam SRC1_TAN_TABLE = 3;
	localparam SRC1_ZERO = 4;
	localparam SRC1_EEP_DATA = 5;
	localparam SRC1_PREG_RES = 6;
	localparam SRC1_CORDIC_TMP = 7;

	///////////////
	// Registers //
	///////////////
	reg signed [11:0] tmpEEP;
	reg signed [11:0] sinCorr;
	reg signed [11:0] cosCorr;

	assign cos_sign = cosCorr[11];
	assign sin_sign = sinCorr[11];

	reg signed [11:0] angleAccum;

	reg signed [11:0] temp; // Holds values during a swap in CORDIC

	always@(posedge clk, negedge rst_n)
		if(!rst_n)
			sinCorr <= 0;
		else if (ld_sin)
			sinCorr <= dst;

	always@(posedge clk, negedge rst_n)
		if(!rst_n)
			cosCorr <= 0;
		else if (ld_cos)
			cosCorr <= dst;

	always@(posedge clk, negedge rst_n)
		if(!rst_n)
			angleAccum <= 0;
		else if (ld_angle_accum)
			angleAccum <= dst;

	always@(posedge clk, negedge rst_n)
		if(!rst_n)
			temp <= 0;
		else if (ld_cordic_tmp)
			temp <= dst;

	// Temp reg for an eeprom read
	always@(posedge clk, negedge rst_n)
		if(!rst_n)
			tmpEEP <= 0;
		else
			tmpEEP <= EEP_rd_data;

	

	////////////////
	// CORDIC ALG //
	////////////////
	wire signed [11:0] barrel;
	assign barrel = (barrel_sel ? cosCorr : sinCorr) >>> cordic_iter;

	// Arctangent lookup table
	reg signed [11:0] atTable;
	always@(cordic_iter) begin
		case (cordic_iter)
			0:  atTable = 12'h200;
			1:  atTable = 12'h12E;
			2:  atTable = 12'h0A0;
			3:  atTable = 12'h051;
			4:  atTable = 12'h029;
			5:  atTable = 12'h014;
			6:  atTable = 12'h00A;
			7:  atTable = 12'h005;
			8:  atTable = 12'h003;
			9:  atTable = 12'h001;
			10: atTable = 12'h001;
			default: atTable = 12'h000;
		endcase
	end

	/////////////////////
	// BOOTH ALGORITHM //
	/////////////////////
	always@(posedge clk, negedge rst_n)
		if(!rst_n)
			p_reg <= 0;
		else if(init_mult)
			p_reg <= {{12{1'b0}},{dst,1'b0}};
		else
			p_reg <= {dst[11], dst[11:0], p_reg[12:1]};

	///////////////
	// ALU ////////
	///////////////

	wire signed [11:0] src1i; //src1 before we consider to take 2's cmplmnt
	// src1 mux //
	assign src1i =
					(src1sel == SRC1_BARREL)     ? barrel :
					(src1sel == SRC1_7FF)        ? 12'h7FF :
					(src1sel == SRC1_A5A)        ? 12'hA5A :
					(src1sel == SRC1_TAN_TABLE)  ? atTable :
					(src1sel == SRC1_EEP_DATA)   ? tmpEEP :
					(src1sel == SRC1_PREG_RES)   ? p_reg[23:12] :
					(src1sel == SRC1_CORDIC_TMP) ? temp :
					12'b0; //zero
	wire signed [11:0] src0;
	// src0 mux //
	assign src0 =
					(src0sel == SRC0_PREG)       ? p_reg[24:13] :
					(src0sel == SRC0_SIN_SAR)    ? SinSAR :
					(src0sel == SRC0_COS_SAR)    ? CosSAR :
					(src0sel == SRC0_ANGLE_ACCUM)? angleAccum :
					(src0sel == SRC0_SIN_CORR)   ? sinCorr :
					(src0sel == SRC0_COS_CORR)   ? cosCorr :
					(src0sel == SRC0_CMD_DATA)   ? cmd_data :
					12'b0;


	wire signed [11:0] src1 = cmplmnt ? ~src1i + 1 : src1i;
	//The adder:
	wire signed [11:0] sat = src1 + src0;
	//Saturation logic:
	assign dst =	~src1[11] & ~src0[11] & sat[11] ? 12'h7FF :	//if two positve numbers add to a negative
					src1[11] & src0[11] & ~sat[11] ? 12'h800 :	//if two negative numbers add to positive
					sat;														//default
	// -------- endmodule ALU --------- //

endmodule
