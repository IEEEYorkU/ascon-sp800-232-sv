# =====================
# Dual-Simulator Makefile
# =====================

# List of testbenches
TESTBENCHES = substitution_layer_tb constant_addition_layer_tb linear_diffusion_layer_tb

# --- PATH DEFINITIONS ---
LIB_DIR     = .
LIB_SRCS    = $(wildcard $(LIB_DIR)/rtl/*.sv)
PKG_SRCS    = rtl/ascon_pkg.sv
DESIGN_SRCS = $(wildcard rtl/*.sv)
COMMON_SRCS = $(wildcard rtl/*.svh)

# Simulator selection (default to vsim if not specified)
# Usage: make run_all SIM=verilator
SIM ?= vsim

# --- VERILATOR FLAGS ---
# --binary: Build an executable (requires Verilator v5.0+)
# --timing: Support delay statements (#1ns) in SV
# --trace:  Enable VCD tracing
VERILATOR_FLAGS = --binary -j 0 --timing --trace -Wall -Wno-fatal

# Default target
all: run_all

.PHONY: run_all clean run_%

# Loop through testbenches
run_all:
	@for tb in $(TESTBENCHES); do \
		$(MAKE) run_$$tb; \
	done

# Rule for each testbench
run_%:
	@echo "=== Running $* with $(SIM) ==="
ifeq ($(SIM), verilator) # Catch 'verilator'
    # 1. Verilate (Compile to C++ -> Compile to Exe)
    # We filter out the specific TB we are running + Design + Packages
	verilator $(VERILATOR_FLAGS) \
		+incdir+$(LIB_DIR)/rtl \
		--top-module $* \
		$(PKG_SRCS) $(COMMON_SRCS) $(filter-out $(PKG_SRCS), $(DESIGN_SRCS)) tb/$*.sv

    # 2. Run the executable (Generated in obj_dir/V<top_module_name>)
	./obj_dir/V$*
else
    # --- MODELSIM FLOW (Your existing code) ---
	vlib work
	vlog -work work -sv +incdir+$(LIB_DIR)/rtl $(PKG_SRCS) $(LIB_SRCS)
	vlog -work work -sv +incdir+$(LIB_DIR)/rtl $(filter-out $(PKG_SRCS), $(DESIGN_SRCS)) $(COMMON_SRCS) tb/$*.sv
	@echo 'vcd file "$*.vcd"' > run_$*.macro
	@echo 'vcd add -r /$*/*' >> run_$*.macro
	@echo 'run -all' >> run_$*.macro
	@echo 'quit' >> run_$*.macro
	vsim -c -do run_$*.macro work.$*
	rm -f run_$*.macro
endif

# Clean build files
clean:
	rm -rf work *.vcd transcript vsim.wlf run_*.macro
	rm -rf obj_dir
