/*
 * Module Name: ascon_core_tb.sv
 * Aurthor(s): Arthur Sabadini, Artin Kiany, Kiet Le
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
    ascon_state_t test_data_i;
    ascon_state_t test_data_o;
    ascon_state_t state_data_o;

    // Python Golden File Variables
    int fd;
    int r;
    logic [63:0] temp_word;
    int round_config_file;
    ascon_state_t input_state_file;
    ascon_state_t expected_state_file;

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
        start_perm_i |=> !ready_o;
    endproperty

    property data_stable_when_ready;
        @(posedge clk)
        (ready_o & $past(ready_o) & $stable(word_sel_i) & !$past(write_en_i)) |-> $stable(data_o);
    endproperty

    property write_successful_on_idle;
        @(posedge clk)
        ((dut.state == 1'b0) & write_en_i & !xor_en_i) |=> (
            dut.state_array[$past(word_sel_i)] == $past(data_i)
        );
    endproperty

    property xor_write_sucessful_on_idle;
        @(posedge clk)
        ((dut.state == 1'b0) & write_en_i & xor_en_i) |=> (
                dut.state_array[$past(word_sel_i)] ==
                ($past(dut.state_array[word_sel_i]) ^ $past(data_i))
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
            $display("Success. State out is State Expected.");
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

        // Synchronize to the clock before starting
        @(negedge clk);

        for (int i = 0; i < max_tests; i++) begin
            // Generating random input
            rand_array(test_data_i);
            test_data_o = ascon_perm(round_config_i, test_data_i);

            // Writing input (Synchronous 1-cycle write loop)
            for(int w = 0; w < NUM_WORDS; w++) begin
                @(negedge clk);
                word_sel_i = w;
                data_i = test_data_i[w];
                write_en_i = 1;
            end
            @(negedge clk);
            write_en_i = 0;

            // Synchronous start permutation pulse
            word_sel_i = 0;
            start_perm_i = 1;
            @(negedge clk);
            start_perm_i = 0;

            // Wait for permutations to finish
            wait(ready_o == 1);

            // Reading full state output (Synchronous Read)
            for(int w = 0; w < NUM_WORDS; w++) begin
                @(negedge clk);
                word_sel_i = w;
                // Wait half a cycle for the combinational read data to settle
                @(posedge clk);
                state_data_o[w] = data_o;
            end

            check_core_output(test_data_o, state_data_o);
        end

        // ----------------------------
        // Python Golden Vector Test
        // ----------------------------

        $display("Running Python golden vector tests...");

        fd = $fopen("verif/test_vectors/ascon_vectors.txt", "r");
        if(fd == 0) $fatal("Cannot open ascon_vectors.txt");

        while(!$feof(fd)) begin

            // Read round config
            r = $fscanf(fd, "%d\n", round_config_file);
            round_config_i = round_config_file;

            // Read input state
            for(int i=0;i<NUM_WORDS;i++) begin
                r = $fscanf(fd, "%h\n", temp_word);
                input_state_file[i] = temp_word;
            end

            // Read expected state
            for(int i=0;i<NUM_WORDS;i++) begin
                r = $fscanf(fd, "%h\n", temp_word);
                expected_state_file[i] = temp_word;
            end

            // Write to DUT (Synchronous 1-cycle write loop)
            for(int w = 0; w < NUM_WORDS; w++) begin
                @(negedge clk);
                word_sel_i = w;
                data_i = input_state_file[w];
                write_en_i = 1;
            end
            @(negedge clk);
            write_en_i = 0;

            // Synchronous start permutation pulse
            word_sel_i = 0;
            start_perm_i = 1;
            @(negedge clk);
            start_perm_i = 0;

            // Wait for permutations to finish
            wait(ready_o == 1);

            // Read back (Synchronous Read)
            for(int w = 0; w < NUM_WORDS; w++) begin
                @(negedge clk);
                word_sel_i = w;
                @(posedge clk);
                state_data_o[w] = data_o;
            end

            check_core_output(expected_state_file, state_data_o);
        end

        $display("All tests completed.");

        $finish;
    end

endmodule
