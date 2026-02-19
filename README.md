# Core Systems

## Progressive Damage System

Damage is impulse-based.

When the vehicle collides with objects:

-   Damage accumulates per wheel
-   Suspension stiffness degrades
-   Suspension travel reduces
-   Engine power scales down
-   Steering effectiveness reduces (front wheels especially)

Only when damage exceeds a threshold do wheels detach.

------------------------------------------------------------------------

## Wheel Detachment

-   Wheels detach independently.
-   Only wheels on the impacted side receive damage.
-   Detached wheels:
    -   Become physics `RigidBody3D`
    -   Inherit velocity
    -   Receive impact impulse + spin
-   Handling becomes progressively worse as wheels degrade.

------------------------------------------------------------------------

## Breakable Bumpers

Front and rear bumpers:

-   Absorb damage before wheels.
-   Reduce wheel damage while attached.
-   Detach into physics objects when destroyed.
-   Protect front/rear wheels until removed.

------------------------------------------------------------------------

## Boost System

-   Activated via **Spacebar**
-   Adds temporary engine force
-   Has duration and cooldown
-   AI can trigger boost when preparing to ram

------------------------------------------------------------------------

## AI Rammer

The enemy soapbox:

-   Always pushes forward aggressively
-   Slight steering bias prevents over-correction
-   Leads the player slightly
-   Boosts when close
-   Minimal alignment logic
-   Simple unstuck behavior
-   Optional --- can be toggled on/off before runtime

This AI is designed to **ram like a truck**, not race cleanly.

------------------------------------------------------------------------

## Obstacle System

Random obstacles spawn across the arena:

-   Random size
-   Random shape
-   Random color
-   Full physics simulation
-   Pushable
-   Affected by gravity

------------------------------------------------------------------------

## Arena System

-   Large ground plane
-   Tall perimeter walls
-   Walls apply full collision impulses
-   Prevent falling off map
-   Contribute to wheel damage

------------------------------------------------------------------------

## Damage HUD

On-screen UI displays:

-   RF (Right Front)
-   LF (Left Front)
-   RB (Right Back)
-   LB (Left Back)

Each wheel shows:

-   Damage percentage

Updated in this version:

-  Moved the HUD to it's own scene so it's usable across scenes

------------------------------------------------------------------------

## Camera System

-   Right mouse button rotates camera
-   Vertical pitch clamped
-   Smooth return when released
-   Adjustable sensitivity and return speed

Updated in this version:

-  Moved the camera out of the World scene so it's usable in other scenes

------------------------------------------------------------------------

# Controls

| Action              | Key / Input                |
|---------------------|---------------------------|
| Accelerate          | `W`                       |
| Reverse             | `S`                       |
| Steer Left          | `A`                       |
| Steer Right         | `D`                       |
| Boost               | `Space`                   |
| Rotate Camera       | `Hold Right Mouse Button` |
| Menu                | `Esc` |

------------------------------------------------------------------------

# Tuning

Most gameplay variables are exposed via `@export` in `soapbox.gd` and
`enemy_ai.gd`.

You can tune:

-   Wheel damage thresholds
-   Suspension degradation
-   Engine scaling
-   Bumper durability
-   Boost force and cooldown
-   AI aggression
-   AI boost behavior
-   Steering smoothness

The project is designed for rapid experimentation.

------------------------------------------------------------------------

# Current Features

-   [x] Progressive wheel damage
-   [x] Detachable wheels
-   [x] Detachable bumpers
-   [x] AI rammer
-   [x] Boost system
-   [x] Arena walls
-   [x] Physics obstacles
-   [x] Damage UI
-   [x] AI toggle before runtime
-   [x] Start Up Screen
-   [x] In game Menu
-   [x] Downhill Demo with Win message

------------------------------------------------------------------------

# Project Structure

    soapbox.tscn         -> Vehicle scene
    soapbox.gd           -> Core vehicle logic + damage system
    enemy_ai.gd          -> Aggressive AI driver
    world.tscn           -> Main arena scene
    world.gd             -> AI toggle logic
    obstacle_spawner.gd  -> Random obstacle generation
    damage_hud.gd        -> Per-wheel damage UI

------------------------------------------------------------------------

# Requirements

-   Godot 4.5

------------------------------------------------------------------------
