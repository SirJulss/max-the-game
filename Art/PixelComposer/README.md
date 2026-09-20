# Pixel Composer effects

`Max-VFX.pxc` is the editable source for the game's original effect pack. The
matching JSON file exposes the complete graph and shader formulas for review.
Pixel Composer 1.21.9 rendered the PNGs in `Assets/FX/PixelComposer`; Python only
authors the project data and does not draw the exported images.

Each effect uses a real 12-frame timeline. The `effect_phase` float has keyframes
from 0 to 1. Select a `Max_*` HLSL node and play the timeline to preview its
animation. Its parallel Glow node applies the soft bloom inside Pixel Composer.
Native Render Spritesheet nodes pack both branches, and Export nodes save the
base and `_glow` variants. Godot only selects frames, positions, scales, rotates,
and tints these imported textures.

All strips are 1536 × 128 RGBA: twelve horizontal 128 × 128 frames. Each frame is
centered at (64, 64), with a nominal 96-pixel footprint and room for bloom. Ring
warnings retain an outer radius of 48; their interior ripple animates. Directional
effects face right, except the jet flame, whose tapered tip points left (rotate it
by −90° for downward exhaust). The bottle is upright. Shadow is circular so Godot
can flatten it once. Bottle and beer puddle contain color; other effects are white
tint masks.

The pack includes ring, filling disc, melee sector, charge lane, crosshair,
expanding impact, sweeping slash, projectile, flickering jet flame, rippling beer
puddle, bottle glint, breathing shadow, and halo. The base/glow toggle switches
between actual separately exported textures. Ambient halo and shadow playback
uses the base export in both modes: those already contain their authored soft
falloff, and a second Glow pass makes their translucent center too hard at large
scales. The other eleven effect families use the native-Glow variant when enabled.

To regenerate the editable graph for this checkout, run:

```powershell
python tools/pixelcomposer_pack.py
```

This updates export destinations to the current checkout. The HLSL authoring
nodes require Pixel Composer on Windows; exported PNGs work on every Godot
platform. Open the resulting PXC,
render the complete timeline, then press **F6 (Export All)**. Render the full
timeline before exporting or saving to populate every spritesheet cell. Export
on Save is enabled. Export on Update is disabled so editing and playback do not
continually write 26 files. The generator also accepts `--kind`, `--project`, and
`--output-dir` for isolated experiments. `manifest.json` records the delivered
source/export hashes, renderer version, frame layout, and orientations; refresh
those hashes when deliberately re-exporting a changed pack.

Pixel Composer documents `PixelComposer.exe project.pxc --headless`, but the
installed Steam 1.21.9 build failed during headless node initialization. These
assets were rendered in its normal application instead. The user's existing
projects are not part of this pipeline.

Format references: [official CLI documentation](https://docs.pixel-composer.com/misc/command_line.html),
[export documentation](https://docs.pixel-composer.com/nodes/compose/export/export.html),
and the [public project loader](https://github.com/Ttanasart-pt/Pixel-Composer/blob/026bac8a97fcc4d2a1b6dc551bfd31ee6150fab9/scripts/load_function/load_function.gml).
