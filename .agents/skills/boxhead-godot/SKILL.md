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
- **Elevator Synchronization & Host-Authoritative Level Transition:**
  - `set_elevator_state` must be `@rpc("call_local", "reliable")` so door openings and signs synchronize across all client screens even if the host dies.
  - `_check_all_players_inside()` must filter only LIVING players (`p.current_health > 0 and not p.get("is_dead")`) and debounce transition with `has_triggered_transition`.
  - Only the host (lobby owner / peer 1) can trigger next level start (`_request_start_level`). Client requests must be ignored and Shop `next_floor_btn` must be disabled for non-hosts.
  - When starting a new level, NEVER assign `players[i].position` directly on the server; always call `@rpc func teleport_to(spawn_pos)` on each player so client authorities receive and apply the position change.
  - Do not immediately lock elevator doors upon level start; keep doors open for 2-3 seconds to prevent trapping players behind closed doors.
- **AutoUpdater & Windows File Locks:**
  - Always download update PCK files to `user://update_download.pck` (`OS.get_user_data_dir()`) to avoid permission errors.
  - Single source of truth for version is `res://version.json`, packed into PCK via `include_filter="*.json"`.
  - Windows update applier script (`apply_update.cmd`) uses `tasklist /fi "PID eq %PID%"` to wait for the Godot process to exit completely, followed by `ping 127.0.0.1 -n 2 >nul` retry loop for atomic file swapping without stdin crashes.
  - Surcharged GitHub CDN queries must append `?t=<timestamp>` to prevent caching stale version.json.

## 11. Level Progression, 99 Floors & Thematic Sector Architecture
- **11 Sectors & 99 Floors Data Model (`LevelData.gd`):**
  - Mapped directly from the mega tower climbing scheme: Sectors 1-11 each hold 9 floors (Floors 1–99).
  - Every 9th floor (Levels 9, 18, 27, 36, 45, 54, 63, 72, 81, 90, 99) triggers the Sector Boss.
- **Dynamic Modular Floor Loading (`FloorContainer` in `MainLevel.gd`):**
  - Floors are loaded dynamically into `FloorContainer` via `sync_load_floor_environment.rpc(floor_num)` to avoid scene reloading and keep multiplayer peers connected.
  - Hierarchy check: `res://scenes/levels/floors/floor_%02d.tscn` (Floor-specific if present, e.g. Floors 1-9) -> `res://scenes/levels/floors/sector_%02d.tscn` (Sector-level fallback for remaining floors) -> `floor_01.tscn`.
  - Old floor entities are cleared prior to loading via `sync_clear_all_entities.rpc()`.
- **Dynamic Atmosphere & Lighting Switching (`_apply_sector_atmosphere`):**
  - Prevents player visual fatigue and darkness claustrophobia by dramatically altering `WorldEnvironment` and `DirectionalLight3D` per sector:
    - *Sector 1 (1–9):* Twilight street & atrium.
    - *Sector 2 (10–18):* Industrial amber gloom & steam.
    - *Sector 3 (19–27):* Vibrant neon shopping plaza.
    - *Sector 4 (28–36):* **Crisp sunny daytime & bright azure sky** (zero fog, high noon sunlight).
    - *Sector 5 (37–45):* Electric cyan & violet cyber server racks.
    - *Sector 6 (46–54):* **Sterile bright white hospital fluorescent lighting**.
    - *Sector 7 (55–63):* Royal gold, red velvet & glowing neon casino.
    - *Sector 8 (64–72):* **Lush green tropical greenhouse oasis & pond bridge** with bright natural sunlight.
    - *Sector 9 (73–81):* High-tech bioluminescent teal lab.
    - *Sector 10 (82–90):* Fortified military defense compound & searchlights.
    - *Sector 11 (91–99):* **Open-air rooftop helipad & storm sunset summit** with evacuation rescue chopper.

## 12. Enemy Variants, Sector Bosses & Persistent Save System
- **Enemy Variants (`ZombieAI.gd` - `setup_type(type)`):**
  - `normal`: Balanced speed (4.4) and HP (100).
  - `runner`: High speed (6.5+), lower HP (72%), agile frame, fiery glowing eyes.
  - `tank`: Heavy armor, 2.6x HP, 1.35x scale, high damage (32), gunmetal tint.
  - `toxic`: Neon green bio-hazard glow. Triggers poisonous area burst on death.
  - `boomer`: Carrying pulsating explosive pack. Detonates when within 2.2m of players or on death for 45 area damage.
- **Sector Boss Customization (`setup_boss_sector(sector)`):**
  - Scales dynamically from 1.4x (Sector 1: Mahalle Şefi) up to 2.2x colossal size for Sector 11 (Kat 99: Kutu Şah / The Apocalypse King with 8000 HP).
  - Distinct materials, eye emissions, speeds, and attack damages per sector.
- **Persistent Save System (`SaveManager.gd` Autoload):**
  - Saves to `user://save_data.json` with versioning and validation.
  - Tracks: `highest_unlocked_floor` (1 to 99), `total_kills`, `total_boss_kills`, `total_gold_earned`, `total_floors_cleared`, `total_runs`.
  - When a floor is cleared in `_on_floor_cleared()`: automatically calls `SaveManager.record_floor_cleared()` and `SaveManager.unlock_floor(current_floor + 1)`.
  - `LevelSelect.gd` queries `SaveManager.get_highest_unlocked_floor()` and enables sector switching across all 11 sectors.

## 13. Skill Tree, Meta-Progression & Class Socket Architecture
- **Dual-Economy Separation (Roguelite Core Rule):**
  - *In-Run Gold (Askeri Kredi):* Earned and spent strictly within the run/floor at the elevator shop (`Shop.gd`). Resets on death/run restart. Never conflicts with permanent meta-progression.
  - *Meta-Currency (Biyo-Çekirdek / Bio-Cores):* Earned from clearing new floors (+1), Sector Milestones (+3 on every 9th floor), and Sector Boss eliminations (+5). Persisted via `SaveManager.gd`. Spent in the Skill Tree (Main Menu / In-Game [K] / Elevator Station).
- **Decoupled Architecture (`ProgressionManager.gd` Autoload):**
  - Do NOT bloat `FPSController.gd` with skill tree evaluation code.
  - `ProgressionManager` acts as the single source of truth: stores node catalog, prerequisites, unlocked state, and calculates final aggregated `PlayerStats`.
  - When a player spawns or updates skills: `ProgressionManager.apply_to_player(player)` applies multipliers (`crit_chance`, `headshot_mult`, `dash_unlocked`, `chain_reaction`, etc.) live.
- **5-Branch Tactical Cyber Matrix UI (`SkillTree.gd` & `skill_tree.tscn`):**
  - **Top Operational Core:** `[ ❖ OPERASYONEL ÇEKİRDEK ❖ ]` serves as the root hub.
  - **5 Distinct Branch Columns:**
    - `SİLAH` (Weapon Master - Crimson/Red)
    - `HAYAT` (Survival/Bio-Armor - Emerald Green)
    - `HAREKET` (Mobility/Dash - Cyan/Amber)
    - `KAOS` (Demolition/Explosives - Molten Orange)
    - `TAKTİK` (Utility/Spells - Cyber Violet/Blue)
  - **Dynamic Circuit Lines (`LinesOverlay`):** Uses custom `_draw()` on `LinesOverlay` with orthogonal (90-degree) cyber bus lines connecting core -> column headers -> child nodes. Color coded by unlock and availability state.
  - **Node Chip States:**
    - `Unlocked`: Silver cyber icon with neon cyan/green accent outline.
    - `Available`: Glowing amber border and cost badge; ready to unlock.
    - `Locked`: Dimmed with 🔒 padlock; prerequisites not met.
    - `Selected`: High-contrast neon cyan selection box; details loaded into inspection card.
  - **Multi-Access & Input Guard:**
    - Accessible via Main Menu, In-Game `[K]` shortcut, Pause (ESC) menu button, and Elevator Station button.
    - Safely unlocks mouse (`MOUSE_MODE_VISIBLE`), blocks shooting/kicking/spells while open, and recalculates active player stats instantly.
- **Forward-Compatible Class Agnosticism:**
  - The 5 core branches apply universally to ALL classes.
  - Ability augments use a **Tag System** (`[AOE]`, `[ELEMENTAL]`, `[SUPPORT]`, `[PHYSICAL]`) on spells rather than hardcoded class names.
  - Dedicated **Class Keystone Socket**: Classes dynamically plug in their unique apex traits into a standardized socket.
- **Node ID & Respec Resilience:**
  - Nodes are saved as string IDs in an array (`unlocked_nodes = ["prec_01", "mob_dash"]`). Missing or new nodes never corrupt save files.
  - Full **Respec (Yetenek Sıfırlama)** refunds 100% of spent meta-currency to let players experiment with new builds freely.

## 14. Window Management, Camera & Singleplayer Fallback Standards
- **Window Centering & Responsive Sizing (`SettingsManager.gd`):**
  - Always enforce `initial_position_type=2` (`CENTER_MAIN_WINDOW_SCREEN`) in `project.godot`.
  - `SettingsManager.center_window()` verifies current display resolution: if window dimensions exceed 85% of screen size, it automatically clamps down to standard safe 16:9 bounds (e.g. 1280x720) and centers on the primary display.
- **Player Camera Hierarchy Convention:**
  - The active player camera node path is `$Head/Camera3D` (NOT `$Camera3D`).
  - In `main_level.tscn`, ensure `DefaultCamera.current = false` so the newly spawned player's camera immediately takes precedence.
- **Singleplayer / Standalone F6 Fallback (`MainLevel.gd`):**
  - If started without an active multiplayer peer, `MainLevel.gd` initializes an `OfflineMultiplayerPeer` and notifies peer 1 ready immediately. This guarantees standalone testing (F6) works instantly without freezing or waiting for server handshakes.

## 15. Release & Deployment Strict Rule
- **CRITICAL RESTRICTION:** Never run `build_release.ps1` and never push to Git (`git push origin main`) without the user's explicit command ("güncellemeyi at" or "build al"). Always test locally first.
