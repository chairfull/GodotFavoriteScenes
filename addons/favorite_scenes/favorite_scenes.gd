@tool
extends RefCounted

static var paths: Dictionary

static func _static_init() -> void:
	if not Engine.is_editor_hint():
		return
	
	# Reset path cache.
	paths.clear()
	
	# Find MenuBar.
	var editor_interface = Engine.get_singleton("EditorInterface")
	var menu: Node = editor_interface.get_base_control().find_child("*MenuBar*", true, false)
	var opened_scenes = editor_interface.get_open_scenes()
	
	# Remove items.
	for child in menu.get_children():
		if "@PopupMenu@" in child.name or child.is_in_group(&"favorite_scenes"):
			menu.remove_child(child)
			child.queue_free()
	
	var popup := PopupMenu.new()
	menu.add_child(popup)
	popup.name = "Scenes"
	popup.add_to_group(&"favorite_scenes", true)
	popup.id_pressed.connect(_pressed.bind(popup))
	
	var id := 0
	# Load "favorites" file.
	for path in FileAccess.get_file_as_string("res://.godot/editor/favorites").split("\n"):
		# Find scenes.
		if path.ends_with(".tscn") or path.ends_with(".scn"):
			var sname := path.get_basename().get_file()
			paths[id] = path
			popup.add_item(sname, id)
			var index = popup.get_item_index(id)
			popup.set_item_tooltip(index, path)
			popup.set_item_as_checkable(index, true)
			popup.set_item_checked(index, path in opened_scenes)
			id += 1

static func _pressed(id: int, popup: PopupMenu):
	var path: String = paths.get(id, "")
	if not path:
		return
	
	var editor_interface = Engine.get_singleton("EditorInterface")
	var opened_scenes = editor_interface.get_open_scenes()
	
	# Open if not opened.
	if not path in opened_scenes:
		editor_interface.open_scene_from_path(path)
	
	# Force select this tab as active.
	var bc = editor_interface.get_base_control()
	var est = bc.find_child("*EditorSceneTabs*", true, false)
	var tb: TabBar = est.find_child("*TabBar*", true, false)
	var tab_title = path.get_basename().get_file()
	for i in tb.tab_count:
		if tb.get_tab_title(i) == tab_title:
			tb.current_tab = i
			break
	
	# When scene closes, update the dropdown checks.
	var scene: Node = editor_interface.get_edited_scene_root()
	if not scene.tree_exited.is_connected(_update_checks.call_deferred):
		scene.tree_exited.connect(_update_checks.call_deferred.bind(popup))
	
	_update_checks.call_deferred(popup)

# Display which scenes are open and closed using checkboxes.
static func _update_checks(popup: PopupMenu):
	var editor_interface = Engine.get_singleton("EditorInterface")
	var opened_scenes = editor_interface.get_open_scenes()
	for idd in paths:
		popup.set_item_checked(idd, paths[idd] in opened_scenes)
