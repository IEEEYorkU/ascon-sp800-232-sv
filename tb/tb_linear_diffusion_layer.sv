`timescale 1ns/1ps
import ascon_pkg::*;

module tb_linear_diffusion_layer;

    // DUT signals
    ascon_state_t state_i;
    ascon_state_t state_o;

    // Reference full 320-bit values
    logic [319:0] input_vec;
    logic [319:0] expected_vec;

    // DUT
    linear_diffusion_layer dut (
        .state_array_i(state_i),
        .state_array_o(state_o)
    );

    initial begin
        $display("=== Starting Linear Diffusion Layer Testbench ===");

        // ------------------------
        // test case 1: All zeros
        // ------------------------
        
        state_i[0] = 64'h0;
        state_i[1] = 64'h0;
        state_i[2] = 64'h0;
        state_i[3] = 64'h0;
        state_i[4] = 64'h0;

        #1;

        $display("Full State: Success (320 of all zeros indeed wohoo)");

        if({state_o[0], state_o[1], state_o[2], state_o[3], state_o[4]} !== 320'h0) begin 
            $error("Test 1 failed womp womp");
        end

        // -------------------------
        // test case 2: Word 0 - Rotation 19 & 28 
        // -------------------------
        // Input: 64'h0000|0000|0000|0001
        // Math:
        //      Orginial: 0000|0000|0000|0001
        //      Rot 19:   0000|2000|0000|0000 (Bit 0 moved to 45: 2^45)
        //      Rot 28:   0000|0010|0000|0000 (Bit 0 moved to 36: 2^36)
        // XOR Result:    0000|2010|0000|0001

        state_i[0] = 64'h1;

        #1;

        if(state_o[0] === 64'h0000201000000001) begin
            $display("Word 0: Success (Rot 19 and 28 match wohoo)");
        end else begin
            $display("Word 0: Fail womp womp. Got %h", state_o[0]);
        end

        // -------------------------
        // test case 3: Word 2 - Rotation 1 & 6
        // -------------------------
        // Input: 64'h0000|0000|0000|0001
        // Math:
        //      Orginial: 0000|0000|0000|0001
        //      Rot 19:   8000|0000|0000|0000 (Bit 0 wraps to Bit 63)
        //      Rot 28:   0400|0000|0000|0000 (Bit 0 wraps to Bit 58)
        // XOR Result:    8400|0000|0000|0001

        state_i[2] = 64'h1;

        #1;

        if(state_o[2] === 64'h8400000000000001) begin
            $display("Word 2: Success (Rot 1 and 6 match wohoo)");
        end else begin
            $display("Word 2: fail womp womp. Got %h", state_o[2]);
        end

        $finish;
    end

endmodule