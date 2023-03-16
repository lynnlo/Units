extends RigidBody2D
const SQUARE_SIZE = 32
const PIXEL_SIZE = 4

@export var health: float = 50
@export var speed: float = 1.5
@export var attack: float = 5
@export var cooldown: float = 0.0
@export var commander: Node
var animation_player
var navigation

# Movement plan
@export var target: Vector2 = Vector2(1, 1)

# Called when the node enters the scene tree for the first time.
func _ready():
	animation_player = $AnimationPlayer
	navigation = $NavigationAgent2D
	navigation.set_navigation_map(get_tree().get_first_node_in_group("NavMesh"))
	new_target()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta):
	var local_target = navigation.get_next_path_position()
	
	# If at position get new target
	if ((local_target - get_position()).length_squared() < 4):
		new_target()
	else:
		var dir = (local_target - get_position()).normalized() # Set vector of target
		navigation.set_velocity(dir * speed)
		var collison = move_and_collide(dir * speed) # Move and get collision)
		
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
	
func new_target(collision_position = null):
	""" 
		Go towards the nearest enemy otherwise roam
		If a commander is present go into formation
	"""
	var adjustment = Vector2.ZERO
	#if (collision_position):
		#adjustment = (get_position() - collision_position)
	
	if (!commander):
		var tree = get_tree() # Get all units
		var enemy_units = tree.get_nodes_in_group("enemy" if get_groups().has("team") else "team") # Filter by group
		var nearest_enemy_unit
		for enemy in enemy_units:
			if (!nearest_enemy_unit or (nearest_enemy_unit.position - position).length_squared() > (enemy.position - position).length_squared()): # Get the nearing enemy
				nearest_enemy_unit = enemy if randi_range(0, 10) != 10 else nearest_enemy_unit # Removes deterministic simulation by using random
		# Set the position to the nearest enemy otherwise a random spot on the map
		if (nearest_enemy_unit):
			target = nearest_enemy_unit.position
		else:
			target = Vector2(randi_range(-16 * SQUARE_SIZE, 16 * SQUARE_SIZE), randi_range(-9 * SQUARE_SIZE, 9 * SQUARE_SIZE))
	else:
		target = commander.get_position()
	
	var current = get_position()
	target = Vector2(lerp(current.x, target.x, 0.3), lerp(current.y, target.y, 0.3)) + adjustment
	navigation.set_target_position(target)

func take_damage(amount):
	""" Take damage and remove self if health is 0 """
	health -= amount
	if (health <= 0):
		queue_free()
