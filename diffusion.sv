module diffusion(
	input logic [319:0] state,

	output logic [319:0] diffused
);

	localparam int WORD_SIZE = 64;

	logic [63:0] s0, s1, s2, s3, s4;

	assign s0 = state[ 63:  0];
	assign s1 = state[127: 64];
	assign s2 = state[191:128];
	assign s3 = state[255:192];
	assign s4 = state[319:256];
	
	logic [63:0] s0_d, s1_d, s2_d, s3_d, s4_d;
	
	always_comb begin

		s0_d = s0 ^ ((s0 >> 19) | (s0 << (WORD_SIZE - 19))) ^ ((s0 >> 28) | (s0 << (WORD_SIZE - 28)));
		s1_d = s1 ^ ((s1 >> 61) | (s1 << (WORD_SIZE - 61))) ^ ((s1 >> 39) | (s1 << ( WORD_SIZE- 39)));
		s2_d = s2 ^ ((s2 >> 1)  | (s2 << (WORD_SIZE - 1)))  ^ ((s2 >> 6)  | (s2 << ( WORD_SIZE- 6)));
		s3_d = s3 ^ ((s3 >> 10) | (s3 << (WORD_SIZE - 10))) ^ ((s3 >> 17) | (s3 << ( WORD_SIZE- 17)));
		s4_d = s4 ^ ((s4 >> 7)  | (s4 << (WORD_SIZE - 7)))  ^ ((s4 >> 41) | (s4 << ( WORD_SIZE- 41)));
	
	end

	assign diffused = {s4_d, s3_d, s2_d, s1_d, s0_d};


endmodule : diffusion
