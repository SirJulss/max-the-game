# Max The Game

**Max The Game** is a 2.5D roguelike streamer simulation with action-packed combat.  
The goal is to help Max become the best streamer in the world.  

He must manage his **basic needs** like hunger, hygiene, and sleep while fighting enemies, upgrading equipment, and reaching a daily view goal.  
Combat is dynamic and offers **attack combos, sprinting, parrying, blocking**, and more. Using too much energy forces him to stop streaming early, making strategy essential.

---

## Project Structure
```
max-the-game/
├── Assets/ # All graphics, audio, and font resources
│ ├── Textures/ # Images, icons, textures
│ ├── Sprites/ # Spritesheets or individual sprites
│ ├── Audio/ # Sound effects and music
│ ├── Fonts/ # Fonts used in the game
│ └── Materials/ # Materials, shaders
├── Scenes/ # All Godot scenes (.tscn)
│ ├── Main.tscn
│ ├── Levels/ # Level-specific scenes
│ └── UI/ # UI scenes
├── Scripts/ # All scripts (GDScript or C#)
│ ├── Player/ # Player logic
│ ├── Enemy/ # Enemy logic
│ └── UI/ # Menus, HUD, interface
├── ProjectSettings/ # Optional: project settings
├── .gitignore # Ignored files like cache and import files
├── project.godot # Main Godot project file
└── README.md # This file
```
---

> **Note:** Empty folders like `Assets/` or `Scripts/` should contain a `.gitkeep` file so Git tracks them.  
> The `.gitignore` ensures automatically generated Godot files like `.import` or `.godot` are not pushed to the repository.
