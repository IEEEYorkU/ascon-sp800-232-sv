# Ascon Padder Design Strategy

### 1. Overview and Purpose
The `ascon_padder` serves as a dedicated AXI4-Stream pre-processor (or "Framer") for the Ascon Cryptographic Accelerator.

Its primary purpose is to intercept raw, incoming variable-length data streams and dynamically apply the precise bit-level padding and rate-alignment rules defined in NIST SP 800-232. By handling these complex byte-level operations on the fly, the padder abstracts the formatting burden away from the downstream protocol state machines (`aead_fsm`, `hash_fsm`), allowing them to function as highly efficient, protocol-agnostic block counters.

---

### 2. Architectural Fit: Decoupling Formatting from Control
In this accelerator's "Decoupled Data/Control" architecture, the padder sits directly behind the top-level external AXI4-Stream slave ports, acting as a crucial pipeline stage before data is routed to the Ascon core or the top-level XOR unit.

* **Upstream Flow Control:** The padder directly drives `s_axis_tready_o`, giving it the authority to halt the external data source if it needs extra clock cycles to generate artificial padding words.
* **Downstream Flow Control:** The padder monitors `padded_tready_i` (driven by the active FSM) to know when its formatted output has been successfully consumed.
* **Clean Datapath:** By the time data leaves the padder on the `padded_tdata_o` bus, it is mathematically complete and rate-aligned. The downstream FSMs never need to inspect `padded_tkeep_o` during standard absorption phases; they simply XOR the full 64-bit payload into the core.

---

### 3. Core Responsibilities & Logic Parsing
The padder routes and modifies incoming packets strictly based on their `TUSER` sideband signal, sorting them into three distinct processing categories:

#### A. The Ascon Padding Rule (`TUSER_AD`, `TUSER_PT`, `TUSER_MSG`, `TUSER_Z`)
When processing variable-length data groups (Associated Data, Plaintext, Hash Messages, and Customization Strings), the padder monitors the stream for the boundary marker (`s_axis_tlast_i == 1`).
* Upon detecting the final word, it evaluates the `s_axis_tkeep_i` byte-enables to locate the final valid byte.
* It dynamically masks out invalid bytes and injects the mandatory Ascon padding sequence (a single `1` bit followed by `0`s to fill the 64-bit word).
* It forces the output `padded_tkeep_o = 8'hFF`, ensuring the FSMs do not have to handle fractional bytes.

#### B. Rate Alignment (The AEAD 128-bit Edge Case)
Ascon-Hash256 operates on a 64-bit rate ($r=64$), perfectly matching the AXI bus width. However, Ascon-AEAD128 operates on a 128-bit rate ($r=128$, or two 64-bit words).
* If the accelerator is in AEAD mode and a message ends perfectly aligned on the *first* 64-bit half of a block, the padder will artificially stall the pipeline.
* It forces `s_axis_tready_o = 0` to halt incoming traffic, generates a second 64-bit word of pure `0`s, and asserts `padded_tlast_o = 1`. This safely signals to the `aead_fsm` that the full 128-bit block is ready for the $p^8$ permutation.

#### C. The Decryption Exception (`TUSER_CT`)
Ciphertext undergoes highly specialized handling during decryption.
* **Action:** The padder enforces a STRICT PASS-THROUGH. It does not append the $10...0$ bit sequence, and it passes the raw `s_axis_tkeep_i` byte-enables directly to the output.
* **Why?** During decryption, the fractional Ciphertext is required to overwrite the state precisely up to the $\ell$ boundary, while the padding bits are XORed into the remaining invalid byte positions. The `aead_fsm` requires the unmodified `TKEEP` signal to accurately pinpoint this boundary and manually execute the state split without corrupting the Plaintext output.

#### D. Strict Pass-Through Group (`TUSER_KEY`, `TUSER_NONCE`, `TUSER_TAG`)
Fixed-length cryptographic parameters are passed straight through the module unmodified. `TLAST` and `TKEEP` signals are ignored or passed transparently, as these inputs do not participate in standard sponge absorption padding.
