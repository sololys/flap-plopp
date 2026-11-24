# Flap & Plopp

A cute, energetic 2D arcade game built with **Godot 4.3** for **GitHub Game Off (Theme: SHIFT)**.

Guide a cheerful little puffin across the summer fjord: **FLAP** through the sky, hit **SHIFT** to **PLOPP** straight underwater where buoyancy flips gravity upside down, dodge striped buoys and glowing jellyfish, and chain near-surface **SHIFT** combos!

## Controls

| Action | Keyboard | Mouse |
| --- | --- | --- |
| **Flap up** (in sky) / **Dive down** (underwater) | `Space` / `W` / `Up` | Left Click |
| **SHIFT** (`PLOPP!` into water / `SPLASH!` to sky) | `Shift` / `S` / `Down` | Right Click |
| **Quick Restart** | `Space` or `R` | Left Click |

## Features

* **Two-medium SHIFT physics:** Gravity pulls down in the sky; buoyancy lifts up underwater.
* **Near-surface SHIFT combos:** Time your plunge or splash near the waves to build `x2`–`x8` score multipliers.
* **100% procedural visuals & audio:** Drawn in Godot 4.3 `_draw()` with procedural 16-bit PCM WAV sound effects (`flap`, `plopp`, `splash`, `pickup`, `bonk`) — zero external assets required.

## Run & Verify

```bash
# Play locally in Godot 4.3
godot --path .

# Run headless verification suite
make verify
```

## License

MIT — see [LICENSE](LICENSE).
