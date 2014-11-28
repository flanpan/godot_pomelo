extends Node


var current_scene = null
var pomelo  = load("res://pomelo.gd").new()
var httpClient = load('res://httpClient.gd').new()

func goto_scene(scene):
	#load new scene
	var s = ResourceLoader.load(scene)
	#queue erasing old (don't use free because that scene is calling this method)
	current_scene.queue_free()
	#instance the new scene
	current_scene = s.instance()
	#add it to the active scene, as child of root
	get_scene().get_root().add_child(current_scene)
	

func _init():
	set_process(true)
	add_child(pomelo)
	add_child(httpClient)

func _process(d):
	#print("g")
	pass

func _ready():
	# get the current scene
	# it is always the last child of root,
	# after the autoloaded nodes
	var root = get_tree().get_root()
	#current_scene = root.get_child( root.get_child_count() -1 )
	#current_scene.add_child(pomelo)
	#for i in range(root.get_child_count()):
	#	print(root.get_child(i).get_type())
	
