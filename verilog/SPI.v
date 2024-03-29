module SPI(clk,rst_n,tx_data,wrt,SCLK,MISO, SS_n, MOSI, cmd_rcvd, cmd_rdy, rsp_rdy);

  input clk,rst_n,SS_n,SCLK,wrt, MOSI;
  input [15:0] tx_data;

  output MISO;
  output reg cmd_rdy, rsp_rdy;
  output reg [15:0] cmd_rcvd;

  reg [15:0] buffer;
  reg state,nstate;
  reg shft,ld;
  reg SCLK_ff1,SCLK_ff2,SCLK_ff3,SS_n_ff1,SS_n_ff2, MOSI_ff1, MOSI_ff2, MOSI_ff3;

  wire negSCLK;

  localparam IDLE = 1'b0;
  localparam TX   = 1'b1;

  ///////////////////////////////////////////
  // write is double buffered...meaning   //
  // our core can write to SPI output    //
  // while read of previous in progress //
  ///////////////////////////////////////
  always @(posedge clk, negedge rst_n)
	 if (!rst_n)
		buffer <= 0;
    else if (wrt)
      buffer <= tx_data;

  /////////////////////////////////////
  // create parallel shift register //
  ///////////////////////////////////
  always @(posedge clk, negedge rst_n)
	 if (!rst_n)
		cmd_rcvd <= 0;
    else if (ld)
      cmd_rcvd <= buffer;
    else if (shft)
      cmd_rcvd <= {cmd_rcvd[14:0],MOSI_ff3};

  ////////////////////////////////////////////////////////////
  // double flop SCLK and SS_n for meta-stability purposes //
  ////////////////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n)
    if (!rst_n)
      begin
        SCLK_ff1 <= 1'b0;
        SCLK_ff2 <= 1'b0;
        SCLK_ff3 <= 1'b0;
        SS_n_ff1 <= 1'b1;
        SS_n_ff2 <= 1'b1;
      end
    else
      begin
        SCLK_ff1 <= SCLK; 
        SCLK_ff2 <= SCLK_ff1;
        SCLK_ff3 <= SCLK_ff2;
        SS_n_ff1 <= SS_n;
        SS_n_ff2 <= SS_n_ff1; 
      end

  //Triple flop MOSI to synchronize with negedge of SCLK
  always@(posedge clk, negedge rst_n)
 	 if(!rst_n) begin
		MOSI_ff1 <= 1'b0;
		MOSI_ff2 <= 1'b0;
		MOSI_ff3 <= 1'b0;
	 end
    else begin
		MOSI_ff1 <= MOSI;
		MOSI_ff2 <= MOSI_ff1;
		MOSI_ff3 <= MOSI_ff2;
	 end
	    

  /////////////////////////////////
  // handle the rsp ready signal //
  /////////////////////////////////
  always@(posedge clk or negedge rst_n)
  	if(!rst_n)
		rsp_rdy <= 0;
	else if(wrt)
		rsp_rdy <= 1;
	else if(ld)
		rsp_rdy <= 0;

	///////////////////////////////
	// Handle cmd_ready signal ///
	/////////////////////////////
	always@(posedge clk)
	  if(SS_n_ff2)
		 cmd_rdy <= 1;
	  else
		 cmd_rdy <= 0;

  ///////////////////////////////
  // Implement state register //
  /////////////////////////////
  always @(posedge clk or negedge rst_n)
    if (!rst_n)
      state <= IDLE;
    else
      state <= nstate;
     
  ///////////////////////////////////////
  // Implement state tranisiton logic //
  /////////////////////////////////////
  always @(state,SS_n_ff2,negSCLK)
    begin
      //////////////////////
      // Default outputs //
      ////////////////////
      shft = 0;
      ld = 0;
      /////////////////////////////
      // State transition logic //
      ///////////////////////////
      case (state)
        IDLE : begin
          ld = !SS_n_ff2; //Loaded when a read is initiated
          if (!SS_n_ff2)
            nstate = TX;
          else nstate = IDLE;
        end
        TX : begin
          shft = negSCLK;
          if (SS_n_ff2) nstate = IDLE;
          else nstate = TX;
        end
      endcase
    end
  
  /////////////////////////////////////////////////////
  // If SCLK_ff3 is still high, but SCLK_ff2 is low //
  // then a negative edge of SCLK has occurred.    //
  //////////////////////////////////////////////////
  assign negSCLK = ~SCLK_ff2 && SCLK_ff3;
  ///// MISO is shift_reg[15] with a tri-state ///////////
  assign MISO = (SS_n_ff2) ? 1'bz : cmd_rcvd[15];

endmodule
