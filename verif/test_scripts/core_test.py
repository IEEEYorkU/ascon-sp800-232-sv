import random
import os

ASCON_RC = [
    0xf0, 0xe1, 0xd2, 0xc3,
    0xb4, 0xa5, 0x96, 0x87,
    0x78, 0x69, 0x5a, 0x4b
]

SBOX = [
    0x4, 0xb, 0x1f, 0x14, 0x1a, 0x15, 0x9, 0x2,
    0x1b, 0x5, 0x8, 0x12, 0x1d, 0x3, 0x6, 0x1c,
    0x1e, 0x13, 0x7, 0xe, 0x0, 0xd, 0x11, 0x18,
    0x10, 0xc, 0x1, 0x19, 0x16, 0xa, 0xf, 0x17
]

WORD_MASK = (1 << 64) - 1

def rand_state():
    """Generate random 320-bit state."""
    return random.getrandbits(320)

def split_state(state):
    """Split 320-bit integer into five 64-bit words (little endian)."""
    return [(state >> (64 * i)) & WORD_MASK for i in range(5)]

def combine_state(words):
    """Combine five 64-bit words into one 320-bit integer."""
    state = 0
    for i in range(5):
        state |= (words[i] & WORD_MASK) << (64 * i)
    return state

def rotr(x, r):
    """Rotate right 64-bit word."""
    return ((x >> r) | (x << (64 - r))) & WORD_MASK


# ============================================================
# Constant Addition Layer (pC)
# ============================================================
def constant_addition_layer(state, round_idx):
    s = state.copy()
    s[2] ^= ASCON_RC[round_idx]
    return s


# ============================================================
# Substitution Layer (pS)
# ============================================================
def substitution_layer(state):
    s0, s1, s2, s3, s4 = state

    new_s0 = 0
    new_s1 = 0
    new_s2 = 0
    new_s3 = 0
    new_s4 = 0

    for j in range(64):
        # Extract bit j from each word
        b0 = (s0 >> j) & 1
        b1 = (s1 >> j) & 1
        b2 = (s2 >> j) & 1
        b3 = (s3 >> j) & 1
        b4 = (s4 >> j) & 1

        # Form 5-bit input exactly like RTL concatenation
        sbox_in = (b0 << 4) | (b1 << 3) | (b2 << 2) | (b3 << 1) | b4

        # Lookup
        sbox_out = SBOX[sbox_in]

        # Distribute output bits back
        new_s0 |= ((sbox_out >> 4) & 1) << j
        new_s1 |= ((sbox_out >> 3) & 1) << j
        new_s2 |= ((sbox_out >> 2) & 1) << j
        new_s3 |= ((sbox_out >> 1) & 1) << j
        new_s4 |= ((sbox_out >> 0) & 1) << j

    return [new_s0, new_s1, new_s2, new_s3, new_s4]


# ============================================================
# Linear Diffusion Layer (pL)
# ============================================================
def linear_diffusion_layer(state):
    s0, s1, s2, s3, s4 = state

    s0 ^= rotr(s0, 19) ^ rotr(s0, 28)
    s1 ^= rotr(s1, 61) ^ rotr(s1, 39)
    s2 ^= rotr(s2, 1)  ^ rotr(s2, 6)
    s3 ^= rotr(s3, 10) ^ rotr(s3, 17)
    s4 ^= rotr(s4, 7)  ^ rotr(s4, 41)

    return [s0 & WORD_MASK,
            s1 & WORD_MASK,
            s2 & WORD_MASK,
            s3 & WORD_MASK,
            s4 & WORD_MASK]


# ============================================================
# One Round of Ascon Permutation
# ============================================================
def ascon_round(state, round_idx):
    state = constant_addition_layer(state, round_idx)
    state = substitution_layer(state)
    state = linear_diffusion_layer(state)
    return state


# ============================================================
# Full Permutation (N Rounds)
# ============================================================
def ascon_permutation(state_words, round_config):

    state = state_words.copy()
    rounds = 12 if round_config else 8

    for r in range(rounds):

        if round_config:
            rc_index = r
        else:
            rc_index = r + 4

        state = constant_addition_layer(state, rc_index)
        state = substitution_layer(state)
        state = linear_diffusion_layer(state)

    return state


# ============================================================
# Generate Golden Output
# ============================================================
def generate_test_vectors(filename="ascon_vectors.txt", num_tests=20):
    with open(filename, "w") as f:
        for _ in range(num_tests):

            # Random initial state
            init_state_int = rand_state()
            init_words = split_state(init_state_int)

            # Test both configurations
            for round_config in [0, 1]:

                final_state = ascon_permutation(init_words, round_config)

                # Write round config
                f.write(f"{round_config}\n")

                # Write input words
                for w in init_words:
                    f.write(f"{w:016x}\n")

                # Write expected output words
                for w in final_state:
                    f.write(f"{w:016x}\n")

if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, "..", "test_vectors", "ascon_vectors.txt")
    output_path = os.path.abspath(output_path)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    generate_test_vectors(output_path, num_tests=25)
