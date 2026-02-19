/*
 * Package Name: permutations_sim
 * Author: Arthur Sabadini, Kevin Duong, Tirth Patel, Artin Kiany, Sasha Calmels
 * Description: Functions used to simulate the output of each permutation  
 * Ref: NIST SP 800-232
 */

import ascon_pkg::*;

package permutations_sim_pkg;

    // 16-entry LUT, each entry is 8 bit round constant
    localparam logic [7:0] ConstAddLUT [16] = '{
        8'h3c, // i=0
        8'h2d, // i=1
        8'h1e, // i=2
        8'h0f, // i=3
        8'hf0, // i=4
        8'he1, // i=5
        8'hd2, // i=6
        8'hc3, // i=7
        8'hb4, // i=8
        8'ha5, // i=9
        8'h96, // i=10
        8'h87, // i=11
        8'h78, // i=12
        8'h69, // i=13
        8'h5a, // i=14
        8'h4b  // i=15
    };

    // Will have to change once const_addtion_layer is fixed
    function automatic ascon_state_t addition(
        input ascon_state_t state_array_i,
        input rnd_t rnd
    );

        ascon_state_t state_array_o;
        begin
            state_array_o = state_array_i;
            state_array_o[2] = state_array_o[2] ^ ConstAddLUT[rnd];

            return state_array_o;
        end

    endfunction

    //This is meant to be the expected output, we can use to compare
    //the results from sbox_eq function to our actual implementation substitution_layer.sv
    function automatic ascon_state_t substitution(
        input ascon_state_t x
    );

        ascon_state_t y;
        begin
            for(int j =0; j < WORD_WIDTH; j++) begin
                y[0][j] = (x[4][j] & x[1][j]) ^ x[3][j] ^ (x[2][j] & x[1][j]) ^ x[2][j] ^ (x[1][j] & x[0][j]) ^ x[1][j] ^ x[0][j];
                y[1][j] = x[4][j] ^ (x[3][j] & x[2][j]) ^ (x[3][j] & x[1][j]) ^ x[3][j] ^ (x[2][j] & x[1][j]) ^ x[2][j] ^ x[1][j]^ x[0][j];
                y[2][j] = (x[4][j] & x[3][j]) ^ x[4][j] ^ x[2][j] ^ x[1][j] ^ 1'b1;
                y[3][j] = (x[4][j] & x[0][j]) ^ x[4][j] ^ (x[3][j] & x[0][j]) ^ x[3][j] ^ x[2][j] ^ x[1][j] ^ x[0][j];
                y[4][j] = (x[4][j] & x[1][j]) ^ x[4][j] ^ x[3][j] ^ (x[1][j] & x[0][j]) ^ x[1][j];
            end

            return y;
        end
    endfunction

    // reference model: Right Circular Rotation (ROR). The corrcet behaviour of the Layer

    function automatic logic [63:0] ror64(input logic [63:0] data, input int shift);
        return (data >> shift) | (data << (64 - shift));
    endfunction

    // Compute expected output using the Ascon Sigma functions
    function automatic ascon_state_t diffution(
        input  ascon_state_t in_state
    );
        int r_a [5]; //rotation a
        int r_b [5]; //rotation b
        ascon_state_t out_state;

        r_a[0] = 19;
        r_a[1] = 61;
        r_a[2] = 1;
        r_a[3] = 10;
        r_a[4] = 7;  // word rotation 1 from ascon pdf

        r_b[0] = 28;
        r_b[1] = 39;
        r_b[2] = 6;
        r_b[3] = 17;
        r_b[4] = 41; // word rotation 2 from ascon pdf

        for (int i = 0; i < 5; i++) begin
            out_state[i] = in_state[i] ^ ror64(in_state[i], r_a[i]) ^ ror64(in_state[i], r_b[i]);
        end

        return out_state;
    endfunction

endpackage : permutations_sim_pkg

