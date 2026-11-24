# Flap & Plopp: The Fjord Shift

A cute, energetic 2D arcade adventure built with **Godot 4.3** for **GitHub Game Off (Theme: SHIFT)** — where a little puffin named **Pip** carries a golden spark across four fjord chapters to relight the Northern Lighthouse.

## The Four Laws of the Fjord

* **$T(T(s)) = s$ (Involution):** Press `SHIFT` to flip between **Sky** (`FLAP`) and **Sea** (`PLOPP`). Flip twice and you are always home — completing a clean `T(T(s)) = s` loop cools your spark and awards bonus points.
* **$C(t) < R$ (Capacity Bound):** Every moment and flap builds spark load $C(t)$ toward ceiling $R = 100$. Collect stars/pearls and chain clean `SHIFT` flips to stay strictly below $R$.
* **`HOLD` (Safe Stasis):** Press `H` anytime to enter a golden `HOLD` bubble (`0.00 V`). Motion pauses, $C(t)$ cools gently, and time alone never opens `HOLD` until you explicitly press `SPACE` or `H`.
* **`KILL` (0.00 V Cutoff):** Hitting $C(t) \ge R$ or bonking an obstacle triggers an instant `KILL` cutoff, appends the event to the journey witness log (never erased on retry), and lets you retry the current chapter cleanly.

## Controls

| Action | Keyboard | Mouse |
| --- | --- | --- |
| **Flap up** (Sky) / **Dive down** (Sea) / **Next dialogue** | `Space` / `W` / `Up` / `Enter` | Left Click |
| **SHIFT** ($T(s)$: `PLOPP!` / `SPLASH!`) | `Shift` / `S` / `Down` | Right Click |
| **`HOLD`** (enter / release safe bubble) | `H` | — |
| **Skip Dialogue** / **Restart Story** | `Esc` / `R` | — |

## Architecture & KY Engine v1 ($\kappa_{27}$) Reference

Alongside the playable Godot 4.3 game, [rust/ky_engine_v1.rs](rust/ky_engine_v1.rs) provides a zero-dependency, zero-float Rust reference implementation of **KY Engine v1 ($\kappa_{27}$)** enforcing $x_{t+1} = \Omega(\Pi_K(\Phi(x_t)))$ with the strict lifecycle `○ (RAW) -> ◇ (ESTIMATE) -> □ (STRUCT) -> ⬡ (VIABILITY) -> ◉ (COMMITTED)` and chained witness log verification for both `RealityForgeRules` and `FlapPloppRules`.

## Run & Verify

```bash
# Play locally in Godot 4.3
make play

# Run full verification suite (Godot 4.3 16/16 + Rust KY Engine v1 -D warnings)
make verify
```

## License

MIT — see [LICENSE](LICENSE).
