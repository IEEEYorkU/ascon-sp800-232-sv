/*
 * Module Name: substitution_layer_tv.sv
 * Aurthor(s): Kevin Duong, (Add your name here for changes)
 * Description: Testbench for substitution_layer.sv
 *
 * If you are SSH into the EECS server, you don't need to install Modelsim:
 *          1. Open terminal and type bash
 *          2. Once, you're in bash, execute source env.sh
 *          3. After that, you can execute make
 */

`timescale 1ns/1ps 

import ascon_pkg::*;

module substitution_layer_tb;

// Inputs and Registers DUT
ascon_state_t state_array_i;
ascon_state_t state_array_o;

//Instantiate DUT from substitution_layer:
substitution_layer dut (
    .state_array_i(state_array_i),
    .state_array_o(state_array_o)
);

/*
-------------------------------------------------------------------------
 * SBOX equations from NIST SP 800-232, Sec 3.3 Eq (7)
 * Mapping follows Eq (5): (s(0,j),...,s(4,j)) = SBOX(...)
 * So x0=s(0,j)=state_array_i[0][j], ..., x4=s(4,j)=state_array_i[4][j]
-------------------------------------------------------------------------
 */

//This is meant to be the expected output, we cna use to compare
//the results from sbox_eq function to our actual implementation substitution_layer.sv
function automatic logic [4:0] sbox_eq(
    input logic x0, x1, x2, x3, x4
);

 logic y0, y1, y2, y3, y4;
 begin
    y0 = (x4 & x1) ^ x3 ^ (x2 & x1) ^ x2 ^ (x1 & x0) ^ x1 ^ x0;
    y1 = x4        ^ (x3 & x2) ^ (x3 & x1) ^ x3 ^ (x2 & x1) ^ x2 ^ x1 ^ x0;
    y2 = (x4 & x3) ^ x4 ^ x2 ^ x1 ^ 1'b1;
    y3 = (x4 & x0) ^ x4 ^ (x3 & x0) ^ x3 ^ x2 ^ x1 ^ x0;
    y4 = (x4 & x1) ^ x4 ^ x3 ^ (x1 & x0) ^ x1;

    //Return the outputs
    sbox_eq = {y0, y1, y2, y3, y4};
 end
endfunction 




