/*
 * Module Name: substitution_layer
 * Author(s): Arthur Sabadini, Kevin Duong, Kiet Le
 * Description: The substitution layer applies a 5-bit nonlinear S-box in bit-sliced form across the entire state.
 *              This layer provides the "confusion" property to secure the state against linear analysis.
 * Ref: NIST SP 800-232
 */

`timescale 1ns / 1ps

import lascon_pkg::*;

module substitution_layer #(
    parameter int SBOX_WIDTH = 64
)(
    input   logic [4:0][SBOX_WIDTH-1:0] state_chunk_i,
    output  logic [4:0][SBOX_WIDTH-1:0] state_chunk_o
);

    // ----------------------------------------------------------------------
    // Parallel S-box Application via Boolean Logic
    // ----------------------------------------------------------------------
    // Implements Ascon S-box using Boolean equations from NIST SP 800-232 Section 3.3.
    // This utilizes logical gates directly instead of relying on LUT inference.
    generate
        for (genvar j = 0; j < SBOX_WIDTH; j++) begin : gen_sbox_loop
            logic x0, x1, x2, x3, x4;
            logic t0, t1, t2, t3, t4;
            logic y0, y1, y2, y3, y4;

            assign x0 = state_chunk_i[0][j] ^ state_chunk_i[4][j];
            assign x1 = state_chunk_i[1][j];
            assign x2 = state_chunk_i[2][j] ^ state_chunk_i[1][j];
            assign x3 = state_chunk_i[3][j];
            assign x4 = state_chunk_i[4][j] ^ state_chunk_i[3][j];

            assign t0 = ~x0;
            assign t1 = ~x1;
            assign t2 = ~x2;
            assign t3 = ~x3;
            assign t4 = ~x4;

            assign y0 = x0 ^ (t1 & x2);
            assign y1 = x1 ^ (t2 & x3);
            assign y2 = x2 ^ (t3 & x4);
            assign y3 = x3 ^ (t4 & x0);
            assign y4 = x4 ^ (t0 & x1);

            assign state_chunk_o[0][j] = y0 ^ y4;
            assign state_chunk_o[1][j] = y1 ^ y0;
            assign state_chunk_o[2][j] = ~y2;
            assign state_chunk_o[3][j] = y3 ^ y2;
            assign state_chunk_o[4][j] = y4;
        end
    endgenerate

endmodule
