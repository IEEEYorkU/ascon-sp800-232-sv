/*
 * Module Name: ascon_core
 * Author(s): Kiet Le
 * Description:
 *
 */

import ascon_pkg::*;

module ascon_core (
    input   logic           clk,
    input   logic           rst,

    // Permutation Control
    input   logic           start_perm_i,
    input   logic           round_config_i,

    // Read/Write Word Address
    input   logic [2:0]     word_sel_i,

    // Data I/O Control
    input   ascon_word_t    data_i,
    input   logic           write_en_i,
    input   logic           xor_en_i,

    // Data Output (according to word_sel_i)
    output  ascon_word_t    data_o,

    // Permutation Complete
    output  logic           ready_o
);

endmodule
