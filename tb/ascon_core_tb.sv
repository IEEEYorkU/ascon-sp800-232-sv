/*
 * Module Name: ascon_core_tb.sv
 * Aurthor(s): Arthur Sabadini
 * Description: Testbench for ascon_core.sv
 *
 */

`timescale 1ns/1ps

import ascon_pkg::*;

module ascon_core_tb;

    // ----------------------------
    // Input and Output Signals
    // ----------------------------
    logic clk = 0, rst = 0;

    // Permutation Control
    logic           start_perm_i;
    logic           round_config_i;

    // Read/Write Word Address
    logic [2:0]     word_sel_i;

    // Data I/O Control
    ascon_word_t    data_i;
    logic           write_en_i;
    logic           xor_en_i;

    // Data Output (according to word_sel_i)
    ascon_word_t    data_o;

    // Permutation Complete
    logic           ready_o;

    // ----------------------------
    // Test signal
    // ----------------------------
    ascon_word_t test_data_i;

    ascon_core dut(
        .clk(clk), .rst(rst),
        .start_perm_i(start_perm_i),
        .round_config_o(round_config_i),
        .word_sel_i(word_sel_i),
        .data_i(data_i),
        .write_en_i(write_en_i),
        .xor_en_i(xor_en_i),
        .data_o(data_o),
        .ready_o(ready_o)
    );

endmodule
