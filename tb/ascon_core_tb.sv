/*
 * Module Name: ascon_core_tb.sv
 * Aurthor(s): Arthur Sabadini
 * Description: Testbench for ascon_core.sv
 *
 */

`timescale 1ns/1ps

import ascon_pkg::*;
import permutations_sim_pkg::*;

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
    ascon_word_t test_data_o;
    ascon_state_t state_data_o;

    ascon_core dut(
        .clk(clk), .rst(rst),
        .start_perm_i(start_perm_i),
        .round_config_i(round_config_i),
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
    always #1 clk = ~clk;

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
        ((dut.state == 1'b0) & write_en_i & !xor_en_i) |-> (dut.state_array[word_sel_i] == data_i);
    endproperty

    property xor_write_sucessful_on_idle;
        @(posedge clk)
        ((dut.state == 1'b0) & write_en_i & xor_en_i) |-> (
            dut.state_array[word_sel_i] == dut.state_array[word_sel_i] ^ data_i
        );
    endproperty

    // ----------------------------
    // Properties Assertions
    // ----------------------------

    assert property (data_stable_when_ready);
    assert property (not_ready_on_start);
    assert property (write_successful_on_idle);
    assert property (xor_write_sucessful_on_idle);

    // ----------------------------
    // Task Definitions
    // ----------------------------

    // Checks if output state is expected
    task automatic check_core_output(
        input ascon_state_t state_exp,
        input ascon_state_t state_o
    );
        assert(
            state_o == state_exp
        )
            $display("Sucess. State out is State Expected.");
        else
            $error("Failed. State out is Incorrect.");
    endtask

    // ----------------------------
    // Tests Begin
    // ----------------------------

    integer max_tests = 10;

    initial begin
        // Initialize
        rst = 0;
        start_perm_i = 0;
        round_config_i = 0;
        word_sel_i = 3'd0;
        write_en_i = 0;
        xor_en_i = 0;
        data_i = 320'd0;

        // Exhaustive Tests
        $display("Exhaustive Random Input Test...");
        round_config_i = 1'd1;
        for (int i = 0; i < max_tests; i++) begin
            #2;
            // Generating random input
            rand_array(test_data_i);
            test_data_o = ascon_perm(round_config_i, test_data_i);

            // Writting input
            for(word_sel_i = 0; word_sel_i < NUM_WORDS; word_sel_i++) begin
                #4;
                data_i = test_data_i[word_sel_i];    // Word to be written
                write_en_i = 1;                      // Enable write
                #4;
                write_en_i = 0;
            end

            word_sel_i = 0;      // Reset index
            start_perm_i = 1;    // Starting Permutation
            #4 start_perm_i = 0;

            // Wait for permutations to finish
            wait(ready_o == 1);

            // Reading full state output
            for(word_sel_i = 0; word_sel_i < NUM_WORDS; word_sel_i++) begin
                #4 state_data_o[word_sel_i] = data_o;
            end

            // Wait for output to be stable, and check
            #2;
            check_core_output(test_data_o, state_data_o);
        end

        $finish;
    end

endmodule
