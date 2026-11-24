GODOT ?= godot
RUSTC ?= rustc
CC ?= cc
CFLAGS := -std=c11 -O2 -Wall -Wextra -Werror -Wpedantic -msoft-float -mno-sse -mno-sse2

.PHONY: play verify verify-godot verify-rust verify-qnx-c11 clean

play:
	$(GODOT) --path .

verify: verify-godot verify-rust verify-qnx-c11

verify-godot:
	$(GODOT) --headless --path . -s tests/test_game_core_headless.gd

verify-rust:
	$(RUSTC) -D warnings -O rust/ky_engine_v1.rs -o /tmp/flap_plopp_ky_engine_v1
	/tmp/flap_plopp_ky_engine_v1
	$(RUSTC) -D warnings -O rust/millennium_gate_v1.rs -o /tmp/flap_plopp_millennium_v1
	/tmp/flap_plopp_millennium_v1
	rm -f /tmp/flap_plopp_ky_engine_v1 /tmp/flap_plopp_millennium_v1

verify-qnx-c11:
	$(CC) $(CFLAGS) c11_qnx/flap_plopp_qnx_gate.c -o /tmp/flap_plopp_qnx_gate
	@if objdump -d /tmp/flap_plopp_qnx_gate | grep -E '\b(addss|subss|mulss|divss|addsd|subsd|mulsd|divsd|ucomiss|ucomisd|cvtsi2ss|cvtsi2sd|fld|fstp|fadd|fmul)\b' >/dev/null; then \
		echo "FLOAT_INSN_DETECTED"; exit 1; \
	else \
		echo "OBJDUMP_ZERO_FLOAT_OK"; \
	fi
	/tmp/flap_plopp_qnx_gate
	rm -f /tmp/flap_plopp_qnx_gate

clean:
	rm -f /tmp/flap_plopp_ky_engine_v1 /tmp/flap_plopp_millennium_v1 /tmp/flap_plopp_qnx_gate
