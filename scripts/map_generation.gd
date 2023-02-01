extends Node

@export var mapSize = 128
var playerSpawn = Vector2()

@export
var player_scene: PackedScene

@onready
var tile_map: TileMap = $tile_map

@export
var light: PackedScene

@export
var pickup: PackedScene

@export
var basic_enemy: PackedScene

@export
var exit: PackedScene

@export
var music: AudioStream

const PATH_SIZE = 2

func _ready():

	MusicPlayer.stop()
	MusicPlayer.stream = music
	MusicPlayer.volume_db = 0
	MusicPlayer.play()


	UpdateProgress("Loading generation libraries...")
	randomize()

func UpdateProgress(message):
	print(message)
	$LoadingScreen.get_child(2).text = message

func setTile(x,y, value):
	var tileValue = -1
	if(value == "block"):
		tileValue = 0
	elif(value == "safe_block"):
		tileValue = 2
	elif(value == "player"):
		playerSpawn = Vector2(x,y)
	elif(value == "ladder"):
		tileValue = 1
	elif(value == "light"):
		create_object(x,y, light)
	elif(value == "coin"):
		create_object(x,y, pickup)
	elif(value == "enemy"):
		create_object(x,y, basic_enemy)
	elif(value == "exit"):
		create_object(x,y, exit)
	tile_map.set_cell(tileValue, Vector2i(x, y))

func create_object(x: int, y: int, object_scene: PackedScene) -> void:
	var obj = object_scene.instantiate()
	self.add_child(obj)
	var pos = tile_map.map_to_local(Vector2i(x,y))
	obj.position = Vector2(pos.x + 8, pos.y + 8)

func generateStructure(x,y, structure):
	var symbolDictionary = {
		"x" : "safe_block",
		"p" : "player",
		"l" : "ladder",
		"c" : "coin",
		"e" : "enemy",
		"#" : "exit",
		"?": "light"
		}
	var largestX = 0
	var largestY = structure.size()
	for structY in range(0, structure.size()):
		for structX in range(0, structure[structY].size()):
			if structX > largestX:
				largestX = structX
			var symbol = structure[structY][structX]
			setTile(x + structX, y + structY, symbolDictionary.get(symbol))
	var rect = Rect2(Vector2(x-1,y-1),Vector2(largestX+1,largestY+1))
	return rect


func fillMap(value="block"):
	for x in range(0, mapSize):
		for y in range(0, mapSize):
			setTile(x,y,value)

func spawnPlayer():
	var tempVector = Vector2(playerSpawn.x * tile_map.cell_size.x, playerSpawn.y * tile_map.cell_size.y)
	var player = player_scene.instantiate()
	add_child(player)
	player.position = tempVector
	var welcome = load("res://Nodes/PlayerGreetings.tscn").instantiate()
	add_child(welcome)
	welcome.position = Vector2(tempVector.x - 16, tempVector.y - 16)
	tile_map.set_cell(-1, Vector2i(playerSpawn.x, playerSpawn.y))
	$LoadingScreen.hideSelf()

var rooms = Array()
func createConnections():
	var graph = AStar3D.new()
	var point_id = 0
	for x in range(mapSize):
		for y in range(mapSize):
			if tile_map.get_cell(x,y) == 0:
				graph.add_point(point_id, Vector3(x,y,0))

				if x > 0 && tile_map.get_cell(x - 1, y) == 0:
					var left_point = graph.get_closest_point(Vector3(x - 1, y, 0))
					graph.connect_points(point_id, left_point)

				if y > 0 && tile_map.get_cell(x, y - 1) == 0:
					var above_point = graph.get_closest_point(Vector3(x, y - 1, 0))
					graph.connect_points(point_id, above_point)

				point_id += 1

	var room_graph = AStar3D.new()
	point_id = 0
	for room in rooms:
		var room_center = room.position + room.size / 2
		room_graph.add_point(point_id, Vector3(room_center.x, room_center.y, 0))
		point_id += 1

	while !is_everything_connected(room_graph):
		add_random_connection(graph, room_graph)

func is_everything_connected(graph):
	var points = graph.get_points()
	var start = points.pop_back()
	for point in points:
		var path = graph.get_point_path(start, point)
		if !path:
			return false
	return true

func add_random_connection(stone_graph, room_graph):

	var start_room_id = get_least_connected_point(room_graph)
	var end_room_id = get_nearest_unconnected_point(room_graph, start_room_id)

	var start_position = pick_random_door_location(rooms[start_room_id])
	var end_position = pick_random_door_location(rooms[end_room_id])

	var closet_start_point = stone_graph.get_closest_point(start_position)
	var closet_end_point = stone_graph.get_closest_point(end_position)

	var path = stone_graph.get_point_path(closet_start_point, closet_end_point)

	for pos in path:
		for i in range(PATH_SIZE):
			if(tile_map.get_cell(pos.x+i, pos.y+i) == 0):
				setTile(pos.x+i, pos.y+i, "-1")
			if(tile_map.get_cell(pos.x+i, pos.y-i) == 0):
				setTile(pos.x+i, pos.y-i, "-1")
			if(tile_map.get_cell(pos.x-i, pos.y+i) == 0):
				setTile(pos.x-i, pos.y+i, "-1")
			if(tile_map.get_cell(pos.x-i, pos.y-i) == 0):
				setTile(pos.x-i, pos.y-i, "-1")
		if tile_map.get_cell(pos.x, pos.y - 2) == -1:
			if tile_map.get_cell(pos.x, pos.y - 1) == -1:
				if tile_map.get_cell(pos.x, pos.y) == -1:
					if !isNextToCell(pos.x, pos.y, 1):
						setTile(pos.x, pos.y, "ladder")
					#elif(randf_range(0,1) > 0.666):
					#	setTile(pos.x, pos.y, "light")

		elif tile_map.get_cell(pos.x, pos.y + 2) == -1:
			if tile_map.get_cell(pos.x, pos.y + 1) == -1:
				if tile_map.get_cell(pos.x, pos.y) == -1:
					if !isNextToCell(pos.x, pos.y, 1):
						setTile(pos.x, pos.y, "ladder")

	room_graph.connect_points(start_room_id, end_room_id)

func isNextToCell(x, y, tileId):
	return tile_map.get_cell(x-1, y) == tileId or tile_map.get_cell(x+1, y) == tileId or tile_map.get_cell(x, y-1) == tileId or tile_map.get_cell(x, y+1) == tileId

func get_least_connected_point(graph):
	var point_ids = graph.get_points()

	var least
	var tied_for_least

	for point in point_ids:
		var count = graph.get_point_connections(point).size()
		if !least or count < least:
			least = count
			tied_for_least = [point]
		elif count == least:
			tied_for_least.append(point)

	return tied_for_least[randi() % tied_for_least.size()]

func get_nearest_unconnected_point(graph, target_point):
	var target_position = graph.get_point_position(target_point)
	var point_ids = graph.get_points()

	var nearest
	var tied_for_nearest = []

	for point in point_ids:
		if point == target_point:
			continue

		var path = graph.get_point_path(point, target_point)
		if path:
			continue

		var dist = (graph.get_point_position(point) - target_position).length()
		if !nearest || dist < nearest:
			nearest = dist
			tied_for_nearest = [point]
		elif dist == nearest:
			tied_for_nearest.append(point)
	return tied_for_nearest[randi() % tied_for_nearest.size()]

func pick_random_door_location(room):
	var options = []

	for x in range(room.position.x + 1, room.end.x - 2):
		if tile_map.get_cell(x, room.position.y) == -1:
			options.append(Vector3(x, room.position.y, 0))
		if tile_map.get_cell(x, room.end.y) == -1:
			options.append(Vector3(x, room.end.y - 1, 0))

	for y in range(room.position.y + 1, room.end.y - 2):
		if tile_map.get_cell(room.position.x, y) == -1:
			options.append(Vector3(room.position.x, y, 0))
		if tile_map.get_cell(room.end.x - 1, y) == -1:
			options.append(Vector3(room.end.x - 1, y, 0))


	return options[randi() % options.size()]

func defaultGenerator(padding = 16):

	UpdateProgress("Running default generator with map size " + str(mapSize) + "x" + str(mapSize))
	fillMap()


	var randomStructures = [
		[
			['x','x','x','x','x','x','x','x','x','x','x','x'],
			[' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' '],
			[' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' '],
			[' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' '],
			['x','x',' ',' ','x',' ',' ','x',' ',' ','x','x'],
			['x',' ',' ',' ','x',' ',' ','x',' ',' ',' ','x'],
			['x',' ',' ',' ','x',' ','e','x',' ','e',' ','x'],
			['x','x','x','x','x','x','x','x','x','x','x','x']
		],
		[
			['x','x','x','x','x','x','x','x','x','x','x','x'],
			[' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' '],
			[' ',' ',' ',' ','x','l',' ','x',' ',' ',' ',' '],
			[' ','e',' ',' ','x',' ',' ','x',' ',' ',' ',' '],
			['x','x','x','x','x','l',' ','x','x','x','x','x'],
			['x',' ',' ',' ','x',' ',' ','x',' ',' ',' ','x'],
			['x','c',' ',' ',' ',' ','e',' ',' ',' ','c','x'],
			['x','x','x','x','x','x','x','x','x','x','x','x']
		],
	]


	for i in range(randf_range(mapSize/32.0, mapSize/8.0)):
		rooms.append(generateStructure(randf_range(padding, mapSize - padding),randf_range(padding, mapSize - padding), randomStructures[randf_range(0, randomStructures.size())]))


	#Create spawn point
	UpdateProgress("Creating client connection port...")
	var spawnStructure =	[
							['x','x','x','x','x','x','x','x','x'],
							['x',' ','?',' ',' ',' ','?',' ','x'],
							['x',' ',' ',' ',' ',' ',' ',' ',' '],
							['x',' ','p',' ',' ',' ',' ',' ',' '],
							['x','x','x','x','x','x','x','x','x']]
	rooms.append(generateStructure(randf_range(padding, mapSize/3.0),randf_range(padding, mapSize/3.0), spawnStructure))

	var exitStructure =	[
							['x','x','x','x','x','x','x'],
							['x',' ',' ',' ',' ',' ','x'],
							['x',' ',' ',' ',' ',' ','x'],
							[' ',' ',' ','#',' ',' ',' '],
							[' ',' ','x','x','x',' ',' '],
							[' ',' ','x','x','x',' ',' ']]

	rooms.append(generateStructure(randf_range(padding, mapSize - padding),randf_range(padding, mapSize - padding*3), exitStructure))

	createConnections()

	tile_map.set_cell(playerSpawn.x, playerSpawn.y, 0)


	UpdateProgress("Removing all possible escapes...")
	for x in range(0, mapSize):
		for y in range(0, mapSize):
			if x < padding or y < padding or x >= mapSize - padding or y >= mapSize - padding:
				setTile(x,y,"block")

	spawnPlayer()
