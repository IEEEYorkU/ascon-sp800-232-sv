# LASCON (Lassonde ASCON) Lightweight Cryptographic Hardware Accelerator

By: Lassonde Hardware Design Club under IEEE YorkU Student Chapter (York University)

![NIST Standard](https://img.shields.io/badge/NIST-SP%20800--232-blue)
![Primitive](https://img.shields.io/badge/Primitive-Ascon-orange)
![Language](https://img.shields.io/badge/Language-SystemVerilog-blue)
![Security](https://img.shields.io/badge/Security-128--bit-green)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

A synthesizable, area-efficient SystemVerilog implementation of the [NIST SP 800-232 Ascon lightweight cryptography standard](https://csrc.nist.gov/pubs/sp/800/232/final). The design implements the core Ascon permutation and sponge construction, supporting both authenticated encryption and hashing operations in a unified hardware architecture.

## Features

- **AEAD128 Encryption & Decryption**: Authenticated encryption with associated data.
- **Hash256**: Cryptographic hashing.
- **XOF128**: Extendable-output function.
- **CXOF128**: Customizable extendable-output function.
- **AXI4-Stream Interface**: Industry-standard data streaming for seamless integration.

## Architecture

Lascon utilizes a "Decoupled Data/Control" philosophy, separating the mathematical permutation logic from protocol-specific state machines.

- **`lascon_core` (The Muscle)**: A protocol-agnostic permutation engine that maintains the 320-bit state.
- **`lascon_padder` (The Framer)**: An AXI-Stream pre-processor that handles bit-level framing and rate alignment (64-bit vs 128-bit blocks).
- **Sub-FSMs (`aead_fsm`, `hash_fsm`) (The Brains)**: Protocol-specific controllers managing handshakes and permutation scheduling.
- **`lascon_top` (Top-Level Arbiter)**: Multiplexes control signals and AXI handshakes based on the active mode.

For deep dives into the architecture, refer to the [docs/architecture](docs/architecture/) directory.

## Usage: Driving the Interface

The top-level module `lascon_top` utilizes standard AXI4-Stream interfaces for data input (`s_axis_*`) and output (`m_axis_*`).

### `lascon_top` Interface Summary

| Port Family | Description |
| :--- | :--- |
| `mode_i` | Operating mode: `00` (AEAD128), `01` (Hash256), `10` (XOF128), `11` (CXOF128) |
| `start_i`, `busy_o`, `done_o` | Basic control signals for initiating and monitoring operations |
| `s_axis_*` | AXI4-Stream slave for data input (Key, Nonce, AD, PT, CT, Msg, Z) |
| `m_axis_*` | AXI4-Stream master for data output (CT, PT, Tag, Digest) |

### AEAD Encryption/Decryption

Drive the `s_axis_tuser` sideband signal to indicate the type of data being streamed.

| Step | TUSER Stream Sequence | Description |
| :--- | :--- | :--- |
| 1 | `TUSER_KEY` (x2) | Two 64-bit words for the 128-bit Key |
| 2 | `TUSER_NONCE` (x2) | Two 64-bit words for the 128-bit Nonce |
| 3 | `TUSER_AD` (Optional) | Associated Data words (variable length) |
| 4 | `TUSER_PT` or `TUSER_CT` | Plaintext (Enc) or Ciphertext (Dec) words |
| 5 | `TUSER_TAG` (Dec Only) | Two 64-bit words for the expected Tag (for verification) |

### Hashing (Hash256, XOF128, CXOF128)

| Step | TUSER Stream Sequence | Description |
| :--- | :--- | :--- |
| 1 | `TUSER_Z` (CXOF Only) | Customization String (variable length) |
| 2 | `TUSER_MSG` | Message words (variable length) |

## Getting Started & Testing

### Prerequisites

- Python 3 (for test vector generation)
- ModelSim / QuestaSim or Verilator
- GNU Make

### Clone & Setup

Ensure you initialize the build tools submodule when cloning:

```bash
git clone --recurse-submodules https://github.com/IEEEYorkU/lascon-ip.git
cd lascon-ip
```

### Running Tests

The test suite uses a Makefile to drive simulations.

```bash
# Run all tests using the default simulator (VSIM)
make

# Run a specific testbench (e.g., lascon_top_tb)
make run_lascon_top_tb

# Run all tests using Verilator
make SIM=verilator
```

## Verification Status

The accelerator is rigorously tested against software reference models. Continuous Integration (CI) is managed via GitHub Actions calling the `lascon-build-tools` pipeline.

| Testbench | Coverage | Status |
| :--- | :--- | :--- |
| `lascon_core_tb` | Permutation rounds (p_C, p_S, p_L) | Passing |
| `lascon_padder_tb` | AXI stream padding and rate alignment | Passing |
| `constant_addition_layer_tb` | Round constant addition | Passing |
| `linear_diffusion_layer_tb` | Linear diffusion layer | Passing |
| `substitution_layer_tb` | S-box substitution layer | Passing |
| `hash_fsm_tb` | Hash state machine | Passing |
| `aead_fsm_tb` | AEAD state machine | Passing |
| `lascon_top_tb` | Full system integration and continuous streams | Passing |

> **Note:** Performance characterization (throughput, clock frequency, and resource utilization) is ongoing. Synthesis results will be published here as the design matures.

## Repository Structure

```
lascon-ip/
├── .github/      # CI/CD Workflows
├── build-tools/  # Submodule: Centralized build scripts
├── docs/         # Architecture documentation
├── rtl/          # SystemVerilog source code
├── tb/           # SystemVerilog testbenches
├── verif/        # Python scripts and generated test vectors
├── Makefile      # Top-level simulation driver
└── README.md     # You are here
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
