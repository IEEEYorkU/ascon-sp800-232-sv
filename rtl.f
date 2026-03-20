# 1. Submodules (i.e. -f lib/keccak-fips202-sv/rtl.f)

# 2. Local Packages
rtl/ascon_pkg.sv
tb/permutations_sim_pkg.sv

# 3. Ascon Core Layers
rtl/substitution_layer.sv
rtl/linear_diffusion_layer.sv
rtl/constant_addition_layer.sv
rtl/ascon_core.sv

# 4. Ascon Padder
rtl/ascon_padder.sv

# 5. Ascon FSMs
rtl/hash_fsm.sv
rtl/aead_fsm.sv

# 6. Helper Modules
rtl/xor64.sv

# 7. Ascon Top-Level
rtl/ascon_top.sv
