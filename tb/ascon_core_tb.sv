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

    // Test note: DUT Permutation instances will have the correct values 
    // as soon as rnd_cnt = 0. On the next clk cycle the values will change,
    // as data_o will be updated.

    // Clock generation
    always #5 clk = ~clk;

    // ----------------------------
    // Timing Verification
    // ----------------------------

    property not_ready_on_start;
        @(posedge clk)
        start_perm_i |-> !ready_o;
    endproperty

    property data_stable_when_ready;
        @(posedge clk)
        ready_o |-> $stable(data_o);
    endproperty

    property write_successful_on_idle;
        @(posedge clk)
        ((dut.state == STATE_IDLE) & write_en_i & !xor_en_i) |-> (dut.state_array[word_sel_i] == data_i);
    endproperty

    property xor_write_sucessful_on_idle;
        @(posedge clk)
        ((dut.state == STATE_IDLE) & write_en_i & xor_en_i) |-> (
            dut.state_array[word_sel_i] == dut.state_array[word_sel_i] ^ data_i
        );
    endproperty

    // ----------------------------
    // Properties Assertions 
    // ----------------------------

    assert property (data_stable_when_ready);
    assert property (not_ready_on_start);
    assert property (write_successful_on_idle);
    assert property (xor_write_successful_on_idle);

endmodule
