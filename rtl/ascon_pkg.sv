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

    // 3-bit TUSER encoding for AXI4-Stream
    typedef enum logic [2:0] {
        TUSER_RESERVED = 3'b000,
        TUSER_KEY      = 3'b001, // Incoming data is K
        TUSER_NONCE    = 3'b010, // Incoming data is N
        TUSER_AD       = 3'b011, // Incoming data is Associated Data (A)
        TUSER_PT       = 3'b100, // Incoming data is Plaintext (P) - Encryption
        TUSER_CT       = 3'b101, // Incoming data is Ciphertext (C) - Decryption
        TUSER_TAG      = 3'b110  // Incoming data is Tag (T) - Decryption Verification
    } axi_tuser_t;

    // --- Core Data In Select Enum ---
    // Selects what data is being fed into the ascon core
    typedef enum logic [2:0] {
        MODE_AEAD_ENC   = 3'b000,
        MODE_AEAD_DEC   = 3'b001,
        MODE_HASH256    = 3'b010,
        MODE_XOF        = 3'b011,
        MODE_CXOF       = 3'b100
    } ascon_mode_t;

endpackage : ascon_pkg
