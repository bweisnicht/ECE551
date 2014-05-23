`timescale 1ns/100ps
module A2D_tb();
	reg clk, rst_n, strt_cnv;
	reg  [11:0] ana_sin, ana_cos; // "Analog" values to feed A2D_analog
	wire gt_sin, gt_cos, smpl; // Connections between the analog and digital components that we don't read
	// Outputs we care about
	wire [11:0] cosSAR, sinSAR;
	wire cnv_cmplt;

	A2D_analog analog(.cosSAR(cosSAR), .sinSAR(sinSAR), .ana_cos(ana_cos), .ana_sin(ana_sin), .smpl(smpl),
	                  .gt_cos(gt_cos), .gt_sin(gt_sin));
	A2D_digital DUT(.clk(clk), .rst_n(rst_n), .gt_sin(gt_sin), .gt_cos(gt_cos), .strt_cnv(strt_cnv),
	                .sinSAR(sinSAR), .cosSAR(cosSAR), .smpl(smpl), .cnv_cmplt(cnv_cmplt));

	// Test values
	reg [23:0] vals[0:2047];
	integer signed testsRun;

	initial begin
		// Reset everything and load our test signals
		$readmemh("A2D_vals.txt", vals);
		testsRun = 0;
		clk = 1'b0;
		rst_n = 0;
		strt_cnv = 0;
		#1;
		// Set our initial values and raise the start signal
		rst_n = 1;
		ana_cos = vals[0][23:12];
		ana_sin = vals[0][11:0];
		strt_cnv = 1;
		#2
		strt_cnv = 0;
		// And we're off!
	end

	always @(posedge cnv_cmplt) begin
		testsRun = testsRun + 1;
		if (testsRun == 2048) begin
			$display("SUCCESS");
			$finish;
		end
		else begin
			if (cosSAR !== ana_cos || sinSAR !== ana_sin) begin
				$display("ERROR: Expected: %h, %h, Got: %h, %h", ana_cos, ana_sin, cosSAR, sinSAR);
				$finish;
			end
			ana_cos = vals[testsRun][23:12];
			ana_sin = vals[testsRun][11:0];
			strt_cnv = 1;
			#5;
			strt_cnv = 0;
		end
	end

	always begin
		#2;
		clk = ~clk;
	end
endmodule
