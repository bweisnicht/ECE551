`timescale 1ns/1ps
module car_dig_tb();
// `include "/filespace/people/s/skodje/ece551/ece551-final/verilog/tb_tasks.v"

////////////////////////////////////////////////
// Define any interconnects wider than 1-bit //
//////////////////////////////////////////////
wire [1:0] eep_addr;
wire [11:0] eep_rd_data;
wire [11:0] dst,cosSAR,sinSAR;
wire [11:0] ana_cos,ana_sin;
wire [15:0] resp; 		// response from DUT

/////////////////////////////////////////////
// Define any registers used in testbench //
///////////////////////////////////////////
reg [15:0] cmd;			// connected to cmd of master SPI
reg wrt_cmd;			// connected to wrt of master SPI
reg clk,rst_n;

//////////////////////
// Instantiate DUT //
////////////////////
car_dig_vg DUT(.clk(clk), .rst_n(rst_n), .gt_sin(gt_sin), .gt_cos(gt_cos), .sinSAR(sinSAR), .cosSAR(cosSAR), .smpl(smpl),
            .SCLK(SCLK), .SS_n(SS_n), .MISO(MISO), .MOSI(MOSI), .eep_addr(eep_addr), .eep_cs_n(eep_cs_n),
            .eep_r_w_n(eep_r_w_n), .eep_rd_data(eep_rd_data), .dst(dst), .chrg_pmp_en(chrg_pmp_en), .RDY(RDY));


///////////////////////////////
// Instantiate EEPROM Model //
/////////////////////////////
eep iEEP(.clk(clk), .por_n(rst_n), .eep_addr(eep_addr), .wrt_data(dst),  .rd_data(eep_rd_data), .eep_cs_n(eep_cs_n),
         .eep_r_w_n(eep_r_w_n), .chrg_pmp_en(chrg_pmp_en));

///////////////////////////////////
// Instantiate A2D analog model //
/////////////////////////////////
A2D_analog iAna(.cosSAR(cosSAR), .sinSAR(sinSAR), .ana_cos(ana_cos), .ana_sin(ana_sin), .smpl(smpl),
                .gt_cos(gt_cos), .gt_sin(gt_sin));

//////////////////////////////////////////////////////////////
// Instantiate sequencer to read and apply analog_vals.txt //
////////////////////////////////////////////////////////////
A2D_sequencer iSEQ(.smpl(smpl), .ana_cos(ana_cos), .ana_sin(ana_sin));


/////////////////////////////
// Instantiate Master SPI //
///////////////////////////
SPI_mstr iMaster(.clk(clk), .rst_n(rst_n), .wrt_cmd(wrt_cmd), .cmd(cmd), .done(done),
                .resp(resp), .SCLK(SCLK), .SS_n(SS_n), .MISO(MISO), .MOSI(MOSI));

initial clk = 0;
always
  ///////////////////
  // 500MHz clock //
  /////////////////
  #1 clk = ~clk;


/////////////////////////////////////////////////////////////////
// The following section actually implements the real testing //
///////////////////////////////////////////////////////////////
initial
  begin
	//////////////////////////////////
	// Implement your testing here //
	////////////////////////////////
	cmd = 0;
	rst_n = 0;
	wrt_cmd = 0;
	#50;
	@(posedge clk);
	@(negedge clk)
	rst_n = 1;

	// Testing enter command mode
	@(posedge clk);
	cmd = 16'b0110_0000_0000_0000;
	@(posedge clk);
	wrt_cmd = 1;
	$display("Testing enter cmd mode.");
	#8;
	@(posedge clk);
	wrt_cmd = 0;	
	wait(RDY == 1) 
		$display("Command mode set!");

	// Tesing unlock eeprom
	@(posedge clk);
	cmd = 16'b0111_0000_0000_0000;
	wrt_cmd = 1;
	$display("Testing unlock EEProm");
	#8;
	@(posedge clk);
	wrt_cmd = 0;
	wait(resp == 16'h0A5A) begin
		$display("resp correct for previous test: testing enter command mode");
	end
	wait(RDY == 1) begin
		$display("EEProm unlocked");
	end

	// Testing a write
	@(posedge clk);
	cmd = 16'b1100_0011_0110_1100;
	wrt_cmd = 1;
	$display("Testing Write at address 0");
	#8;
	@(posedge clk);
	wrt_cmd = 0;
	wait(resp == 16'h0A5A) begin
		$display("resp correct for unlock EEPROM");
	end
	wait(iEEP.eep_mem[0] == 12'h36C) begin
		$display("Write success");
	end
	wait(RDY == 1) begin
		$display("Write done");
	end

	// Testing read at address 0
	@(posedge clk);
	cmd = 16'b1000_0000_0000_0000;
	wrt_cmd = 1;
	$display("Testing Read");
	#8;
	@(posedge clk);
	wrt_cmd = 0;
 	wait(resp == 16'h0A5A) begin
		$display("resp correct for write");
	end
	wait(RDY == 1) begin
		$display("Read done");
	end
	
	// Unlock eeprom for another write to address 2
	@(posedge clk);
	cmd = 16'b0111_0000_0000_0000;
	wrt_cmd = 1;
	$display("Testing unlock EEProm");
	#8;
	@(posedge clk);
	wrt_cmd = 0;
	wait(resp == 16'h036C) begin
		$display("resp correct for write at address 0");
	end
	wait(RDY == 1) begin
		$display("EEProm unlocked");
	end

	// Testing a write at address 2
	@(posedge clk);
	cmd = 16'b1110_0110_1100_0011;
	wrt_cmd = 1;
	$display("Testing Write at address 2");
	#8;
	@(posedge clk);
	wrt_cmd = 0;
	wait(resp == 16'h0A5A) begin
		$display("resp correct for write at address zero");
	end
	wait(RDY == 1) begin
		$display("Write success");
	end

	// Unlock eeprom for another write to address 1
	@(posedge clk);
	cmd = 16'b0111_0000_0000_0000;
	wrt_cmd = 1;
	$display("Testing unlock EEProm");
	#8;
	@(posedge clk);
	wrt_cmd = 0;
	wait(resp == 16'h0A5A) begin
		$display("resp correct for write at address 0");
	end
	wait(RDY == 1) begin
		$display("EEProm unlocked");
	end

	// Testing a write at address 1
	@(posedge clk);
	cmd = 16'b1101_0000_1100_1100;
	wrt_cmd = 1;
	$display("Testing Write at address 1");
	#8;
	@(posedge clk);
	wrt_cmd = 0;
	wait(resp == 16'h0A5A) begin
		$display("resp correct for write at address 2");
	end
	wait(iEEP.eep_mem[1] == 12'h0CC) begin
		$display("Write success");
	end
	wait(RDY == 1) begin
		$display("Write done");	
	end

	// Unlock eeprom for another write to address 3	
	@(posedge clk);
	cmd = 16'b0111_0000_0000_0000;
	wrt_cmd = 1;
	$display("Testing unlock EEProm");
	#8;
	@(posedge clk);
	wrt_cmd = 0;
	wait(resp == 16'h0A5A) begin
		$display("resp correct for write at address 0");
	end
	wait(RDY == 1) begin
		$display("EEProm unlocked");
	end

	// Testing a write at address 3
	@(posedge clk);
	cmd = 16'b1111_0110_0110_0110;
	wrt_cmd = 1;
	$display("Testing Write at address 3");
	#8;
	@(posedge clk);
	wrt_cmd = 0;
	wait(resp == 16'h0A5A) begin
		$display("resp correct for write at address 1");
	end
	wait(iEEP.eep_mem[3] == 12'h666) begin
		$display("Write success");
	end
	wait(RDY == 1) begin
		$display("Write command awknowledged");
	end

	//Testing Sin_Corr read
	@(posedge clk);
	cmd = 16'b0100_0000_0000_0000;
	wrt_cmd = 1;
	$display("Testing Sin_Corr Read");
	#20;
	@(posedge clk);
	wrt_cmd = 0;
	wait(resp == 16'h0A5A) begin
		$display("resp correct for write at address 3");
	end
	wait(dst == 16'h00cb) begin
		$display("resp correct for Sin_Corr read");
	end
	wait(RDY)
 
 
 
	//Testing Cos_Corr read
	@(posedge clk);
	cmd = 16'b0101_0000_0000_0000;
	wrt_cmd = 1;
	$display("Testing Cos_Corr Read");
	#20;
	@(posedge clk);
	wrt_cmd = 0;
	wait(dst == 16'h0665) begin
		$display("resp correct for Cos_Corr read");
	end
	wait(RDY)

	//Cordic test
	// First reset to get out of command mode
	
	rst_n = 0;
	#20; 
	@(posedge clk);
	@(negedge clk);
	rst_n = 1;
	
	wait(RDY)
	$display("Result: %d. SinSAR: %d. CosSAR: %d", dst, sinSAR, cosSAR);


	$display("COMMAND TEST SUCCESS!");

	$finish;

	end


endmodule
