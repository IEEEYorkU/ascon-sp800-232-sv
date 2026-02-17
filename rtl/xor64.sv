module xor64 (
    input   ascon_word_t    op1,
    input   ascon_word_t    op2,
    output  ascon_word_t    res_o
);

    assign res_o = op1 ^ op2;

endmodule
