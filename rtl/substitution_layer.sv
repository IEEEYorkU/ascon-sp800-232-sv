/*
 * Module Name: substitution_layer
 * Author(s): Arthur Sabadini, Kevin Duong
 * Description: The substitution layer applies a 5-bit nonlinear S-box in bit-sliced form across the entire state.
 * This layer provides the "confusion" property to secure the state against linear analysis.
 * Ref: NIST SP 800-232
 */

module substitution_layer (
    input   ascon_pkg::ascon_state_t   state_array_i,
    output  ascon_pkg::ascon_state_t   state_array_o
);

    // ----------------------------------------------------------------------
    // S-box Function (Bulletproof for Synthesis)
    // ----------------------------------------------------------------------
    function automatic logic [4:0] apply_sbox(input logic [4:0] val);
        case (val)
            5'd0:  apply_sbox = 5'h4;
            5'd1:  apply_sbox = 5'hb;
            5'd2:  apply_sbox = 5'h1f;
            5'd3:  apply_sbox = 5'h14;
            5'd4:  apply_sbox = 5'h1a;
            5'd5:  apply_sbox = 5'h15;
            5'd6:  apply_sbox = 5'h9;
            5'd7:  apply_sbox = 5'h2;
            5'd8:  apply_sbox = 5'h1b;
            5'd9:  apply_sbox = 5'h5;
            5'd10: apply_sbox = 5'h8;
            5'd11: apply_sbox = 5'h12;
            5'd12: apply_sbox = 5'h1d;
            5'd13: apply_sbox = 5'h3;
            5'd14: apply_sbox = 5'h6;
            5'd15: apply_sbox = 5'h1c;
            5'd16: apply_sbox = 5'h1e;
            5'd17: apply_sbox = 5'h13;
            5'd18: apply_sbox = 5'h7;
            5'd19: apply_sbox = 5'he;
            5'd20: apply_sbox = 5'h0;
            5'd21: apply_sbox = 5'hd;
            5'd22: apply_sbox = 5'h11;
            5'd23: apply_sbox = 5'h18;
            5'd24: apply_sbox = 5'h10;
            5'd25: apply_sbox = 5'hc;
            5'd26: apply_sbox = 5'h1;
            5'd27: apply_sbox = 5'h19;
            5'd28: apply_sbox = 5'h16;
            5'd29: apply_sbox = 5'ha;
            5'd30: apply_sbox = 5'hf;
            5'd31: apply_sbox = 5'h17;
            default: apply_sbox = 5'h0;
        endcase
    endfunction

    // ----------------------------------------------------------------------
    // Parallel S-box Application
    // ----------------------------------------------------------------------
    always_comb begin
        logic [4:0] slice_in;
        logic [4:0] slice_out;

        // 1. Flatten the 2D packed arrays into 1D vectors to avoid Yosys AST crashes
        logic [ascon_pkg::WORD_WIDTH-1:0] s0_in, s1_in, s2_in, s3_in, s4_in;
        logic [ascon_pkg::WORD_WIDTH-1:0] s0_out, s1_out, s2_out, s3_out, s4_out;

        s0_in = state_array_i[0];
        s1_in = state_array_i[1];
        s2_in = state_array_i[2];
        s3_in = state_array_i[3];
        s4_in = state_array_i[4];

        // 2. Loop over the 1D vectors (Yosys handles this perfectly)
        for (integer j = 0; j < ascon_pkg::WORD_WIDTH; j = j + 1) begin
            slice_in[4] = s0_in[j];
            slice_in[3] = s1_in[j];
            slice_in[2] = s2_in[j];
            slice_in[1] = s3_in[j];
            slice_in[0] = s4_in[j];

            slice_out = apply_sbox(slice_in);

            s0_out[j] = slice_out[4];
            s1_out[j] = slice_out[3];
            s2_out[j] = slice_out[2];
            s3_out[j] = slice_out[1];
            s4_out[j] = slice_out[0];
        end

        // 3. Pack the 1D vectors back into the 2D output array
        state_array_o[0] = s0_out;
        state_array_o[1] = s1_out;
        state_array_o[2] = s2_out;
        state_array_o[3] = s3_out;
        state_array_o[4] = s4_out;
    end

endmodule
