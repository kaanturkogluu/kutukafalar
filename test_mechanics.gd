extends SceneTree

func _init():
	print('--- KUTU KAFALAR COMBAT & DEATH TEST ---')
	
	# Load main level scene
	var level_scene = load('res://scenes/levels/main_level.tscn')
	assert(level_scene != null, 'MainLevel scene must exist')
	var level = level_scene.instantiate()
	root.add_child(level)
	
	await process_frame
	await process_frame
	
	# Check spawned player
	var players = level.get_tree().get_nodes_in_group('players')
	print('Spawned players count: ', players.size())
	assert(players.size() >= 1, 'Player should be spawned')
	var player = players[0]
	
	print('Initial player health: ', player.current_health, ' / ', player.max_health)
	assert(player.current_health == 100.0, 'Initial health should be 100')
	assert(player.is_dead == false, 'Player should start alive')
	
	# TEST 1: Damage taking and visual effect
	print('[TEST 1] Applying 30 damage to player...')
	player.take_damage(30.0)
	print('Player health after damage: ', player.current_health)
	assert(player.current_health == 70.0, 'Health should be 70')
	assert(player.camera_trauma > 0, 'Camera trauma should increase')
	assert(player.is_dead == false, 'Player should still be alive at 70 HP')
	
	# TEST 2: Low health critical pulse
	print('[TEST 2] Applying 50 more damage to reach critical health...')
	player.take_damage(50.0)
	print('Player health: ', player.current_health)
	assert(player.current_health == 20.0, 'Health should be 20')
	
	# TEST 3: Lethal damage and death transition
	print('[TEST 3] Applying lethal damage...')
	player.take_damage(30.0)
	print('Player health after lethal damage: ', player.current_health)
	assert(player.current_health == 0.0, 'Health should be 0')
	assert(player.is_dead == true, 'Player is_dead should be TRUE')
	assert(player.gun.visible == false, 'Player gun should be hidden when dead')
	assert(player.collision_layer == 0, 'Collision layer should be 0 when dead')
	assert(player.death_screen.visible == true, 'Death screen should be visible')
	print('Player death state verified successfully!')
	
	# TEST 4: Dead player cannot shoot or move
	var ammo_before = player.weapon_ammo
	player._shoot()
	assert(player.weapon_ammo == ammo_before, 'Dead player cannot shoot')
	
	# TEST 5: Zombie ignores dead player
	var zombie_scene = load('res://scenes/enemies/zombie.tscn')
	var zombie = zombie_scene.instantiate()
	level.add_child(zombie)
	zombie._find_closest_player()
	print('Zombie target when player is dead: ', zombie.target_player)
	assert(zombie.target_player == null, 'Zombie must ignore dead players')
	
	# TEST 6: Zombie taking damage and dying
	print('[TEST 6] Testing zombie damage and death...')
	assert(zombie.is_dead == false, 'Zombie should start alive')
	zombie.take_damage(50.0)
	print('Zombie health: ', zombie.current_health)
	assert(zombie.current_health < 100.0, 'Zombie took damage')
	zombie.take_damage(100.0)
	assert(zombie.is_dead == true, 'Zombie is_dead should be true')
	print('Zombie death verified successfully!')
	
	# TEST 7: Reviving player
	print('[TEST 7] Reviving player...')
	player.revive(50.0, Vector3(0, 1.5, 0))
	assert(player.is_dead == false, 'Player should be alive after revive')
	assert(player.current_health == 50.0, 'Player health should be 50')
	assert(player.gun.visible == true, 'Gun should be visible after revive')
	assert(player.death_screen.visible == false, 'Death screen should be hidden after revive')
	print('Player revive verified successfully!')
	
	print('=== ALL TESTS PASSED SUCCESSFULLY! ===')
	level.queue_free()
	quit()

