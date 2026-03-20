# =========================================================
# Local Project Variables & Vector Generation
# =========================================================
.DEFAULT_GOAL := all

PYTHON      ?= python3
PY_SCRIPT   := verif/test_scripts/core_test.py
AEAD_PY_SCRIPT := verif/test_scripts/aead_test.py
VECTOR_FILE := verif/test_vectors/ascon_vectors.txt
AEAD_VECTOR_FILE := verif/test_vectors/aead_vectors.txt

# Always regenerate vectors
.PHONY: FORCE
$(VECTOR_FILE): FORCE
	@echo "=== Generating Python Core test vectors ==="
	$(PYTHON) $(PY_SCRIPT)

$(AEAD_VECTOR_FILE): FORCE
	@echo "=== Generating Python AEAD test vectors ==="
	$(PYTHON) $(AEAD_PY_SCRIPT)

# We want the test vectors to be generated before any simulation target.
# Since common.mk makes `run_%` depend on `build.f`, we can just
# hook our vector generation into `build.f`!
build.f: $(VECTOR_FILE) $(AEAD_VECTOR_FILE)

# =========================================================
# Import Central Build System
# =========================================================
include build-tools/common.mk
