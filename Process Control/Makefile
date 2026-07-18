# Generic x86-64 NASM Makefile
# Works with ANY .asm file in this directory — no editing needed per project.
#
# Usage:
#   make fork          -> builds fork.asm  -> ./fork
#   make hello         -> builds hello.asm -> ./hello
#   make run FILE=fork -> builds AND runs fork.asm
#   make debug FILE=fork -> builds with debug symbols, launches gdb
#   make clean          -> removes all build artifacts (all .o files and
#                          any binary that has a matching .asm file)

NASM      := nasm
NASMFLAGS := -f elf64
LD        := ld
LDFLAGS   :=

# --- Pattern rule: %.o depends on %.asm ---
# The '%' matches whatever name you asked for (e.g. "fork" -> "fork.asm")
%.o: %.asm
	$(NASM) $(NASMFLAGS) $< -o $@

# --- Pattern rule: the final binary depends on the matching .o ---
%: %.o
	$(LD) $(LDFLAGS) $< -o $@

# --- Convenience targets that need to know WHICH file, via FILE=name ---
.PHONY: run debug clean

run:
	@if [ -z "$(FILE)" ]; then echo "Usage: make run FILE=<name-without-.asm>"; exit 1; fi
	@$(MAKE) $(FILE)
	./$(FILE)

debug:
	@if [ -z "$(FILE)" ]; then echo "Usage: make debug FILE=<name-without-.asm>"; exit 1; fi
	@rm -f $(FILE).o $(FILE)
	@$(MAKE) NASMFLAGS="$(NASMFLAGS) -g -F dwarf" $(FILE)
	gdb ./$(FILE)

clean:
	rm -f *.o
	@for f in *.asm; do \
		name="$${f%.asm}"; \
		if [ -f "$$name" ]; then rm -f "$$name"; fi \
	done