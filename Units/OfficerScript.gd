extends RigidBody2D
const SQUARE_SIZE = 32
const PIXEL_SIZE = 4

@export var health: float = 75
@export var speed: float = 0.8
@export var attack: float = 2
@export var cooldown: float = 0.0
@export var under_command = []
var max_command = 1
var animation_player
var navigation

# Movement plan
@export var target: Vector2 = Vector2(1, 1)
var availible_positions = {}

const SQUARE_FORMATION = [
	Vector2.RIGHT
]

# Called when the node enters the scene tree for the first time.
func _ready():
	animation_player = $AnimationPlayer
	navigation = $NavigationAgent2D
	navigation.set_navigation_map(get_tree().get_first_node_in_group("NavMesh"))
	new_target()
	
	# Gets units under command
	var tree = get_tree() # Get all units
	var units = tree.get_nodes_in_group("team" if get_groups().has("team") else "enemy")
	for unit in units:
		if (len(under_command) >= max_command):
			break
		elif (unit.get_groups().has("infantry") && !unit.commander):
			under_command.append(unit)
			unit.commander = get_node(".")
			unit.new_target()
			availible_positions[unit.name] = unit.get_position()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta):
	var local_target = navigation.get_next_path_position()
	
	# If at position get new target
	if ((local_target - get_position()).length_squared() < 4):
		new_target()
	else:
		var dir = (local_target - get_position()).normalized() # Set vector of target
		#var collison = move_and_collide(dir * speed) # Move and get collision
		var collison = null
		
		if (collison && collison.get_collider() is Node):
			var collider: Node = collison.get_collider() # Get collider
			if (collider.get_groups().has("enemy" if get_groups().has("team") else "team") && cooldown < 0.2): # If has enemy group and not cooling down
				animation_player.set_current_animation("attack")
				collider.take_damage(attack * randf_range(0.9, 1.1)) # Attack the enemy (Removes deterministic simulation by using random)
				cooldown += 10.0
			elif (cooldown < 0.2):
				new_target(collison.get_position()) # Otherwise get new position
	
	if (cooldown < 0.2):
			animation_player.set_current_animation("walk") # Set walking animation when not attacking
	else:
		cooldown -= 1.0 # If attacking reduce cooldown

func order_position(unit: Node):
	var order = availible_positions[unit.name]
	return order

func new_target(collision_position = null):
	""" Go towards the nearest enemy otherwise roam """
	var adjustment = Vector2.ZERO
	#if (collision_position):
		#adjustment = (get_position() - collision_position)
	
	var tree = get_tree() # Get all units
	var enemy_units = tree.get_nodes_in_group("enemy" if get_groups().has("team") else "team") # Filter by group
	var nearest_enemy_unit
	for enemy in enemy_units:
		if (!nearest_enemy_unit or (nearest_enemy_unit.position - position).length_squared() > (enemy.position - position).length_squared()): # Get the nearing enemy
			nearest_enemy_unit = enemy if randi_range(0, 10) != 10 else nearest_enemy_unit # Removes deterministic simulation by using random
	# Set the position to the nearest enemy otherwise a random spot on the map
	if (nearest_enemy_unit):
		target = nearest_enemy_unit.position + adjustment
	else:
		target = Vector2(randi_range(-16 * SQUARE_SIZE, 16 * SQUARE_SIZE), randi_range(-9 * SQUARE_SIZE, 9 * SQUARE_SIZE)) + adjustment
	
	availible_positions = {}
	for unit in under_command:
		if (is_instance_valid(unit)): # Check if unit is still there
			var dir = Vector2.from_angle(get_position().angle_to_point(target))
			availible_positions[unit.name] = (get_position() + SQUARE_FORMATION[SQUARE_FORMATION.find(unit)]) * dir
			unit.new_target()
		else:
			under_command.remove_at(under_command.find(unit)) # Otherwise remove unit
			availible_positions.erase(unit.name)
			#TODO: Find new units
	
	var current = get_position()
	target = Vector2(lerp(current.x, target.x, 0.6), lerp(current.y, target.y, 0.6)) + adjustment
	navigation.set_target_position(target)

func take_damage(amount):
	""" Take damage and remove self if health is 0 """
	health -= amount
	if (health <= 0):
		for unit in under_command: # Remove all command and buffs
			if (is_instance_valid(unit)):
				unit.new_target()
		queue_free()
