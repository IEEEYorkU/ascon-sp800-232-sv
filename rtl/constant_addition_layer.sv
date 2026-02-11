/*
 * Module Name: constant_addition_layer
 * Author(s): Sasha Calmels
 * Description:
 * Ref: NIST SP 800-232
 */

import ascon_pkg::*;

module constant_addition_layer (
    input   rnd_t           rnd_i,
    input   ascon_state_t   state_array_i,
    output  ascon_state_t   state_array_o
);

    // 16-entry LUT, each entry is 8 bit round constant
    localparam logic [7:0] ASCON_RC_LUT [0:15] = '{
        8'h3c, // i=0
        8'h2d, // i=1
        8'h1e, // i=2
        8'h0f, // i=3
        8'hf0, // i=4
        8'he1, // i=5
        8'hd2, // i=6
        8'hc3, // i=7
        8'hb4, // i=8
        8'ha5, // i=9
        8'h96, // i=10
        8'h87, // i=11
        8'h78, // i=12
        8'h69, // i=13
        8'h5a, // i=14
        8'h4b  // i=15
    };

    always_comb begin
        state_array_o = state_array_i;

        state_array_o[2] = state_array_i[2] ^ ASCON_RC_LUT[rnd_i];
    end

endmodule
