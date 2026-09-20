# Max: Chat Has Hands

A small 2D action roguelite about turning a tiny stream into a very large doorstep problem.

**Apartment → walk to the PC → play a stream from 08:00–16:00 → buy items → fight Haters outside → next morning.** Clear six days and defeat the Algorithm to win. Losing a fight ends the run; reaching day three unlocks two alternative starting styles.

## Play

Open `project.godot` in **Godot 4.5 or newer, Standard edition**, let the assets import, and press **F6** with `Scenes/Game/Main.tscn` open, or **F5** to run the project. The game is GDScript and does not require .NET. It uses the Compatibility renderer and a 1280×720 interface.

From a terminal with Godot on `PATH`:

```sh
godot --editor --path . --import --quit
godot --path .
```

The automated workflow uses the [official Godot 4.5.1 release](https://github.com/godotengine/godot/releases/tag/4.5.1-stable). Local headless checks have also passed on Godot 4.7.2.

For a standalone Windows build, install the matching Godot export templates, then use the included **Windows Desktop** preset or run `godot --headless --path . --export-release "Windows Desktop" export/Max.exe`. Keep `Max.exe` and `Max.pck` together. Include Godot's MIT license/third-party notices and `Assets/Fonts/OFL.txt` when distributing the build.

## Controls

| Context | Input | Action |
| --- | --- | --- |
| Apartment | WASD / arrow keys | Walk to the PC |
| Apartment | E near the PC | Choose a game |
| Turnip Farm | Space or the harvest button | Harvest when the marker enters the wide green zone |
| Ranked Rush | Click the marked target | Aim at moving targets; Space in the timing lane's green zone gives an assisted shot |
| Goose Court | A / D, arrows, or the left/right buttons | Flower: free the goose (A). Stolen bread: bonk it (D). Answer before the timer expires |
| Shop | Mouse | Buy items, reroll stock, or switch owned weapons |
| Combat | WASD / arrow keys | Move |
| Combat | Mouse | Aim |
| Combat | Hold left mouse / J | Attack and chain the weapon's combo |
| Combat | Space / Shift | Dash with invulnerability |
| Combat | Right mouse / K | Touch Grass pulse: knock enemies back and clear nearby bullets |
| Global | Esc | Pause and access the main menu |
| Global | M / F11 | Toggle audio / fullscreen |
| Pause menu | SHAKE + BLOOM | Toggle impact shake and imported effect glow; the preference is saved |

## What's in this version

- Three distinct minigames inside the original PC artwork: harvest timing in Turnip Farm, aimed shots in Ranked Rush, and quick left/right reactions in Goose Court.
- A complete eight-hour stream takes **64 seconds**. Playing well earns viewers, hype, and tips; no narrative choices interrupt the game.
- Consecutive successes build a combo: every three adds 10% to action viewers and tips, capped at +30%. A miss breaks the streak; extra input during recovery does nothing.
- Viewer goals rise from **80 to 50,000**. Hitting the goal earns a bonus; the shift still finishes at 16:00. Missing it pays the donations you earned and also advances to the shop.
- A stock keyboard, sweeping Banhammer, and ranged Caps Lock Cannon; purchased weapons can be swapped in the shop.
- Eighteen shop items covering equipment, healing, weapons, combat stats, security, and stream/combat synergies. Shops show four items and offer increasingly expensive rerolls.
- Three enemies made from the original NPC sprites: Tan commits to a marked frontal swipe, Louis throws beer bottles with area damage, and Julian uses a jetpack ground slam. Enemies arrive with a warning and space around Max. Modzilla and the Algorithm appear on days three and six.
- Impact-driven screen shake, 13 animated Pixel Composer effects with baked Glow, and 19 imported 8-bit sound effects. The pixel HUD stays sharp and still; the original music is retained.
- A complete start, win, loss, restart, pause, and checkpoint flow, with saved run records and starting-style unlocks.

The game reuses the original project's Max animations, Player scene, state-machine foundation, music, streaming PC art, UI buttons, and NPC character artwork. See [design and asset notes](docs/DESIGN.md) for the implementation map.

The editable [Pixel Composer project](Art/PixelComposer/Max-VFX.pxc) contains real 12-frame animations and native Glow nodes. Its [export notes](Art/PixelComposer/README.md) explain how to edit and regenerate the imported sprite sheets. Pixel Composer renders the effects; Godot only plays and places their frames.

## Saves

Progress is saved in the apartment/game selection, after a stream, after shop purchases/rerolls/loadout changes, and after clearing a yard. **Continue resumes the latest checkpoint**, including the current shop's stock and sold items. Leaving during a stream returns to that morning's apartment; leaving during a fight returns to the preceding shop. Win or loss clears the run checkpoint.

Records and style unlocks are stored separately. The files are `user://run_v1.json` and `user://profile_v1.json`; use Godot's **Project → Open User Data Folder** to find them. Starting a new run replaces the previous checkpoint.

## Test

Import first on a fresh checkout, then run:

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/model_test.gd
godot --headless --path . --script tests/stream_stage_test.gd
godot --headless --path . --script tests/audio_test.gd
godot --headless --path . --script tests/pixel_fx_test.gd
godot --headless --path . --script tests/screen_effects_test.gd
godot --headless --path . --script tests/game_flow_test.gd -- --test
godot --headless --path . --script src/combat/combat_smoke.gd
```

On Windows, `tools/test.ps1 -Godot 'C:\path\to\Godot_console.exe'` runs the same checks. The flow test requires `-- --test`, which disables game profile and checkpoint reads, writes, and deletions. The other tests instantiate the model or arena without persistence.

The model suite checks economy, saves, and nine complete game/style combinations. The flow suite exercises the real UI/controller and arena signals, using deliberately high damage to make transitions deterministic. Combat smoke checks attack geometry, state-machine input, damage rules, enemy patterns, and encounter completion. These checks verify functionality; they do not establish human difficulty or visual quality. An optional input-driven combat probe is documented in [DESIGN.md](docs/DESIGN.md).

This is a focused single-player desktop game: one apartment, one yard, six days. It has no network streaming integration, online multiplayer, procedural map generation, or controller support.
