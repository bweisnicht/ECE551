//Module to multiply two numbers using booth encoding
module mult(clk, rst_n, multiplier, multiplicand, result, done, strt_mult);
	input clk, rst_n, strt_mult;
	input [11:0] multiplier, multiplicand;
	output reg done;
	output [23:0] result;

	reg [24:0] p_reg; //upper 12 bits 0, lower 12 bits multiplier
	reg ld;
	wire add, sub;
	reg shft, nxt;
	//Algorithm:
	//All shifts are ASR
	//Look at the two lsbs of multiplier
	//Case 0 1: Add multiplacnd to product and shift
	//Case 1 0: Subtract multiplicand from producty and shift

	localparam IDLE = 1'b0;
	localparam MULT = 1'b1;
	reg state, nxt_state;
	always@(posedge clk, negedge rst_n)
		if(!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;

	wire [24:0] multiplicand_comp = ~(multiplicand) + 1;
	wire [24:0]	arit;

	always@(posedge clk, negedge rst_n)
		if(!rst_n)
			p_reg <= 0;
		else if(ld)
			p_reg <= {{12{1'b0}},{multiplier,1'b0}};
		else if(shft) begin
			if(sub || add)
				p_reg <= {arit[24], {arit[24:1]}};
			else
				p_reg <= {p_reg[24], {p_reg[24:1]}};
		end

	assign arit = sub ? {p_reg[24:13] + multiplicand_comp, p_reg[12:0]} :
						add ? {p_reg[24:13] + multiplicand, p_reg[12:0]} : 0;

	//Counter that counts the 12 cycles
	reg [3:0] count;
	reg rst_count;
	always@(posedge clk)
		if(rst_count)
			count <= 0;
		else
			count <= count + 1;

	assign count_eq_12 = (count == 4'b1101);

	assign sub = (p_reg[1] & ~p_reg[0]);
	assign add = (~p_reg[1] & p_reg[0]);
	always@(state, strt_mult, count_eq_12) begin
		nxt_state = IDLE;
		rst_count = 0;
		ld = 0;
		shft = 0;
		done = 0;
		case(state)
			IDLE: begin
				rst_count = 1;
				done = 1;
				if(strt_mult) begin
					rst_count = 0;
					ld = 1;
					nxt_state = MULT;
				end
			end
			MULT: begin
				nxt_state = MULT;
				shft = 1;
				if(count_eq_12) begin//How to set done signal?	Synchronize with clock
					done = 1;
					nxt_state = IDLE;
					shft = 0;
				end
			end
		endcase
	end
	assign result = p_reg[23:1];
endmodule
