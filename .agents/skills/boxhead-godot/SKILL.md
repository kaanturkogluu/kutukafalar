---
name: boxhead-godot
description: Godot 4.x multiplayer FPS horde shooter (Kutu Kafalar) development standards, networking architecture, scene organization, and token-efficient coding guidelines.
---

# Boxhead Godot 4 Multiplayer FPS Skill & Development Guidelines

This skill guides development for the Kutu Kafalar (Boxhead FPS Co-op) project in Godot 4.x. Follow these rules to keep the codebase clean, performant, and token-efficient.

## 1. Token-Efficiency & Development Principles
- **Concise & Modular:** Write focused GDScript classes (single responsibility). Avoid monolithic 1000-line scripts.
- **Diff-Friendly Edits:** Only edit relevant methods/blocks. Do not rewrite entire scene scripts when modifying a single function.
- **Deterministic Patterns:** Standardize signal and RPC names across all multiplayer nodes.

## 2. Directory Structure Conventions
```
res://
├── assets/
│   ├── audio/          # Sound effects, ambient, music
│   ├── fonts/          # Retro/pixel fonts
│   ├── materials/      # Godot StandardMaterial3D / Shaders
│   └── models/         # Voxel / low-poly meshes
├── scenes/
│   ├── ui/             # HUD, lobby, health bar, combo meter
│   ├── player/         # Player character, arms, first-person camera
│   ├── enemies/        # White zombie, red devil, tank
│   ├── interactables/  # Barrels (red, blue, green, yellow), barricades
│   ├── levels/         # Modular floors, elevator, spawn rooms
│   └── weapons/        # Projectiles, bullet impacts, muzzle flashes
└── scripts/
    ├── autoload/       # GameManager, NetworkManager, SteamManager
    ├── combat/         # Health, DamageData, Hitbox, Hurtbox
    ├── player/         # FPSController, PlayerInput, SpellController
    ├── enemies/        # EnemyBase, ZombieAI, DevilAI
    └── world/          # FloorManager, Spawner, ElevatorController
```

## 3. Multiplayer & Networking Architecture (Godot 4 High-Level API)
- **Host-Authoritative AI & Combat:**
  - Zombies and barrels are spawned and simulated ONLY on the server (`multiplayer.is_server()`).
  - Clients send inputs (`PlayerInput`), Host executes movement and replicates via `MultiplayerSynchronizer`.
- **Spawn Replication & Despawn Safety:**
  - Always use `MultiplayerSpawner` for dynamically instantiated entities (Zombies, Barrels, Projectiles).
  - **CRITICAL:** Replicated nodes spawned by `MultiplayerSpawner` must ONLY be `queue_free()`'d by the server. On clients, hide visuals and disable collisions (`visible = false; collision_layer = 0`) to avoid despawn race conditions.
  - Non-replicated visual effects (gibs, sparks) must be added to `get_tree().current_scene`, NOT inside containers tracked by a `MultiplayerSpawner`.
- **RPC Guidelines & Authority Rules:**
  - `@rpc("any_peer", "call_local", "reliable")` when the server needs to call an RPC on a node whose authority belongs to a client (e.g. `_apply_player_damage`, `revive` on client `Player`). Without `any_peer`, Godot blocks server calls to client-owned nodes.
  - `@rpc("any_peer", "reliable")` for client-to-server requests (e.g. `_request_damage.rpc_id(1, ...)`).
  - `@rpc("call_local", "unreliable")` for visual effects called by the authority (muzzle flash, bullet hit effects, hit flash).

## 4. Combat, Damage Feedback & Voxel Physics Guidelines
- **Hit Detection:**
  - Hitscan weapons (pistol, shotgun) use `RayCast3D` from camera center.
  - Projectiles (rockets, fireballs) use `Area3D` with collision detection.
- **Damage Feedback Standards (Visual & Camera Punch):**
  - **Screen Damage Vignette:** Use radial `GradientTexture2D` in `HUD/DamageOverlay` with tween fadeout.
  - **Low Health Pulse:** When `current_health < 30.0`, pulse vignette alpha using a sine wave.
  - **Camera Trauma & Punch:** Apply camera trauma (`trauma = clamp(trauma + amount/30.0, 0.35, 1.0)`) and subtle angular flinch (`head.rotation_degrees.x`, `camera.rotation_degrees.z`). Decay quadratically in `_physics_process`.
  - **3D Mesh Hit Flash:** `MeshInstance3D` has **NO `modulate` property**. Always use `material_override = hurt_material` and restore to `null` after 0.1-0.12s.
- **Voxel Gibs / Destruction:**
  - Use `GPUParticles3D` for small blood/cube splatter (lightweight).
  - Use `RigidBody3D` cube pieces (`cube_gibs.tscn`) on death and explosions, with an auto-queue_free timer (2-3 seconds).

## 5. Character Death & Revive Architecture
- **State Guarding:** Guard all movement, input, shooting, kicking, barrel placement, spell casting, and pickups with `if is_dead: return`.
- **Death Handling:**
  - Set `is_dead = true`, reset combo, hide weapon (`gun.visible = false`).
  - Disable collisions (`collision_layer = 0`) so entities do not get stuck.
  - Tilt 3D mesh flat on floor (`rotation_degrees.z = 85`), update `NameLabel` to `[ÖLDÜ] Name` in red.
  - First-person camera: tumble to floor (`position:y = -0.5`, `rotation_degrees:z = 40`).
  - Show `DeathScreen` UI, unlock mouse cursor (`Input.mouse_mode = Input.MOUSE_MODE_VISIBLE`), enable `[R]` retry shortcut.
- **Enemy AI Integration:**
  - `_find_closest_player()` and `_attack_player()` must filter out dead players (`not p.get("is_dead")`).
- **Revival & Restart:**
  - Elevator clears dead players via `p.revive.rpc(half_health, elevator_pos)`.
  - Server restart resets floor, clears zombies, and revives squad at spawn points.

## 6. Input Action Mapping Standard
- `move_forward`, `move_backward`, `move_left`, `move_right`
- `jump`, `sprint`
- `shoot`, `aim_down_sights`
- `kick` (F key)
- `spell_tactical` (E key)
- `spell_ultimate` (Q key)
- `interact` (G key for explosive barrels)
- Weapon Switch: Mouse Scroll Wheel (`MOUSE_BUTTON_WHEEL_UP`, `MOUSE_BUTTON_WHEEL_DOWN`) and Number keys (`1`, `2`, `3`, `4`)

## 7. Weapon Arsenal, Inventory & Audio Architecture
- **Sound System (`SoundManager` Autoload):**
  - Generates procedural 16-bit PCM retro arcade `AudioStreamWAV` buffers in GDScript math without external audio assets.
  - Supports 2D stereo SFX (`SoundManager.play_sfx("pistol")`) and 3D spatial SFX (`SoundManager.play_3d_sfx("shotgun", pos)`).
  - Built-in sound profiles: `pistol`, `shotgun`, `uzi`, `rocket`, `switch`, `empty`, `pickup`.
- **Multi-Weapon Inventory (`FPSController`):**
  - Players start with infinite default `pistol` in `weapon_inventory = ["pistol"]` and `weapon_ammo_dict["pistol"] = -1`.
  - Dropped weapon pickups (`shotgun`, `uzi`, `rocket`) automatically add the weapon to inventory if not owned, stack ammo if already owned, and auto-equip newly discovered weapons.
  - Quick cycle between all collected weapons via Mouse Wheel Up/Down or direct slot keys 1-4.
  - **Ammo Depletion Discard:** When non-pistol weapons deplete their ammo to 0, they are automatically removed from `weapon_inventory`, playing the `empty` SFX and reverting the player to the next available weapon or the infinite pistol.
- **UI & Shop Input Isolation:** Whenever UI is active (Shop, menus, death screen) or `Input.mouse_mode != Input.MOUSE_MODE_CAPTURED`, all weapon shooting, kicking, barrel placement, spell casting, weapon cycling, and camera rotations are strictly locked. Clicks within UI panels are consumed and never trigger `_shoot()`.
