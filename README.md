# Flap & Plopp: The Fjord Shift

A cute, energetic 2D arcade adventure built with **Godot 4.3** for **GitHub Game Off (Theme: SHIFT)** — where a little puffin named **Pip** carries a golden spark across four fjord chapters to relight the Northern Lighthouse.

## The Four Laws of the Fjord

* **$T(T(s)) = s$ (IKS Involution $F(s) = 1 - s$) & Poincaré Return:** Press `SHIFT` to flip between **Sky** (`FLAP`) and **Sea** (`PLOPP`). Flip twice and you return with zero residual (`F(F(s)) == s`); landing within the $\epsilon$-neighborhood of your departure altitude triggers a **Poincaré Return** bonus.
* **$C(t) < R$ & Four-Indicator Gate ($\prod_{i=1}^4 \chi_i = 1$):** Every moment and flap builds spark load $C(t)$ toward ceiling $R = 100$. All four indicators (`HPIS`, `TOR`, `WORM`, `RFM`) must hold simultaneously (`INSPIRED_BY != IMPLEMENTS != PROVES`).
* **`HOLD` (Analytical Waiting Room, 11.2 Hz Pulse):** Press `H` anytime to enter a golden `HOLD` bubble (`0.00 V`). Motion pauses, $C(t)$ cools gently, and time alone never opens `HOLD` until you explicitly press `SPACE` or `H`.
* **`KILL` (Discrete 0.00 V Cutoff):** Because no smooth holomorphic function separates admissible from forbidden domains, hitting $C(t) \ge R$ or bonking an obstacle triggers an instant `KILL` cutoff, appends the event to the witness log (never erased on retry), and lets you retry the current chapter cleanly.

## Controls

| Action | Keyboard | Mouse |
| --- | --- | --- |
| **Flap up** (Sky) / **Dive down** (Sea) / **Next dialogue** | `Space` / `W` / `Up` / `Enter` | Left Click |
| **SHIFT** ($T(s)$: `PLOPP!` / `SPLASH!`) | `Shift` / `S` / `Down` | Right Click |
| **`HOLD`** (enter / release safe bubble) | `H` | — |
| **Skip Dialogue** / **Restart Story** | `Esc` / `R` | — |

## Architecture: KY Engine v1, Millennium Engine & QNX C11 Gate

Alongside the playable Godot 4.3 game, the repository includes three zero-dependency, zero-float reference kernels enforcing the same four laws ($T(T(s)) = s$, $C(t) < R$, `HOLD`, `KILL`):

* **KY Engine v1 ($\kappa_{27}$, Rust):** [rust/ky_engine_v1.rs](rust/ky_engine_v1.rs) — 7-module fail-closed kernel (`○ -> ◇ -> □ -> ⬡ -> ◉`) with chained witness log verification (`RealityForgeRules` + `FlapPloppRules`).
* **Millennium Engine v1 (Rust):** [rust/millennium_gate_v1.rs](rust/millennium_gate_v1.rs) — $O(1)$ P-verifiable 7-monolith admission gate with exact involution ($T^2 = I$ in `HOLD` phase space $M$), exact rational boundary threshold $\tau \le 27/50$ on $\partial M \to \{\text{OPEN}, \text{KILL}\}$, Double-Pulse check ($\psi_{\text{Rx}}(\psi_{\text{Tx}}(x)) \equiv x$), discrete epistemic horizon ($t < t^*$), Design Invalidity ($U_{\text{safe}} = \emptyset \to \text{KILL}$), Constrained Decision Collapse (`|A| -> 1`), and $C(t) < R$ enforcement.
* **QNX Neutrino 8.0 / C11 Gate:** [c11_qnx/flap_plopp_qnx_gate.c](c11_qnx/flap_plopp_qnx_gate.c) — zero-float C11 consequence gate (`OBJDUMP_ZERO_FLOAT_OK`, exact $\tau \le 27/50$, discrete $t < t^*$ horizon, Design Invalidity check, Double-Pulse involution, monotonic-clock `HOLD` phase-space invariant), aligned with [omega-gate-qnx](https://github.com/sololys/omega-gate-qnx) and Zenodo DOIs [`10.5281/zenodo.23244129`](https://doi.org/10.5281/zenodo.23244129) & [`10.5281/zenodo.23244425`](https://doi.org/10.5281/zenodo.23244425) (`INSPIRED_BY != IMPLEMENTS != PROVES`).

## Run & Verify

```bash
# Play locally in Godot 4.3
make play

# Run full tri-stack verification (Godot 16/16 + Rust KY/Millennium + C11 QNX 0-float)
make verify
```

## License

MIT — see [LICENSE](LICENSE).
