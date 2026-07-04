# System Overview: Ascon Hardware Accelerator

## Introduction to NIST SP 800-232
This project is a SystemVerilog hardware accelerator for the **NIST SP 800-232 Standard: Ascon-Based Lightweight Cryptography Standards for Constrained Devices**[cite: 1].

Ascon is a family of cryptographic algorithms designed to provide efficient Authenticated Encryption with Associated Data (AEAD), hash functions, and extendable Output Functions (XOF). It was selected by NIST specifically for resource-constrained environments—such as Internet of Things (IoT) devices, embedded systems, and low-power sensors—where traditional standards like AES-GCM may be too resource-intensive or consume too much power.

In a real-world scenario, this hardware module operates as a dedicated cryptographic co-processor. A host microcontroller streams raw plaintext and keys into the accelerator via standard bus interfaces (like AXI4-Stream), and the accelerator securely encrypts and authenticates the data in hardware, saving the host CPU thousands of clock cycles and significantly reducing system power consumption.

---

## Architectural Design Strategy: The Hierarchical "Permutation Sequencer"

To effectively implement the Ascon suite, this Lassonde Hardware Design Club accelerator employs a "Decoupled Data/Control" methodology. This strategy decouples the high-level protocol logic from the low-level permutation mechanics.

### 1. The Datapath (The "Slave" Core)
The `ascon_core` acts as a "slave" unit containing the 320-bit state, permutation layers, and a dedicated round counter/controller. This core executes the requested number of mathematical rounds (e.g., $p^{12}$ or $p^8$) and signals completion. It serves as a pure permutation engine and is entirely isolated from understanding the broader cryptographic context (such as whether it is currently hashing or encrypting).

### 2. The Control Path (The "Master" FSMs)
The high-level Algorithm FSMs (such as AEAD and Hash) function as "masters" that sequence the protocol steps. Their responsibilities include:
* Loading the Key, Nonce, and Initialization Vectors (IV).
* Feeding input blocks into the state (the absorbing phase).
* Requesting permutation runs from the core.

The FSMs operate without managing the cycle-by-cycle details of the cryptographic rounds.

### Summary
This separation of concerns creates a cleaner, highly modular design where the core handles the heavy mathematics (Constant-Addition $p_C$, Substitution $p_S$, and Linear Diffusion $p_L$), and the FSMs strictly handle the data routing and AXI-stream flow control.
