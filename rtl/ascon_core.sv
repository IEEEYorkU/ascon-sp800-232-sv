/*
 * Module Name: ascon_core
 * Author(s): Kiet Le, Arthur Sabadini
 * Description: Applies the Ascon Permutation for a configurable number of
 * rounds.
 * Ref: NISP ST 800-232 Section 3.
 */

import ascon_pkg::*;

module ascon_core (
    input   logic           clk,
    input   logic           rst,

    // Permutation Control
    input   logic           start_perm_i,
    input   logic           round_config_i,

    // Read/Write Word Address
    input   logic [2:0]     word_sel_i,

    // Data I/O Control
    input   ascon_word_t    data_i,
    input   logic           write_en_i,
    input   logic           xor_en_i,

    // Data Output (according to word_sel_i)
    output  ascon_word_t    data_o,

    // Permutation Complete
    output  logic           ready_o
);

    // FSM States
    typedef enum logic [1:0] {
		STATE_IDLE,
		STATE_INIT,
		STATE_PERM
    } state_t;
    state_t state = STATE_IDLE, next_state;
	
	rnd_t rnd_cnt;
	ascon_state_t state_array = 320'd0;
	
	// Permutation Layers Output
	ascon_state_t addition_state_array_o, substitution_state_array_o, diffusion_state_array_o;
	
	// Permutation Layers Instances
	constant_addition_layer const_add(
        .rnd_i(rnd_cnt),
        .state_array_i(state_array),
        .state_array_o(addition_state_array_o)
    );
	substitution_layer substitution(
        .state_array_i(addition_state_array_o),
        .state_array_o(substitution_state_array_o)
    );
	linear_diffusion_layer diffusion(
        .state_array_i(substitution_state_array_o),
        .state_array_o(diffusion_state_array_o)
    );
	
    // FSM Control Process 1: State Register (Sequential)
    // ----------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            state <= STATE_IDLE;
        end else begin
            state <= next_state;
        end
    end
    
	// FSM Control Process 2: Next State Decoder (Combinational)
    // ----------------------------------------------------------
	always_comb begin
        next_state = state;
	
	    case(state)
            STATE_IDLE: begin
                if(start_perm_i) begin
                    next_state = STATE_INIT;
                end else begin
                    next_state = STATE_IDLE;
                end
            end
            
            STATE_INIT: begin
                next_state = STATE_PERM;
            end
            
            STATE_PERM: begin
                if(rnd_cnt > 0) begin
                    next_state = STATE_PERM;
                end else begin
                    next_state = STATE_IDLE;
                end
            end
        endcase
	end
    
    // FSM Control Process 3: Action Decoder (Combinational)
    // ----------------------------------------------------------
    always_comb begin
        ready_o = 1'd0;
        data_o = state_array[word_sel_i];
        
        case(state)
            STATE_IDLE: begin
                ready_o = 1'd1;
            end
        endcase
    end
	
    // FSM Control Process 4: Action Logic (Sequential)
    // ----------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            rnd_cnt <= 4'd0;
            state_array <= 320'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if(write_en_i) begin
                        if(xor_en_i) begin
                            state_array[word_sel_i] <= data_i ^ state_array[word_sel_i];
                        end else begin
                            state_array[word_sel_i] <= data_i;
                        end
                    end
                end
				  
                STATE_INIT: begin
                    // Set counter to N-1, to have exactly N rounds.
                    if(round_config_i) begin
                        rnd_cnt <= 4'd11;
                    end else begin
                        rnd_cnt <= 4'd7;
                    end
                end

                STATE_PERM: begin
                    state_array <= diffusion_state_array_o;
                    if(rnd_cnt > 0)
                        // Preventing rnd_cnt from wrapping-around.
                        rnd_cnt <= rnd_cnt - 4'd1;
                end
            endcase
        end
    end

endmodule
