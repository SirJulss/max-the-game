# Design and implementation notes

## Run structure

A run contains six streaming days. Each morning Max walks through his apartment to the PC, selects a game, and streams from 08:00 to 16:00. A complete shift takes 64 seconds of active play, then donations are banked and the item shop opens. The player answers a knock at the door and clears a front-yard encounter before the next morning. Day-three and day-six encounters include bosses. A sixth clear wins; losing all HP ends the run.

The viewer goals are **80, 240, 900, 3,200, 12,000, and 50,000**. Passive growth and successful minigame audience rewards scale with the goal. Donation payouts use their own modest day scaling. Money therefore stays useful throughout the run instead of inflating with audience numbers. The goal grants a bonus; it neither ends a stream early nor blocks the shop if missed.

### Streaming choices

| Category | Main advantage | Cost |
| --- | --- | --- |
| Turnip Farm | Low heat and steady progress; harvest target turnips | Lower tips and slower growth |
| Ranked Rush | Fast viewer growth; fire at NPC targets | Highest passive heat |
| Goose Court | Highest passive donation rate; time a honk | More heat than the cozy category |

All three games share a clear timing mechanic: press Space inside the 40–60% sweet spot. Success triggers the category's action animation and adds viewers, tips, and hype while slightly lowering heat. Misses reduce hype and raise heat. A short cooldown prevents repeated input from farming rewards.

Gameplay is continuous throughout the 64-second shift, without interrupting narrative prompts. Hitting the goal increases donations and heat growth for the remainder of the shift. At 16:00 the controller automatically moves to the shop, whether or not the audience target was met.

### Economy and builds

The initial wallet is $20. Banking grants accumulated tips plus a day-dependent bonus when the viewer goal was met. Defeated enemies and cleared encounters pay additional bounties. Each shop has four offers: a one-use heal, one unowned weapon when available, and items drawn from streaming, combat, and synergy pools. Rerolls cost `6 + 3 × day + 4 × previous rerolls`. Items are bought once per day, many stack across days, and subsequent stacks cost more. Rerolls preserve sold flags; full-health healing is unavailable.

Build examples already supported:

- **Rage economy:** generate heat with Ranked Rush or Fiber, convert heat into damage with Rage-to-Wage Converter, then earn extra KO donations with Hater Investment Fund.
- **Game specialist:** Clip Goblin improves successful minigame rewards; webcam and tip-jar upgrades turn active streaming into higher viewer counts and a healthier wallet.
- **Yard sustain:** Parasocial Vampire heals on KOs, acoustic armor reduces incoming hits, and a lawn moderator fires supporting shots.
- **Redemption Arc:** each clear returns fans worth 8% of the next day's goal per stack, capped at 30% of that goal, and restores extra health.

Purchased weapons remain unlocked during the run and can be re-equipped in the shop. The keyboard has a three-hit melee chain, the Banhammer has wider, heavier swings and strong interruption, and Caps Lock fires ranged shots with a fan on the third attack. Touch Grass is a shared cooldown ability; dash provides a brief invulnerability window.

Reaching day three unlocks the Ragebait Rookie and Comfort Creator starting sidegrades. Ragebait trades health and additional heat for donations and KO income. Comfort trades attack damage for viewers and armor. Persistent progression records runs, wins, best day, and peak audience; combat-stat purchases reset with each run.

## Encounter content

| Enemy | Pressure and response |
| --- | --- |
| Tan | Approaches for a short telegraphed melee swipe; manage spacing |
| Louis | Throws arcing beer bottles at marked landing spots; leave the splash and lingering damaging puddle |
| Julian | Rises with a jetpack and becomes untargetable, then slams a marked position; avoid or dash through the expanding shockwave |
| Modzilla, day 3 | Large stomps and charges; gains reinforcements below half health |
| The Algorithm, day 6 | Delayed advertising hazards and projectile rings; adds pressure below half health |

Heat increases regular enemy count and enemy health/damage. Encounters spawn enemies over time instead of placing the full wave at once. Red tells, hit flashes, knockback, attack effects, health feedback, and sound distinguish threat and impact. Every fifth KO restores a little health, and clearing a yard also restores health.

## Existing work retained

| Existing material | Use in the new game |
| --- | --- |
| `Scenes/Levels/Player/Player.tscn` | Instanced as Max in the combat arena |
| `Assets/Player/Idle/MaxIdle.png`, `Walk/MaxWalk.png`, `bodycheck/max_bodycheck.png` | Original idle, eight-direction movement, and attack animations |
| `src/state_machine/` and `src/Player/game_input_events.gd` | Refactored movement, attack, dash, animation, and state-transition foundation |
| `Assets/Gameplay/Streaming/Pc/PCOverlay.png` | Streaming setup and PC presentation |
| `Assets/UI/Button.png`, `ButtonH.png`, `ButtonI..png` | Button surfaces and interaction states |
| `Assets/npc/*.ase` and matching exported `.png` sheets | Original Tan, Louis, and Julian characters, with front/back/right facing sheets; reused in enemies and minigames |
| `Assets/Sounds/Music/MaxLoop_Nostalgic_Keys.wav` | Title music |
| `Assets/Sounds/Music/MaxBackgroundLofi.wav` | Studio music |
| `Assets/Sounds/Music/MaxFIghtingTrap.wav` | Combat music |

Apartment/yard composition, minigames, telegraphs, projectiles, and other feedback combine retained artwork with code-drawn elements. The original NPC source files remain available, and `tools/export_aseprite.py` creates the committed PNG exports without requiring an Aseprite installation. Small sound effects are synthesized locally. The supplied source assets retain their existing provenance; this change does not grant new rights to them.

## Code map

| Path | Responsibility |
| --- | --- |
| `Scenes/Game/Main.tscn` | Project entry scene |
| `src/run/game.gd` | Phase transitions, UI, input, checkpoint and profile files |
| `src/run/run_data.gd` | Scene-independent economy, streaming simulation, offers, builds, validated save payloads |
| `src/ui/stream_stage.gd` | Three timing minigames inside the original animated PC |
| `src/combat/combat_arena.gd` | Spawning, attack resolution, projectiles, hazards, rewards, security |
| `src/combat/hater.gd` | Regular enemies and boss patterns |
| `Scenes/Levels/Player/player.gd` | Combat stats, aim, damage, healing, cooldowns, animation mapping |
| `src/presentation/` | Studio/yard backdrop and music/effects playback |

The project uses native GDScript and Godot nodes, with no autoload requirement or external runtime dependencies. Legacy exploratory scenes may remain in the repository; the configured entry point is `Scenes/Game/Main.tscn`.

## Persistence and testing

Run payloads are versioned and validated before replacing live state. Checkpoints are allowed in `setup` and `shop`; the controller presents `setup` checkpoints as apartment mornings. They retain HP, currency, purchases, equipped weapon, returning fans, shop inventory, sold flags, reroll costs, and RNG state. RNG state is serialized as text to preserve its full integer precision through JSON. Stream and combat callbacks cannot deposit a reward twice. The controller saves through a temporary file and rename; win/loss removes the run checkpoint but retains the profile.

At implementation verification, **235 model checks**, **60 game-flow checks**, and **18 combat-smoke assertions** passed. The GitHub Actions workflow imports assets and runs the same suites on Linux using official Godot 4.5.1; a hosted CI run still requires the changes to be pushed. Headless tests require no .NET runtime or export templates.

The flow fixture deliberately raises damage to test all six days and both boss transitions quickly. It must not be interpreted as balance evidence. The optional input-driven probe uses normal attack, movement, dash, and special inputs with fixed sample builds:

```sh
godot --headless --path . --script src/combat/balance_probe.gd
```

It reports win/loss, HP, time, and KOs for all three weapons on days 1, 3, and 6. It is a development aid rather than a CI pass/fail gate or a substitute for human playtesting. The test suites and probe instantiate no live-user persistence; the controller integration test additionally requires `-- --test`.

## Deliberate limits

Content is concentrated in three timing games, three weapons, three regular enemies, two bosses, one apartment, and one yard. The minigames share a timing mechanic with different targets, actions, tempos, and economic profiles. There is no equipment inventory screen beyond shop weapon selection, no procedural map or endless mode, and no connection to real streaming services. Keyboard/mouse and a desktop-sized landscape display are the supported inputs/layout. Original pixel art, procedural effects, and generated audio favor readable feedback. Difficulty and long-term replay value still benefit from human playtesting.
