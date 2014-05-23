`timescale 1ns/1ps
module A2D_digital(clk, rst_n, gt_sin, gt_cos, strt_cnv, sinSAR, cosSAR, smpl, cnv_cmplt);
	input clk; // Clock
	input rst_n; // Active-low reset
	input gt_sin, gt_cos; // sinSAR > V_sin and cosSAR > V_Cos, respectively. Returned from the A2D Analog component
	input strt_cnv; // Raised to start a conversion
	output reg [11:0] sinSAR, cosSAR; // Successive approximations of the analog sine and cosine values
	output smpl; // Sent to the A2D analog copmonent to hold the current sample voltage
	output reg cnv_cmplt; // Sent to signal the completion of the conversion process

	// Double flop gt_sin and gt_cos
	wire df_gt_sin, df_gt_cos;
	dflop sinStabilizer(.clk(clk), .rst_n(rst_n), .in(gt_sin), .out(df_gt_sin));
	dflop cosStabilizer(.clk(clk), .rst_n(rst_n), .in(gt_cos), .out(df_gt_cos));

	// States
	localparam IDLE = 2'b00; // Idle state. Doubles as finished state
	localparam INIT = 2'b01; // Initialize the conversion proces and assert strt_cnv;
	localparam STABILIZE = 2'b10; // Waiting for a conversion to settle
	localparam CALC = 2'b11; // Calculate one SAR bit

	reg [1:0] state, next;

	reg [11:0] SARMask; // SAR bit mask/counter. Starts at msb and shifts down to zero
	reg [6:0] stableWait; // Amount of clocks that we should wait before taking another measurement. Also used for init.

	assign smpl = state == INIT; // Hold inputs steady during the A2D process

	reg nextBit; // Raised if we should shift the SAR mask/counter and set the current SAR bit
	reg resetWait; // Raised if we should reset the wait counter
	reg decWait; // Raised if we should decrement the wait counter
	reg resetSAR; // Rasied if we should reset the SAR registers
	reg setComplete, clearComplete; // Used to set and clear cnv_cmplt

	wire [11:0] nextMask;
	assign nextMask = {1'b0, SARMask[11:1]};

	// State register control
	always @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			state <= IDLE;
		else
			state <= next;
	end

	// Conversion complete register control
	always @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			cnv_cmplt <= 0;
		end
		else begin
			if (setComplete)
				cnv_cmplt <= 1;
			else if (clearComplete)
				cnv_cmplt <= 0;
		end
	end

	// SAR mask register control
	always @(posedge clk) begin
		if (resetSAR)
			SARMask <= 12'h800;
		else if (nextBit)
			SARMask <= nextMask;
	end

	// sinSAR register control
	always @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			sinSAR <= 0;
		else if (resetSAR) begin
			sinSAR <= 12'h800;
		end
		else if (nextBit) begin
			if (df_gt_sin)
				// If we're greater than, zero the current bit and set the next bit high
				sinSAR <= (sinSAR & ~SARMask) | nextMask;
			else
				// If we're less than or equal to, set the next bit high
				sinSAR <= sinSAR | nextMask;
		end
	end

	// cosSSAR reigster control
	always @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			cosSAR <= 0;
		else if (resetSAR) begin
			cosSAR <= 12'h800;
		end
		else if (nextBit) begin
			if (df_gt_cos)
				// If we're greater than, zero the current bit and set the next bit high
				cosSAR <= (cosSAR & ~SARMask) | nextMask;
			else
				// If we're less than or equal to, set the next bit high
				cosSAR <= cosSAR | nextMask;
		end
	end

	// stable wait counter control
	always @(posedge clk) begin
		if (resetWait)
			stableWait <= 127;
		else if (decWait)
			stableWait <= stableWait - 1;
	end

	// State machine
	always @(*) begin
		// Defaults
		nextBit = 0;
		resetWait = 0;
		decWait = 0;
		resetSAR = 0;
		setComplete = 0;
		clearComplete = 0;

		case (state)
			IDLE: begin
				resetWait = 1;
				next = strt_cnv ? INIT : IDLE;
			end

			INIT: begin
				clearComplete = 1;
				decWait = 1;
				resetSAR = 1;
				next = stableWait == 0 ? STABILIZE : INIT;
			end

			STABILIZE: begin
				decWait = 1;
				next = stableWait == 0 ? CALC : STABILIZE;
			end

			CALC: begin
				decWait = 1;
				nextBit = 1;
				setComplete = nextMask == 0;
				next = nextMask == 0 ? IDLE : STABILIZE;
			end
		endcase
	end
endmodule
