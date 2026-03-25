`timescale 1ns / 1ps

import ascon_pkg::*;

module xor64 (
    input   ascon_word_t    op1_i,
    input   ascon_word_t    op2_i,
    output  ascon_word_t    res_o
);

    assign res_o = op1_i ^ op2_i;

endmodule
