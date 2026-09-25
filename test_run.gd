extends SceneTree

func _init():
	print('--- INITIALIZING NETWORKMANAGER & TEST ---')
	var net_script = load('res://scripts/autoload/NetworkManager.gd')
	var net_inst = net_script.new()
	net_inst.name = 'NetworkManager'
	root.add_child(net_inst)
	
	# Instantiate player
	var p_scene = load('res://scenes/player/player.tscn')
	var player = p_scene.instantiate()
	player.name = '1'
	root.add_child(player)
	
	print('1. Initial Player Health: ', player.current_health, ' / ', player.max_health)
	assert(player.current_health == 100.0)
	assert(player.is_dead == false)
	
	# Test Damage and Effect
	print('2. Player taking 35 damage...')
	player.take_damage(35.0)
	print('Health after damage: ', player.current_health)
	assert(player.current_health == 65.0)
	assert(player.camera_trauma > 0)
	assert(player.is_dead == false)
	
	# Test Lethal Damage and Death
	print('3. Player taking lethal 70 damage...')
	player.take_damage(70.0)
	print('Health after lethal damage: ', player.current_health)
	assert(player.current_health == 0.0)
	assert(player.is_dead == true)
	assert(player.gun.visible == false)
	assert(player.collision_layer == 0)
	assert(player.death_screen.visible == true)
	print('Death verified: is_dead=true, gun hidden, death_screen shown!')
	
	# Test Zombie Ignore Dead Player
	var z_scene = load('res://scenes/enemies/zombie.tscn')
	var zombie = z_scene.instantiate()
	root.add_child(zombie)
	zombie._find_closest_player()
	assert(zombie.target_player == null)
	print('Zombie successfully ignores dead player!')
	
	# Test Zombie Damage and Death
	print('4. Zombie taking damage and dying...')
	zombie.take_damage(50.0)
	assert(zombie.current_health < 100.0)
	zombie.take_damage(100.0)
	assert(zombie.is_dead == true)
	print('Zombie death verified!')
	
	# Test Player Revive
	print('5. Player revive...')
	player.revive(50.0, Vector3(0, 1.5, 0))
	assert(player.is_dead == false)
	assert(player.current_health == 50.0)
	assert(player.gun.visible == true)
	assert(player.death_screen.visible == false)
	print('Player revive verified!')
	
	print('=== ALL 5 MECHANIC TESTS PASSED PERFECTLY! ===')
	quit(0)

