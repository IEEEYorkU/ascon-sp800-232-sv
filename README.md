# NIST SP 800-232 (Ascon) Hardware Accelerator in SystemVerilog

By: York University - Lassonde Hardware Design Club under IEEE YorkU Student Chapter

![NIST Standard](https://img.shields.io/badge/NIST-SP%20800--232-blue)
![Primitive](https://img.shields.io/badge/Primitive-Ascon-orange)
![Language](https://img.shields.io/badge/Language-SystemVerilog-blue)
![Security](https://img.shields.io/badge/Security-128--bit-green)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

This repository aims to provide a **SystemVerilog hardware accelerator** for the **Ascon** cryptographic suite, as specified in **NIST SP 800-232**. Optimized for **Lightweight Cryptography (LWC)**, this implementation targets the 320-bit permutation-based authenticated encryption (AEAD) and hashing algorithms (Ascon-128, Ascon-Hash) to deliver robust security for resource-constrained devices. By shifting these compute-intensive permutations from software to dedicated hardware, we achieve significantly higher throughput and lower energy-per-bit, enabling real-time integrity and confidentiality for low-power FPGA and ASIC deployments.
