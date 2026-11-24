GODOT ?= godot
RUSTC ?= rustc

.PHONY: play verify verify-godot verify-rust clean

play:
	$(GODOT) --path .

verify: verify-godot verify-rust

verify-godot:
	$(GODOT) --headless --path . -s tests/test_game_core_headless.gd

verify-rust:
	$(RUSTC) -D warnings -O rust/ky_engine_v1.rs -o /tmp/flap_plopp_ky_engine_v1
	/tmp/flap_plopp_ky_engine_v1
	rm -f /tmp/flap_plopp_ky_engine_v1

clean:
	rm -f /tmp/flap_plopp_ky_engine_v1
