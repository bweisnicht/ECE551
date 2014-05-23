// Double-flops an input to prevent metastability issues
module dflop(clk, rst_n, in, out);
	input clk, rst_n, in;
	output out;

	reg flops[0:1];

	assign out = flops[1];

	always @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			flops[0] <= 0;
			flops[1] <= 0;
		end
		else begin
			flops[0] <= in;
			flops[1] <= flops[0];
		end
	end
endmodule
