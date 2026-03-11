
`timescale 1ns/1ps

import ascon_pkg::*;

module ascon_padder_tb;

    //DUT Inputs
    logic clk;
    logic rst;
    ascon_mode_t mode_i;

    ascon_mode_t s_axis_tdata_i;
    logic [7:0] s_axis_tkeep_i;
    axi_tuser_t s_axis_tuser_i;
    logic       s_axis_tlast_i;
    logic       s_axis_tvalid_i;
    logic       s_axis_tready_o;

    //DUT Outputs
    

endmodule


