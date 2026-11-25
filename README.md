# Flap & Plopp: The Fjord Shift

```text
+--------------------------------------------------------------------------+
|                    FLAP & PLOPP : THE FJORD SHIFT                        |
+--------------------------------------------------------------------------+
|                                                                          |
|        *      .         (o>   FLAP!                 .       |/|          |
|      .    *            //\                          *      [===]         |
|  ~~~~~~~~~~~~~~~~~~~~~ V_/_ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ |===| ~~~~~~  |
|             o   o       \                                  |   |         |
|           o              v  PLOPP!     (o>    ~~~          |___|         |
|                 ( )                  //\                                 |
|                / | \   *  pearls     V_/_   stars  *                     |
|                                                                          |
+--------------------------------------------------------------------------+
|  GODOT 4.3 ARCADE  |  4 FJORD CHAPTERS + ENDLESS AURORA  |  0 EXTERNAL   |
|  100% PROCEDURAL ART & RETRO PCM SYNTH  |  5-STACK VERIFIED KERNELS      |
+--------------------------------------------------------------------------+
```

**Flap through the fjord sky. Plopp beneath the waves. Relight the Northern Lighthouse.**

Play as **Pip**, a tiny puffin carrying a fragile golden spark across four handcrafted Norwegian fjord chapters. One tap of `SHIFT` flips your world upside down — gravity pulls you down in the **Sky**, buoyancy lifts you up in the **Sea** — while stars, glowing pearls, and a golden `HOLD` bubble keep your spark from overheating.

Built with **Godot 4.3** for **GitHub Game Off (Theme: SHIFT)** with zero external sprite or audio files: every wave, aurora ribbon, puffin wingbeat, and retro chime is drawn and synthesized live in code.

---

## Quick Start

```bash
git clone https://github.com/sololys/flap-plopp.git
cd flap-plopp
make play
```

Requires **Godot 4.3** on your `PATH`. Want to run the full 5-stack verification suite (Godot headless, Rust, C11, SystemVerilog RTL, Python)? Run `make verify`.

---

## Controls

| Action | Keyboard | Mouse |
| :--- | :--- | :--- |
| **Flap up** (Sky) / **Dive down** (Sea) / **Next dialogue** | `Space` / `W` / `Up` / `Enter` | Left Click |
| **SHIFT** — flip between Sky (`SPLASH!`) and Sea (`PLOPP!`) | `Shift` / `S` / `Down` | Right Click |
| **`HOLD` Bubble** — pause time & cool your spark safely | `H` | — |
| **Skip Dialogue** / **Restart Story** | `Esc` / `R` | — |

### Arcade Tips

* **Skim the waterline:** Shifting close to the waves triggers a **Combo Multiplier** (up to `x8`) and extra spark cooling.
* **Aim for the Golden Ring:** After your first `SHIFT`, a pulsing **Poincaré Return** ring marks your departure altitude. Flip back through it for a massive score and cooling bonus.
* **Breathe in `HOLD`:** Spark getting too hot? Tap `H` anytime to freeze the fjord inside a golden `HOLD` bubble. Time alone will never pop it — you leave only when you press `Space` or `H`.

---

## Meet the Fjord Crew

* **Pip** — A fearless little puffin with orange beak, snappy wings, and a golden spark to deliver.
* **Captain Klabb** — Harbour seal mentor who teaches the Flip Law and promises fish cakes on the pier.
* **Lumina** — Cheerful glowing jellyfish guiding Pip through the deep currents of Jellyfish Cove.
* **Keeper Sol** — Lighthouse keeper waiting beneath the northern lights for the beacon to shine again.

---

## Four Chapters + Endless Aurora

| Chapter | Fjord Zone | Goal | Vibe |
| :--- | :--- | :--- | :--- |
| **Chapter 1** | **Morning Pier** | `160 pts` | Crisp morning sky, gentle waves, learning the Sky <-> Sea rhythm |
| **Chapter 2** | **Jellyfish Cove** | `420 pts` | Warm amber sun, faster currents, cooling pearls and stars |
| **Chapter 3** | **Twilight Reef** | `760 pts` | Deep violet dusk, rising spark heat, tactical `HOLD` pauses |
| **Chapter 4** | **Northern Lighthouse** | `1150 pts` | Dancing aurora ribbons, the dark lighthouse ahead — relight the beacon! |
| **Bonus** | **Endless Aurora** | `Infinity` | Unlocked on victory — chase your high score under the northern lights |

---

## Under the Hood: The Four Laws & 5-Stack Reference Kernels

Beneath the cozy puffin arcade runs a serious deterministic architecture built around four fail-closed laws (`INSPIRED_BY != IMPLEMENTS != PROVES`):

1. **$T(T(s)) = s$ (Sky <-> Sea Involution):** Flip twice and you return with zero residual; return within the $\epsilon$-ring for a **Poincaré Return** bonus.
2. **$C(t) < R$ (Spark Ceiling):** Every flap and second builds spark load $C(t)$ toward ceiling $R = 100$. Collect stars, pearls, or shift cleanly to stay cool.
3. **`HOLD` (Safe Waiting Room):** `H` pauses motion at `0.00 V` and cools $C(t)$ gently; elapsed time alone never opens `HOLD` without explicit player input.
4. **`KILL` (Discrete `0.00 V` Cutoff):** Hitting an obstacle or $C(t) \ge R$ triggers an instant `KILL` cutoff, appends the event to the witness log (never erased on retry), and lets you retry the chapter cleanly.

<details>
<summary><strong>5-Stack Verification Suite (<code>make verify</code>) — Godot 4.3, Rust, QNX C11, SystemVerilog RTL &amp; Python</strong></summary>

| Layer | Files | Verification |
| :--- | :--- | :--- |
| **Godot 4.3 Game Core** | [`scripts/game_core.gd`](scripts/game_core.gd), [`scripts/main.gd`](scripts/main.gd), [`scripts/sound_synth.gd`](scripts/sound_synth.gd), [`scripts/story_data.gd`](scripts/story_data.gd) | `37/37` headless checks in [`tests/test_game_core_headless.gd`](tests/test_game_core_headless.gd) |
| **Rust Zero-Float Kernels** | [`rust/ky_engine_v1.rs`](rust/ky_engine_v1.rs), [`rust/millennium_gate_v1.rs`](rust/millennium_gate_v1.rs) | `#![forbid(unsafe_code)]`, exact $\tau \le 27/50$, Doc 171/176/178/181/183/185 invariants |
| **QNX / C11 Zero-Float Gates** | [`c11_qnx/flap_plopp_qnx_gate.c`](c11_qnx/flap_plopp_qnx_gate.c), [`c11_qnx/sluse_3d_gate.c`](c11_qnx/sluse_3d_gate.c), [`c11_qnx/lih_sluse_gate.c`](c11_qnx/lih_sluse_gate.c), [`c11_qnx/ky_kora_sluse.c`](c11_qnx/ky_kora_sluse.c) | `-msoft-float -mno-sse -mno-sse2` + `OBJDUMP_ZERO_FLOAT_OK` on all 4 binaries |
| **SystemVerilog RTL** | [`rtl/lih_sluse_gate.sv`](rtl/lih_sluse_gate.sv), [`rtl/ky_kora_sluse.sv`](rtl/ky_kora_sluse.sv) | `iverilog -g2012` + `vvp` (`7/7` LiH + `7/7` KORA latched-`KILL` parity) |
| **Python Phase-Mirror v0.1** | [`python/phase_mirror.py`](python/phase_mirror.py) | `6/6` zero-float HPIS scenarios, deterministic SHA-256 ledger & tamper detection |

Aligned with [omega-gate-qnx](https://github.com/sololys/omega-gate-qnx) and Zenodo DOIs [`10.5281/zenodo.23244129`](https://doi.org/10.5281/zenodo.23244129) & [`10.5281/zenodo.23244425`](https://doi.org/10.5281/zenodo.23244425).

</details>

---

## License

MIT — see [LICENSE](LICENSE).
