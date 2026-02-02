# Soapbox Metal

A simple 3D physics demo built with **Godot 4.5** featuring a controllable soapbox cart that can push objects around the world.

## About

Soapbox Metal is a basic game prototype demonstrating:
- Character movement using `CharacterBody3D`
- Physics interactions with `RigidBody3D` objects
- Camera following the player
- Basic lighting with a directional light

The player controls a box-shaped soapbox cart and can push around a physics-enabled object (affectionately named "Funny hat" with a squid 3D model).

## Controls

| Action       | Keys                    |
|--------------|-------------------------|
| Move Forward | `W` or `Up Arrow`       |
| Move Back    | `S` or `Down Arrow`     |
| Move Left    | `A` or `Left Arrow`     |
| Move Right   | `D` or `Right Arrow`    |

## Requirements

- **Godot Engine 4.5** or later
- Rendering: Forward Plus (requires a GPU with Vulkan support)

## How to Run

### Option 1: Open in Godot Editor

1. **Download and install Godot 4.5** from [godotengine.org](https://godotengine.org/download)
2. **Clone this repository:**
   ```bash
   git clone https://github.com/your-username/SoapBox-Metal.git
   ```
3. **Open Godot Engine**
4. Click **"Import"** and navigate to the project folder
5. Select the `project.godot` file and click **"Import & Edit"**
6. Press **F5** (or click the Play button) to run the game

### Option 2: Run from Command Line

If you have Godot installed and added to your system PATH:

```bash
# Navigate to the project directory
cd SoapBox-Metal

# Run the project
godot --path .
```

Or run the editor:
```bash
godot --editor --path .
```

## Project Structure

```
SoapBox-Metal/
├── project.godot       # Godot project configuration
├── world.tscn          # Main scene (entry point)
├── soapbox.tscn        # Player soapbox cart scene
├── soapbox.gd          # Player movement script
├── Funny hat.tscn      # Pushable physics object
├── player.glb          # 3D model (squid)
└── icon.svg            # Project icon
```

## Gameplay

- Move around the 60x60 unit ground plane using WASD or arrow keys
- Push the "Funny hat" object around using your soapbox cart
- The cart has gravity, so it will fall if moved off the ground

## Technical Details

- **Player Speed:** 14 units/second
- **Fall Acceleration:** 75 units/second²
- **Push Force:** 50 units

