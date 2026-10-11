# Fidelity and conversion status

Reference: `a327ex/SNKRX` at `6b93a64d694d59472375467648868ae4521d6706`.
This is a working first milestone, not a complete or release-ready port.

| System | Current behavior | Remaining work |
|---|---|---|
| Original source | Preserved with recorded hashes | Keep reference pinned when making further changes |
| Roster | All 52 active heroes' catalog data imported; eight tier-one heroes playable | Convert the other 44 heroes before offering them in the shop |
| Shop | Three offers, buy, upgrade, reserves, sell, lock, reroll, reorder | Preview draws uniformly from tier one; original 70/20/10 starting tier weights are stored but not applied until higher-tier abilities exist. Shop XP/leveling awaits those heroes |
| Menus | Owner-requested colorful redesign: hero cards, friendly portraits, recruitment, gold/team panels, hero management, bonuses and onboarding | Deliberately departs from the original visual layout. Uses Roblox Gotham text and code-drawn art; device QA and full options remain |
| Movement | Original turning, bounds, average party speed, spacing and bounce | Distance-interpolated fixed-step trail replaces the original 0.01-second sampled trail; tune against original footage |
| Physics | Local 2D movement, contact damage, knockback, basic separation | Circle contact approximations replace Box2D rotated rectangles and steering forces. This changes feel; do not describe it as exact physics parity |
| Tier-one combat | Original attack ranges, cooldown multipliers, projectile speed, piercing, chains, square area attacks and per-target Swordsman bonus | More projectile collision comparison; original hit-stop, camera motion, trails and particles remain |
| Level-three heroes | Vagrant, Swordsman, Magician, Archer, Scout, Cleric and Arcanist upgrades implemented | Merchant's level-three item reroll needs the item system |
| Healing | Cleric orb timing and count; pickups heal the lowest health percentage by 20% of max | Original orb impulse, spin and magnetic attraction are not yet simulated |
| Classes | Original thresholds and stat tables preserved; Explorer's reachable tier-one bonus works | All class-specific combat effects need verification as additional heroes unlock them |
| Enemies | NG+0 basic Seeker stat curve and pursuit | Elite enemies (including arena 2's speed boosters and shooters), enemy projectiles, bosses and original steering |
| Waves | Standard opening pattern, 8/10/12 counts, first two arenas, telegraph and stagger | Arena 2's 5% distributed-pattern chance is not yet used; spawn suppression differs; later arenas and boss encounters remain |
| Rewards | Original first-two-arena gold rewards and pre-reward interest, including Merchant | Gold pickups, item selection, full run/loop/NG+ progression |
| Assets | Original assets retained in repository; original title font rendered from permitted asset | Body font, icon, music and sound licenses/imports need individual handling |
| Roblox integration | Standalone place/model, managed installer, scalable full-screen GUI, keyboard/mouse/D-pad and basic touch buttons | Persistent saves, achievements, platform options and device QA |

## Intentional code-over-tooltip choice

Vagrant level-three damage/attack-speed uses the executable source's **+10% per
active class**, multiplied by the Explorer bonus. The original tooltip says
+15%. Preserve this distinction until the owner chooses to fix upstream bugs.
Level-one Vagrant receives the Explorer bonus including its own active set.

## Validation

- 24 CLI behavioral tests: source stat values, classes, shop transactions,
  upgrade/reserve math, frame-rate equivalence, wall reflection, trail spacing,
  pause, projectiles/chains/ricochets, healing, death and arena transitions.
- Original balance tables compared with the generated module; source hashes
  checked against the pinned upstream snapshot.
- Luau syntax compilation for all source modules; strict analysis for Rules
  and Run and analysis of the simulation.
- Studio Place2: menus rendered, three heroes purchased, arena 1 completed
  naturally with 18 kills and +3 gold, return to shop verified, pause froze the
  simulation, console had no runtime errors. Revised title/shop screens were
  visually inspected; background covers the full viewport behind the top bar.

## Next conversion pass

1. Port remaining opening-game shop tiers and their real abilities; enable
   original shop probabilities rather than substituting attacks.
2. Finish elite enemies/distributed waves and match Box2D collision behavior.
3. Add items and level-three class interactions, then the full arena/boss loop.
4. Resolve and import remaining original visual/audio assets, then add saving.

UI redesign validation: Studio title/shop screenshots inspected; recruitment, hero details, team reordering, bonus dialog, and battle entry exercised without console errors. The 24 behavior tests still pass.
