# Asset provenance

The repository's MIT license covers code. Upstream explicitly states that
assets have separate licenses. Original assets remain in their original
folders; the Roblox package does not assume that all are MIT licensed.

| Asset | Roblox use | Permission/source |
|---|---|---|
| FatPixelFont.ttf | Original SNKRX title rendered as GUI rectangles in `TitleGlyphs.luau` | [Tyemu's author page](https://tyemu.itch.io/fatfuckfont): “Free to use in any form you can imagine.” Checked 2026-10-11. Credit: Tyemu |
| PixulBrush.ttf | Not embedded; Roblox Code font is used temporarily | [Mercyssh's author page](https://mercyssh.itch.io/pixulbrush-a-bitmap-font) does not provide clear reuse terms; verify before packaging |
| Class/item PNG icons | Not embedded; current class symbols are code-drawn substitutes | Individual original-asset permission review pending |
| Kubbi music | Not embedded | Refer to original in-game credits; license/import review pending |
| Sound effects | Not embedded | Multiple credited authors and licenses; review individually |

Generated title data is reproducible using `tools/import-title-font.py` and
the unchanged original font. Palette values and geometric hero rectangles
come from the original code (`shared.lua`, `player.lua`, `buy_screen.lua`).
