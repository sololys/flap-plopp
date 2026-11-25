GODOT ?= godot
RUSTC ?= rustc
CC ?= cc
IVERILOG ?= iverilog
VVP ?= vvp
PYTHON ?= python3
CFLAGS := -std=c11 -O2 -Wall -Wextra -Werror -Wpedantic -msoft-float -mno-sse -mno-sse2

.PHONY: play verify verify-godot verify-rust verify-qnx-c11 verify-rtl verify-python clean

play:
	$(GODOT) --path .

verify: verify-godot verify-rust verify-qnx-c11 verify-rtl verify-python

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
	$(CC) $(CFLAGS) c11_qnx/sluse_3d_gate.c -o /tmp/flap_plopp_sluse_3d
	@if objdump -d /tmp/flap_plopp_sluse_3d | grep -E '\b(addss|subss|mulss|divss|addsd|subsd|mulsd|divsd|ucomiss|ucomisd|cvtsi2ss|cvtsi2sd|fld|fstp|fadd|fmul)\b' >/dev/null; then \
		echo "FLOAT_INSN_DETECTED_SLUSE"; exit 1; \
	else \
		echo "OBJDUMP_ZERO_FLOAT_SLUSE_OK"; \
	fi
	/tmp/flap_plopp_sluse_3d
	$(CC) $(CFLAGS) c11_qnx/lih_sluse_gate.c -o /tmp/flap_plopp_lih_sluse
	@if objdump -d /tmp/flap_plopp_lih_sluse | grep -E '\b(addss|subss|mulss|divss|addsd|subsd|mulsd|divsd|ucomiss|ucomisd|cvtsi2ss|cvtsi2sd|fld|fstp|fadd|fmul)\b' >/dev/null; then \
		echo "FLOAT_INSN_DETECTED_LIH"; exit 1; \
	else \
		echo "OBJDUMP_ZERO_FLOAT_LIH_OK"; \
	fi
	/tmp/flap_plopp_lih_sluse
	$(CC) $(CFLAGS) c11_qnx/ky_kora_sluse.c -o /tmp/flap_plopp_ky_kora
	@if objdump -d /tmp/flap_plopp_ky_kora | grep -E '\b(addss|subss|mulss|divss|addsd|subsd|mulsd|divsd|ucomiss|ucomisd|cvtsi2ss|cvtsi2sd|fld|fstp|fadd|fmul)\b' >/dev/null; then \
		echo "FLOAT_INSN_DETECTED_KORA"; exit 1; \
	else \
		echo "OBJDUMP_ZERO_FLOAT_KORA_OK"; \
	fi
	/tmp/flap_plopp_ky_kora
	rm -f /tmp/flap_plopp_qnx_gate /tmp/flap_plopp_sluse_3d /tmp/flap_plopp_lih_sluse /tmp/flap_plopp_ky_kora

verify-rtl:
	$(IVERILOG) -g2012 -Wall -o /tmp/flap_plopp_lih_rtl.vvp rtl/lih_sluse_gate.sv rtl/tb_lih_sluse_gate.sv
	$(VVP) /tmp/flap_plopp_lih_rtl.vvp
	$(IVERILOG) -g2012 -Wall -o /tmp/flap_plopp_kora_rtl.vvp rtl/ky_kora_sluse.sv rtl/tb_ky_kora_sluse.sv
	$(VVP) /tmp/flap_plopp_kora_rtl.vvp
	rm -f /tmp/flap_plopp_lih_rtl.vvp /tmp/flap_plopp_kora_rtl.vvp

verify-python:
	$(PYTHON) python/phase_mirror.py

clean:
	rm -f /tmp/flap_plopp_ky_engine_v1 /tmp/flap_plopp_millennium_v1 /tmp/flap_plopp_qnx_gate /tmp/flap_plopp_sluse_3d /tmp/flap_plopp_lih_sluse /tmp/flap_plopp_ky_kora /tmp/flap_plopp_lih_rtl.vvp /tmp/flap_plopp_kora_rtl.vvp
