/*
 * Package Name: ascon_pkg
 * Description: Type definitions and constants for the Ascon Hardware Accelerator
 * Ref: NIST SP 800-232
 */

package ascon_pkg;

    // -------------------------------------------------------------------------
    // 1. Parameters (Constants)
    // -------------------------------------------------------------------------
    localparam int WORD_WIDTH   = 64;   // Ascon uses 64-bit words
    localparam int NUM_WORDS    = 5;    // State consists of S0..S4
    localparam int STATE_WIDTH  = 320;  // Total state size

    // -------------------------------------------------------------------------
    // 2. Type Definitions
    // -------------------------------------------------------------------------

    // A single 64-bit word (S0, S1, etc.)
    typedef logic [WORD_WIDTH-1:0] ascon_word_t;

    // The full Ascon state: 5 words of 64 bits each
    // Defined as [4:0] so index 0 maps to S0 (IV), index 4 maps to S4
    typedef ascon_word_t [NUM_WORDS-1:0] ascon_state_t;

    // Round constant type
    typedef logic [3:0] rnd_t;

endpackage : ascon_pkg
