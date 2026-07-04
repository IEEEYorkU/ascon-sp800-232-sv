# Ascon Core Design Strategy

### 1. Design Philosophy: "The Dumb Slave"
The guiding principle for this Ascon Core is **Decoupling**. We separate cryptographic mathematics from protocol logic.
* **Core Responsibility (The "Muscle"):** The Core is strictly a "Permutation Engine" and "State Register File". It knows how to store 320 bits and how to run the mathematical permutations for a specific number of rounds. It does **not** know what "Encryption" or "Hashing" is.
* **Controller Responsibility (The "Brain"):** All protocol-specific logic—XORing input data for absorption, extracting ciphertext, padding messages, and managing modes (AEAD vs. Hash)—is moved **out** of the Core and managed by the Controller.
* **Solved Problem:** This architecture elegantly solves the **Decryption Conflict** (where the state update differs from the output generation) because the Controller handles the XOR logic externally, treating the Core as a simple memory unit.

---

### 2. Module Interface (I/O)
This interface minimizes routing congestion by using a narrow 64-bit data path, matching the word size defined in the standard.

| Signal Name | Direction | Width | Purpose |
| :--- | :--- | :--- | :--- |
| **`clk`** | Input | 1 | System clock |
| **`rst`** | Input | 1 | **Global Reset.** Only used for power-on reset. (Standard "clearing" is done by overwriting state with IVs) |
| **`start_perm_i`** | Input | 1 | **Trigger.** A high pulse starts the permutation engine. |
| **`round_config_i`** | Input | 1 | **Configuration.** Selects the number of rounds to run (e.g., 0=8 rounds, 1=12 rounds). Matches standard requirements for Init/Final vs. Data phases |
| **`write_en_i`** | Input | 1 | **Write Enable.** When high, write `data_i` into the word selected by `word_sel_i`. |
| **`word_sel_i`** | Input | 3 | **Address Selector.** Selects which of the five state words (S0:S4) to write to or read from. |
| **`data_i`** | Input | 64 | **Input Data.** The 64-bit value to be written (or XORed) *directly* into the selected state word (overwriting or XORing into current value). |
| **`data_o`** | Output | 64 | **Output Data.** Continuously outputs the current value of the state word selected by `word_sel_i`. |
| **`ready_o`** | Output | 1 | **Completion Pulse/Idle Status.** High when the Core is waiting for commands. Low when a permutation is running. |

*(Note: The `xor_en_i` signal was marked as crossed out in the source document, so it has been omitted from this table for clarity.)*

---

### 3. Summary of Operation Flow
The Controller interacts with this core in three distinct "Primitive Operations":
1. **Load/Overwrite (Initialization):** Controller sets `word_sel_i` to 0..4 and pulses `write_en_i` to load IV, Key, and Nonce sequentially.
2. **Permute (Round Function):** Controller sets `round_config_i` (e.g., to 12) and pulses `start_perm_i`. The controller waits until `ready_o` is set.
3. **Absorb/Extract (Data Processing):** **Read:** Controller sets `word_sel_i`, reads `data_o` (State).
