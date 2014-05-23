`timescale 1ns/1ps
// Digital core state machine

module core_sm(
	//Inputs
	clk, rst_n, SPI_in, cnv_cmplt, 
	cos_sign, sin_sign,
	booth_sel, cmd_rdy, 
	//Outputs
	wrt_SPI, strt_cnv,
	src1sel, src0sel, 
	ld_cos, ld_sin, strt_mult, cmplmnt, // BOOTH
	eep_addr, chrg_pmp_en, eep_cs_n, eep_r_w_n, // EEPROM
	barrel_sel, ld_angle_accum, ld_cordic_tmp, cordic_iter // CORDIC
	);

	input clk, rst_n; // Clock and active-low reset
	input [3:0] SPI_in; // Input from the SPI

	input [1:0] booth_sel; // The two lsb's of p_reg used in booth alg
	input cnv_cmplt; // Raised when A2D conversion is completed
	input cmd_rdy; // Command is ready
	input cos_sign; // Sign bit of cosCorr
	input sin_sign; // Sign bit of sinCorr

	output reg strt_cnv; // Raised to start an A2D conversion
	output reg [2:0] src0sel; //Selects first ALU operand
	output reg [2:0] src1sel; //Selects second ALU operand
	output reg eep_r_w_n;
	output reg eep_cs_n;
	output reg chrg_pmp_en;
	output reg [1:0] eep_addr;
	output reg ld_cos, ld_sin; // Asserted at the end mult when Sin/cos corrected is ready
	output reg strt_mult; // Raised to signal core to multiply signals by their gains
	output reg cmplmnt;
	output reg wrt_SPI; // TODO:
	output reg barrel_sel;
	output reg ld_angle_accum;
	output reg ld_cordic_tmp;

	output [3:0] cordic_iter; // Wired to the counter

	reg setInCmds; // Raised to set InCmds
	reg set_unlock; //
	reg clear_unlock; //
	// Source selects
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

	reg unlockEEP;

	// Counts to 3 milliseconds before starting the state machine
	// Doubles as cordic loop counter
	reg [20:0] counter;

	assign cordic_iter = counter[3:0];

	reg inCmds; // True if we have commands to handle

	reg [4:0] state, next; // Current and next state

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

	// Command cases
	localparam CMD_ENTER = 4'b0x10;
	localparam CMD_SIN = 4'b0x00;
	localparam CMD_COS = 4'b0x01;
	localparam CMD_UNLOCK = 4'b0x11;
	localparam CMD_READ = 4'b10xx;
	localparam CMD_WRITE = 4'b11xx;

	// EEPROM addresses
	localparam sinOFF = 0;
	localparam sinGAIN = 1;
	localparam cosOFF = 2;
	localparam cosGAIN = 3;

	wire enterCmd;
	assign enterCmd = SPI_in == 4'b0110;

	reg clear_counter;
	reg inc_counter;
	always @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			counter <= 0;
		else if (clear_counter)
			counter <= 0;
		else if (inc_counter)
			counter <= counter + 1;
	end
	assign threeMS = (counter == 1500000);
	assign count_eq_12 = (counter[3:0] == 4'b1011); // For booth

	always @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			inCmds <= 0;
		else if (setInCmds)
			inCmds <= 1;
	end

	always @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			unlockEEP <= 0;
		else if (set_unlock)
			unlockEEP <= 1;
		else if (clear_unlock)
			unlockEEP <= 0;
	end

	// State register control
	always @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			state <= INIT;
		else
			state <= next;
	end

	// Src selects for booth multiplication
	wire sub = booth_sel[1] & ~booth_sel[0];
	wire add = ~booth_sel[1] & booth_sel[0];

	always @(*) begin
		clear_counter = 0;
		inc_counter = 0;
		src1sel = SRC1_ZERO;
		src0sel = SRC0_ZERO;
		wrt_SPI = 0;
		strt_cnv = 0;

		// CMD signals
		setInCmds = 0;
		clear_unlock = 0;
		set_unlock = 0;

		// Booth signals
		ld_cos = 0;
		ld_sin = 0;
		strt_mult = 0;
		cmplmnt = 0;

		// CORDIC signals
		barrel_sel = 0;
		ld_angle_accum = 0;
		ld_cordic_tmp = 0;

		//EEPROM defaults
		eep_cs_n = 1;
		eep_r_w_n = 1;
		eep_addr = 0;
		chrg_pmp_en = 0;

		next = INIT;

		case (state)
			INIT: begin
				inc_counter = 1;
				if (threeMS) begin
					next = WAIT_FOR_CNV;
					strt_cnv = 1;
				end
				else if(enterCmd && cmd_rdy) begin
					setInCmds = enterCmd;
					next = WAIT_FOR_CNV;
					strt_cnv = 1;
				end
			end

			WAIT_FOR_CNV: begin
				next = cnv_cmplt ? ADD_COS : WAIT_FOR_CNV;
				if(cnv_cmplt) begin
					eep_cs_n = 0;
					eep_r_w_n = 1;
					eep_addr = cosOFF;
				end
			end

			ADD_COS: begin
				eep_cs_n = 0;
				eep_r_w_n = 1;
				eep_addr = cosGAIN;
				next = MUL_COS;
				src0sel = SRC0_COS_SAR;
				src1sel = SRC1_EEP_DATA;
				strt_mult = 1;
				clear_counter = 1;
			end

			MUL_COS: begin
				eep_cs_n = 0;
				eep_r_w_n = 1;
				eep_addr = cosGAIN;
				inc_counter = 1;
				cmplmnt = sub;
				src1sel = (add | sub) ? SRC1_EEP_DATA : SRC1_ZERO;
				src0sel = SRC0_PREG;
				ld_cos = count_eq_12;
				next = count_eq_12 ? STR_COS : MUL_COS;
			end

			STR_COS: begin
				src1sel = SRC1_PREG_RES;
				src0sel = SRC0_ZERO;
				next = ADD_SIN;
				eep_cs_n = 0;
				eep_r_w_n = 1;
				eep_addr = sinOFF;
			end

			ADD_SIN: begin
				eep_cs_n = 0;
				eep_r_w_n = 1;
				eep_addr = sinGAIN;
				next = MUL_SIN;
				src0sel = SRC0_SIN_SAR;
				src1sel = SRC1_EEP_DATA;
				strt_mult = 1;
				clear_counter = 1;
			end

			MUL_SIN: begin
				eep_cs_n = 0;
				eep_r_w_n = 1;
				eep_addr = sinGAIN;
				inc_counter = 1;				
				src1sel = (add | sub) ? SRC1_EEP_DATA : SRC1_ZERO;
				src0sel = SRC0_PREG;
				cmplmnt = sub;
				ld_sin = count_eq_12;
				next = count_eq_12 ? STR_SIN : MUL_SIN;
			end

			STR_SIN: begin
				src1sel = SRC1_PREG_RES;
				src0sel = SRC0_ZERO;
				if (inCmds)
					if(cmd_rdy) begin
						next = EX_CMD;
						eep_r_w_n = 1;
						eep_cs_n = 0;
						eep_addr = SPI_in[1:0];
					end
					else
						next = WAIT_FOR_CNV;
				else begin
					next = CORDIC_SET_ACCUM;
				end
				strt_cnv = 1;
			end

			EX_CMD: begin
				//decode command and begin execution
				casex(SPI_in)
					CMD_ENTER: begin
						next = WAIT_FOR_CNV;
						src1sel = SRC1_A5A;
						src0sel = SRC0_ZERO;
						wrt_SPI = 1;
					end

					CMD_SIN: begin
						next = WAIT_FOR_CNV;
						src1sel = SRC1_BARREL;
						src0sel = SRC0_SIN_CORR;
						wrt_SPI = 1;
					end

					CMD_COS: begin
						next = WAIT_FOR_CNV;
						src1sel = SRC1_BARREL;
						src0sel = SRC0_COS_CORR;
						wrt_SPI = 1;
					end

					CMD_UNLOCK: begin
						next = WAIT_FOR_CNV;
						src1sel = SRC1_A5A;
						src0sel = SRC0_ZERO;
						set_unlock = 1;
						wrt_SPI = 1;
					end

					CMD_READ: begin
						next = WAIT_FOR_CNV;
						src1sel = SRC1_EEP_DATA;
						src0sel = SRC0_ZERO;
						wrt_SPI = 1;
					end
					default: begin
						if(unlockEEP) begin
							next = WRITE_EEP;
							src1sel = SRC1_ZERO;
							src0sel = SRC0_CMD_DATA;
							clear_counter = 1;
							eep_r_w_n = 0;
							eep_cs_n = 0;
							eep_addr = SPI_in[1:0];
						end
						else
							next = WAIT_FOR_CNV;
					end
				endcase
			end

			CORDIC_SET_ACCUM: begin
				clear_counter = 1; // Zero our CORDIC counter
				ld_angle_accum = 1;

				// If cos < 0
				if (cos_sign) begin
					// If sin < 0
					if (sin_sign) begin
						// angle_accum = 0x800
						// Adding a negative value to -0x7ff will saturate to 0x800
						cmplmnt = 1;
						src0sel = SRC0_SIN_CORR;
						src1sel = SRC1_7FF;
					end
					else begin
						// angle_accum = 0x7ff
						src0sel = SRC0_ZERO;
						src1sel = SRC1_7FF;
					end

					next = CORDIC_FLIP_COS;
				end
				else begin
					// angle_accum = 0
					src0sel = SRC0_ZERO;
					src1sel = SRC1_ZERO;

					next = CORDIC_INC_ACCUM;
				end
			end

			CORDIC_FLIP_COS: begin
				// cos = -cos
				ld_cos = 1;
				cmplmnt = 1; // Invert us
				barrel_sel = 1; // Route cos through the barrel
				src0sel = SRC0_ZERO;
				src1sel = SRC1_BARREL;
				next = CORDIC_FLIP_SIN;
			end

			CORDIC_FLIP_SIN: begin
				// sin = -sin
				ld_sin = 1;
				cmplmnt = 1; // Invert us
				barrel_sel = 0; // Route sin through the barrel
				src0sel = SRC0_ZERO;
				src1sel = SRC1_BARREL;
				next = CORDIC_INC_ACCUM;
			end

			CORDIC_INC_ACCUM: begin
				ld_angle_accum = 1;
				cmplmnt = sin_sign; // Subtract if sin < 0
				src0sel = SRC0_ANGLE_ACCUM;
				src1sel = SRC1_TAN_TABLE;
				next = CORDIC_STORE_TMP;
			end

			CORDIC_STORE_TMP: begin
				ld_cordic_tmp = 1;
				cmplmnt = sin_sign; // Subtract if sin < 0
				barrel_sel = 0; // Route sin through the barrel
				src0sel = SRC0_COS_CORR;
				src1sel = SRC1_BARREL;
				next = CORDIC_UPDATE_SIN;
			end

			CORDIC_UPDATE_SIN: begin
				ld_sin = 1;
				cmplmnt = ~sin_sign; // Subtract if sin > 0
				barrel_sel = 1; // Route cos through the barrel
				src0sel = SRC0_SIN_CORR;
				src1sel = SRC1_BARREL;
				next = CORDIC_UPDATE_COS;
			end

			CORDIC_UPDATE_COS: begin
				inc_counter = 1; // ++counter
				ld_cos = 1;
				src0sel = SRC0_ZERO;
				src1sel = SRC1_CORDIC_TMP;
				next = counter == 11 ? SEND_ANGLE : CORDIC_INC_ACCUM;
			end

			SEND_ANGLE: begin
				src0sel = SRC0_ANGLE_ACCUM;
				src1sel = SRC1_ZERO;
				wrt_SPI = 1;
				next = WAIT_FOR_CNV;
			end

			WRITE_EEP: begin
				inc_counter = 1;
				if (threeMS) begin
					next = WAIT_FOR_CNV;
					src1sel = SRC1_A5A;
					src0sel = SRC0_ZERO;
					clear_unlock = 1;
					wrt_SPI = 1;
				end
				else begin
					next = WRITE_EEP;
					chrg_pmp_en = 1;
				end
			end

			default: next = INIT;
		endcase
	end

endmodule
