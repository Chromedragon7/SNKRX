# SNKRX Roblox port — first playable milestone

This branch starts a faithful port of **a327ex's SNKRX**. The original LÖVE game,
assets and history remain in this repository. The Roblox implementation lives
under `roblox/`; the original game's source files have not been rewritten.

## Play

Open [`dist/SNKRX.rbxlx`](dist/SNKRX.rbxlx) in Roblox Studio and press **Play**.
Choose **arena run**, click heroes to buy them, then choose **GO!**.
Steer with **A/D**, **left/right arrows**, or **D-pad**. **P** pauses.
Touch steering buttons appear on touch devices (touch interaction is not yet
device-tested). The shop supports 1/2/3 purchases, right-click selling, and the
small arrows beside each party member to change its position.

The current build is deliberately labeled a **preview**: eight tier-one heroes
and the first two arenas. It ends with a completion screen, not an invented
replacement for the rest of the original game. It is single-player per client,
with no persistent saves, monetization or shared competitive state yet.

Alternative installation: paste `dist/install.luau` into Studio's Command Bar
in a test place. It creates `StarterPlayerScripts/SNKRXPort`. It refuses to
overwrite an unmanaged folder of that name. `dist/SNKRX.rbxmx` is also provided
for manual model import into `StarterPlayerScripts`.

## What is preserved

- All **52 active hero entries** across the original four tier pools, their
  names, class membership, colors and costs are imported from `main.lua`.
- Original class stat multipliers, shop odds, 25-arena reward and wave tables
  are retained as source data, including entries not enabled in this milestone.
- The playable heroes are Vagrant, Swordsman, Magician, Archer, Scout, Cleric,
  Arcanist and Merchant. Their base stats, cooldowns, attack ranges and the
  implemented level-three effects come from the original executable code.
- The 480×270 coordinate space, arena bounds, 1.66π turn rate, party-average
  movement speed, 10.4-unit following distance, and wall reflection remain.
- Three-card shop, 3 starting gold, 2-gold rerolls, seven distinct heroes,
  3/9-copy upgrades, reserve sale values, locked cards, rewards and interest.
- The original minimalist menu arrangement: shop left, classes in the middle,
  party at right, hover descriptions, compact icons and green GO button. The
  title uses the original FatPixelFont lettering. A full-screen background
  covers the area behind Roblox's top bar.

**Preserved data does not mean all corresponding behavior is implemented.**
See [PORT_STATUS.md](PORT_STATUS.md) for the current gaps and exact deviations.

## Build and verify

Requires Node.js; no npm packages are needed. Tests use the official Luau CLI
(verified with version 0.742). Point `LUAU_BIN` at the directory containing
`luau`, `luau-compile`, and `luau-analyze` if they are not on PATH.

```text
node roblox/tools/import-source.mjs --check
node roblox/tools/test.mjs
node roblox/tools/build.mjs
```

`build.mjs` rewrites relative CLI module imports to Roblox ModuleScript
references and produces an XML place, an XML model, a Studio installer, and
Rojo-compatible source under `dist/src`. If using Rojo, build first and use
`roblox/default.project.json`. Do not point Rojo directly at `src`, which uses
CLI imports for tests.

`import-source.mjs` regenerates the source-derived data. `upstream.json` pins
the source commit and hashes; the test command checks that those files have
not silently changed. Original title lettering can be regenerated with
`python roblox/tools/import-title-font.py` using Pillow. Normal builds do not
need Python or Pillow.

## Architecture

`SourceData` contains generated source tables. `Rules` holds ported formulas.
`Run` owns shop and progression state. `Simulation` is an engine-independent
2D simulation running at 120 fixed steps per second. `Client` renders the
game using Roblox GUI objects and handles input. No downloaded scripts or
remote-code execution are used at runtime.

Original code: copyright (c) 2021 a327ex, [MIT](../LICENSE).
Asset permissions are separate; see [ASSETS.md](ASSETS.md).
