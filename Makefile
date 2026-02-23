# =====================
# ModelSim Multi-TB Makefile
# =====================

# List of testbenches (example: TESTBENCHES = theta_step_tb rho_step_tb)
TESTBENCHES = substitution_layer_tb constant_addition_layer_tb linear_diffusion_layer_tb ascon_core_tb

# --- PATH DEFINITIONS ---
LIB_DIR     =
# Assuming the submodule has its own 'rtl' folder inside
LIB_SRCS    = $(wildcard $(LIB_DIR)/rtl/*.sv)

# --- SOURCE FILES ---
# Packages must be compiled first
PKG_SRCS    = rtl/ascon_pkg.sv

# Your local design files
DESIGN_SRCS = $(wildcard rtl/*.sv)
COMMON_SRCS = $(wildcard rtl/*.svh)

# Work library
WORK = work

# Default target
all: $(WORK)
	@if [ -z "$(strip $(TESTBENCHES))" ]; then \
		echo "No testbenches specified. Compiling RTL only..."; \
		vlog -work $(WORK) -sv +incdir+$(LIB_DIR)/rtl $(PKG_SRCS) $(LIB_SRCS); \
		vlog -work $(WORK) -sv +incdir+$(LIB_DIR)/rtl $(filter-out $(PKG_SRCS), $(DESIGN_SRCS)) $(COMMON_SRCS); \
	else \
		$(MAKE) run_all TESTBENCHES="$(TESTBENCHES)"; \
	fi

# Create ModelSim work library
$(WORK):
	vlib $(WORK)

# Run all testbenches
.PHONY: run_all clean run_%

run_all:
	@for tb in $(TESTBENCHES); do \
		$(MAKE) run_$$tb; \
	done

# Rule for each testbench
run_%: $(WORK)
	@if [ "$*" = "all" ]; then exit 0; fi
	@echo "=== Running $* ==="
# 1. Compile Packages & Common Lib (Interfaces)
	vlog -work $(WORK) -sv +incdir+$(LIB_DIR)/rtl $(PKG_SRCS) $(LIB_SRCS)
# 2. Compile Design & Testbench
	vlog -work $(WORK) -sv +incdir+$(LIB_DIR)/rtl $(filter-out $(PKG_SRCS), $(DESIGN_SRCS)) $(COMMON_SRCS) tb/$*.sv

# 3. Create Macro & Run
	@echo 'vcd file "$*.vcd"' > run_$*.macro
	@echo 'vcd add -r /$*/*' >> run_$*.macro
	@echo 'run -all' >> run_$*.macro
	@echo 'quit' >> run_$*.macro
	vsim -c -do run_$*.macro $(WORK).$*
	rm -f run_$*.macro

# Clean build files
clean:
	rm -rf $(WORK) *.vcd transcript vsim.wlf run_*.macro
