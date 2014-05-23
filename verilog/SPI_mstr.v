`timescale 1 ns / 1 ps;
module SPI_mstr(clk,rst_n,SS_n,SCLK,MISO,wrt_cmd, cmd, done,resp, MOSI);

  input clk,rst_n,wrt_cmd,MISO;
  input [15:0] cmd;
  output SS_n,SCLK,done, MOSI;
  output reg [15:0] resp;			// parallel data of MISO

  reg [1:0] state,nstate;
  reg [9:0] pause_cntr;
  reg [4:0] bit_cntr;
  reg done;
  reg SS_n;

  reg rst_cnt,en_cnt,shft;

  localparam IDLE = 2'b00;
  localparam BITS = 2'b01;
  localparam TRAIL = 2'b10;

  ///////////////////////////////
  // Implement state register //
  /////////////////////////////
  always @(posedge clk, negedge rst_n)
    if (!rst_n)
      state <= IDLE;
    else
      state <= nstate;

  ////////////////////////////
  // Implement bit counter //
  //////////////////////////
  always @(posedge clk)
    if (rst_cnt)
      bit_cntr <= 5'b00000;
    else if (en_cnt)
      bit_cntr <= bit_cntr + 1;

  //////////////////////////////
  // Implement pause counter //
  ////////////////////////////
  always @(posedge clk)
    if (rst_cnt)
      pause_cntr <= 10'h1EE;
    else
      pause_cntr <= pause_cntr + 1;

  assign SCLK = pause_cntr[9];

  //////////////////////////////////////
  // resp is shifted on fall of SCLK //
  ////////////////////////////////////
  always @(posedge clk)
	 if(!rst_n)
		resp <= 0;
	 else if (wrt_cmd)
      resp <= cmd;
    else if (shft)
      resp <= {resp[14:0],MISO}; //Shift in the data from slave
	

  ////////////////////////////////////////
  // Implement SM that controls output //
  //////////////////////////////////////
  always @(state, wrt_cmd, pause_cntr)
    begin
      //////////////////////
      // Default outputs //
      ////////////////////
      rst_cnt = 0; 
      SS_n = 1;
      en_cnt = 0;
      shft = 0;
      done = 0;

      case (state)
        IDLE : begin
          rst_cnt = 1;
          if (wrt_cmd) 
            begin
              SS_n = 0;
              nstate = BITS;
            end
          else nstate = IDLE;
        end
        BITS : begin
          ////////////////////////////////////
          // For the 16 bits of the packet //
          //////////////////////////////////
          SS_n = 0;
          en_cnt = &pause_cntr;
          shft = en_cnt;
          if (bit_cntr==5'h10) 
            begin
              rst_cnt = 1;
              nstate = TRAIL;
            end
          else
            nstate = BITS;         
        end
        default : begin 	// this is TRAIL state
          //////////////////////////////////////////
          // This state keeps SS_n low till 16   //
          // clocks after the last fall of SCLK //
          ///////////////////////////////////////
          SS_n = 0;
          en_cnt = 1;
          if (bit_cntr==5'h10)
            begin
              done = 1;
              nstate = IDLE;
            end
        end
      endcase
    end
	 ///// MOSI is resp[15] with a tri-state ///////////
  	 assign MOSI = (SS_n) ? 1'bz : resp[15];

endmodule 
