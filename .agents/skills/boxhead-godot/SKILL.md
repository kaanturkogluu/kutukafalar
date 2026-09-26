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
  - Use `GPUParticles3D` for small blood/cube splatter (lightweight, GPU-instanced).
  - Use multi-cube rigidbodies only for critical boss deaths or limited debris count.

## 5. Character Death & In-Combat Revive Architecture
- **State Guarding:** Guard all movement, input, shooting, kicking, barrel placement, spell casting, and pickups with `if is_dead: return`.
- **Authoritative Death RPC:**
  - When player health reaches `<= 0`, the server calls `@rpc("call_local", "reliable") func die()`.
  - Sets `is_dead = true`, `current_health = 0.0`, `velocity = Vector3.ZERO`, resets revive timers, hides weapon (`gun.visible = false`).
  - Preserves body collision (`collision_layer = 2`, `collision_mask = 1`) so teammates can target and revive the corpse.
  - Tilts 3D mesh flat on floor (`rotation_degrees.z = 85`), updates `NameLabel` to `💀 [Oyuncu] \n[E] Canlandır (10 sn)` in red.
  - Spawns cube destruction gibs (`cube_gibs.tscn`) and unlocks mouse cursor.
  - If living teammates exist, immediately calls `_start_spectating()`. If all teammates are dead, sets `all_players_dead = true` and shows Game Over.
- **10-Second In-Combat Revive System (`_handle_revive_interaction`):**
  - Living players aiming within 3.2m of a downed teammate see `❤️ [E'YE BASILI TUT] Canlandır (10 sn)`.
  - Holding `[E]` charges `revive_progress_timer` for 10.0 seconds with a real-time progress bar.
  - Notifies downed player via `nearest_downed.notify_being_revived.rpc(player_name, pct)`.
  - When timer reaches 10s: calls `target_player.revive.rpc(50.0, t_pos)` and plays pickup SFX.
  - Weapon shooting, kicking, and tactical spells are locked during revive channeling.
- **Elevator Level-End Revive & Full Squad Reset:**
  - Elevator transition calls `p.revive.rpc(p.max_health * 0.5, elevator_pos)` for all dead players.
  - Full game restart calls `@rpc("call_local", "reliable") func reset_to_default_loadout(spawn_pos)` to restore default weapon inventory, full health, camera, and mouse capture cleanly.

## 6. Input Action Mapping Standard
- `move_forward`, `move_backward`, `move_left`, `move_right`
- `jump`, `sprint`
- `shoot`, `aim_down_sights`
- `kick` (F key)
- `spell_tactical` (E key)
- `spell_ultimate` (Q key)
- `interact` (G key for explosive barrels)
- Weapon Switch: Mouse Scroll Wheel (`MOUSE_BUTTON_WHEEL_UP`, `MOUSE_BUTTON_WHEEL_DOWN`) and Number keys (`1`, `2`, `3`, `4`)
- Spectator UI Toggle: `H` key / `👁 Arayüzü Gizle / Göster` button
- Spectator Cycle: Left Click / Space (Next), Right Click (Previous)

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

## 8. Two-Stage Lobby, Waiting Room, Ready System & Late Join Protection
- **Two-Stage Architecture (`Lobby.gd` & `NetworkManager.gd`):**
  - Stage 1 (`ConnectPanel`): Player picks class, name, IP, and clicks Host or Join.
  - Stage 2 (`RoomPanel` Waiting Room): Displays all connected players with classes and status badges (`👑 [ODA SAHİBİ]`, `✅ HAZIR`, `⏳ BEKLİYOR`).
  - Clients toggle ready state via `set_local_ready(bool)`.
  - Host triggers simultaneous scene change via `start_game()` -> `_start_game_rpc.rpc()` so all peers load `main_level.tscn` at the exact same tick.
- **Mid-Game Join Locking:**
  - Server tracks `is_game_in_progress: bool`.
  - Any connection after match start is rejected via `_reject_connection.rpc_id()` with user notification and clean disconnection, preventing scene desynchronization.

## 9. Multiplayer Spectator Mode & Hideable Death HUD
- **Restart Lockout:**
  - Dead players cannot trigger restart while teammates are alive (`if not all_players_dead and not _get_living_teammates().is_empty(): return`).
  - `RestartBtn` is hidden and shortcut `[R]` / `Space` is disabled until `all_players_dead` is true.
  - Only the host (`multiplayer.is_server()`) can restart the game once everyone is dead.
- **Spectator Camera:**
  - Dead player camera detaches (`top_level = true`, `camera.current = true`) and smoothly tracks behind living teammates in 3rd person:
    `target_cam_pos = spectator_target.global_position + Vector3(0, 2.2, 0) - spectator_target.transform.basis.z * 3.2`
  - `[Left Click]` or `[Space]` cycles forward; `[Right Click]` cycles backward.
- **Hideable Death/Spectator Overlay ([H] Toggle):**
  - Pressing `[H]` or clicking `👁 Arayüzü Gizle [H]` toggles `is_death_ui_hidden`.
  - When hidden: `CenterContainer` and `Backdrop` are hidden; a minimal floating button `👁 Arayüzü Göster [H]` stays in the top-right corner.
  - `Backdrop` and `DeathScreen` use `mouse_filter = Control.MOUSE_FILTER_IGNORE` so viewport mouse clicks are not blocked from cycling players.

## 10. GDScript Safety, Elevator Sync & AutoUpdater Rules
- **GDScript Object.get() Constraint:**
  - In Godot 4 GDScript, `Object.get(property)` takes **AT MOST 1 argument**. Passing a second default argument (e.g. `p.get("prop", default)`) causes a fatal parse error on scene reload. Always check `if p.get("prop") != null and float(p.get("prop")) > 0`.
- **Level Start Server Notify:**
  - At level `_ready()`, server must call `_notify_peer_level_ready(1)` directly rather than using loopback `rpc_id(1)`. This avoids dropped RPC frames and ensures the host immediately spawns and initial barrels/waves begin.
- **Elevator Synchronization:**
  - `set_elevator_state` must be `@rpc("call_local", "reliable")` so door openings and signs synchronize across all client screens even if the host dies.
  - `_check_all_players_inside()` must filter only LIVING players (`p.current_health > 0 and not p.get("is_dead")`).
- **AutoUpdater & Windows File Locks:**
  - Always download update PCK files to `user://` (`OS.get_user_data_dir()`) to avoid program directory permission errors.
  - `apply_update.bat` must implement a retry loop (`:wait_loop` up to 20 seconds) before replacing `KutuKafalar.pck` to prevent Windows file-sharing lock violations (`Error 32`).art.
  - When teammates reach the elevator, dead players are revived via `revive.rpc()`, resetting camera transforms and collisions cleanly.

## 11. Level Progression & Thematic Environment Architecture
- **11 Chapters & 99 Levels Data Model (`LevelData`):**
  - Mapped directly from `leveller`: Chapters 1-11 each hold 9 levels (e.g. Chapter 1: Level 1–9 "Terk Edilmiş Mahalle", Chapter 2: Level 10–18 "Şehir Merkezi").
  - Final level of each chapter (e.g. Level 9 Wave 3) triggers the Chapter Boss (`BossZombie` / "Mahalle Şefi" 1200 HP).
- **Cul-de-sac Abandoned Neighborhood Design:**
  - 52x52m circular asphalt roadway with central park island roundabout, houses, storefronts, boarded windows, streetlights (`OmniLight3D`), dumpsters, and twilight procedural sky.
- **Destructible Car Wrecks (`CarWreck.gd` & `car_wreck.tscn`):**
  - Group `barrels` & `destructibles` so hitscan, rockets, and barrel explosions all damage it.
  - 150 HP health pool with red warning light countdown before 7.5m radius 350-damage explosion, leaving behind a permanent burnt metal cover.
