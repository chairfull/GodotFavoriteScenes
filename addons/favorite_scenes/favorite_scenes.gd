@tool
extends RefCounted

const PATH := "res://.godot/.favorite_scenes.json"
const GROUPS: PackedStringArray = [
	"Important",
	"Default",
	"Scenes",
	"Locations",
	"Objects",
	"Prefabs",
	"Characters",
	"Items",
	"UI",
	"Menus",
	"Misc",
	"Todo",
	"W.I.P.",
	"Finished",
	"Debug",
]
static var scene_info_list: Array

static func get_state() -> Dictionary:
	if FileAccess.file_exists(PATH):
		return JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return {}

static func set_state(state: Dictionary):
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	var json := JSON.stringify(state, "\t", false)
	f.store_string(json)

static func _static_init() -> void:
	if Engine.is_editor_hint():
		var editor_interface = Engine.get_singleton("EditorInterface")
		var bc: Node = editor_interface.get_base_control()
		var tree := bc.get_tree()
		if not tree.node_added.is_connected(_node_added):
			tree.node_added.connect(_node_added)
		var est := bc.find_child("*EditorSceneTabs*", true, false)
		var tb: TabBar = est.find_child("*TabBar*", true, false)
		if not tb.tab_changed.is_connected(_tab_changed):
			tb.tab_changed.connect(_tab_changed)
		_refresh()

static func _tab_changed(tab: Variant):
	_refresh()

static func _node_added(node: Node):
	var editor_interface = Engine.get_singleton("EditorInterface")
	if node == editor_interface.get_edited_scene_root():
		_refresh()

static func _refresh():
	# Find MenuBar.
	var editor_interface = Engine.get_singleton("EditorInterface")
	var menu: Node = editor_interface.get_base_control().find_child("*MenuBar*", true, false)
	var opened_scenes = editor_interface.get_open_scenes()
	var scene: Node = editor_interface.get_edited_scene_root()
	
	# When scene closes, update the dropdown checks.
	if scene and not scene.tree_exited.is_connected(_refresh.call_deferred):
		scene.tree_exited.connect(_refresh.call_deferred)
	
	# Remove items.
	for child in menu.get_children():
		if "@PopupMenu@" in child.name or child.is_in_group(&"favorite_scenes"):
			menu.remove_child(child)
			child.queue_free()
	
	# Load state.
	var state := get_state()
	scene_info_list.clear()
	
	# Group scenes by group name.
	var grouped := {}
	for path in state:
		var scene_info: Dictionary = state[path]
		if not scene_info.group in grouped:
			grouped[scene_info.group] = []
		grouped[scene_info.group].append(scene_info)
	
	var popup := PopupMenu.new()
	menu.add_child(popup)
	popup.name = "Scenes"
	popup.add_to_group(&"favorite_scenes", true)
	popup.id_pressed.connect(_pressed.bind(popup))
	
	var popup_groups := PopupMenu.new()
	var id := 0
	popup_groups.add_separator("Add to group", id)
	id += 1
	for i in len(GROUPS):
		popup_groups.add_radio_check_item(GROUPS[i], id)
		popup_groups.set_item_tooltip(id, "%s Members" % [len(grouped.get(GROUPS[i], []))])
		id += 1
	popup_groups.add_separator("", id)
	id += 1
	popup_groups.add_item("Remove from favorites", id)
	popup_groups.set_item_disabled(id, not scene or not scene.scene_file_path in state)
	popup_groups.set_item_tooltip(id, "Remove %s?\nYou can't undo." % ["" if not scene else scene.scene_file_path])
	
	# Select the group the current scene is inside of.
	if scene and scene.scene_file_path in state:
		var info: Dictionary = state[scene.scene_file_path]
		var group: int = GROUPS.find(info.group)
		if group != -1:
			popup_groups.set_item_checked(group+1, true)
	
	popup_groups.id_pressed.connect(_pressed_group.bind(popup_groups))
	popup.add_submenu_node_item("Current Scene...", popup_groups, 0)
	id = 0
	popup.set_item_disabled(0, not scene)
	id += 1
	
	# Main Scene.
	var main_scene := ProjectSettings.get_setting("application/run/main_scene")
	popup.add_item("Main Scene", id)
	var indx := popup.get_item_index(id)
	popup.set_item_disabled(indx, main_scene == "")
	if not main_scene:
		popup.set_item_tooltip(indx, "No main_scene set for project.")
	elif scene and main_scene == scene.scene_file_path:
		popup.set_item_tooltip(indx, main_scene + "\n(Loaded & Current Scene)")
	elif main_scene and not main_scene in opened_scenes:
		popup.set_item_tooltip(indx, main_scene + "\n(Not Loaded)")
	else:
		popup.set_item_tooltip(indx, main_scene + "\n(Loaded)")
	popup.set_item_as_checkable(indx, true)
	popup.set_item_checked(indx, main_scene in opened_scenes)
	id += 1
	
	# id 0 = Current scene...
	var base_control = editor_interface.get_base_control()
	for i in len(GROUPS):
		var group := GROUPS[i]
		# Skip empty groups.
		if not group in grouped:
			continue
		# Group name.
		popup.add_separator(group)
		# Group scenes.
		for scene_info: Dictionary in grouped[group]:
			var is_current: bool = scene and scene_info.path == scene.scene_file_path
			var is_opened: bool = scene_info.path in opened_scenes
			popup.add_item(scene_info.name, id)
			var index := popup.get_item_index(id)
			if is_current:
				popup.set_item_tooltip(index, scene_info.path + "\n(Loaded & Current Scene)")
			elif not is_opened:
				popup.set_item_tooltip(index, scene_info.path + "\n(Not Loaded)")
			else:
				popup.set_item_tooltip(index, scene_info.path + "\n(Loaded)")
			popup.set_item_icon(index, base_control.get_theme_icon(scene_info.clss, "EditorIcons"))
			popup.set_item_as_checkable(index, true)
			popup.set_item_checked(index, is_opened)
			popup.set_item_disabled(index, is_current)
			popup.set_item_icon_modulate(index, Color.GREEN_YELLOW if is_current else Color.WHITE)
			scene_info_list.append(scene_info)
			id += 1

static func _pressed_group(id: int, popup_groups: PopupMenu):
	var editor_interface = Engine.get_singleton("EditorInterface")
	var scene: Node = editor_interface.get_edited_scene_root()
	
	if not scene:
		return
	
	var path := scene.scene_file_path
	
	#TODO: Allow undo/redo.
	#EditorInterface.get_editor_undo_redo()
	
	match popup_groups.get_item_text(popup_groups.get_item_index(id)):
		"Remove from favorites":
			# Remove.
			var state := get_state()
			state.erase(path)
			set_state(state)
		
		_:
			# Add to group.
			var state := get_state()
			state[path] = {
				name = scene.name,
				path = path,
				clss = scene.get_class(),
				group = GROUPS[id-1],
			}
			set_state(state)
	
	_refresh()

static func _pressed(id: int, popup: PopupMenu):
	if id == 0:
		# Shouldn't happen?
		return
	
	var editor_interface = Engine.get_singleton("EditorInterface")
	var opened_scenes = editor_interface.get_open_scenes()
	var scene_info: Dictionary = scene_info_list[id-2]
	var scene_exists := true
	
	# Open if not opened.
	if not scene_info.path in opened_scenes:
		if FileAccess.file_exists(scene_info.path):
			editor_interface.open_scene_from_path(scene_info.path)
		else:
			scene_exists = false
			push_error("Scene no longer exists at: %s. Removing from favorites." % [scene_info.path])
			var state := get_state()
			state.erase(scene_info.path)
			set_state(state)
	
	# Force select this tab as active.
	if scene_exists:
		var bc = editor_interface.get_base_control()
		var est = bc.find_child("*EditorSceneTabs*", true, false)
		var tb: TabBar = est.find_child("*TabBar*", true, false)
		var tab_title = scene_info.path.get_basename().get_file()
		for i in tb.tab_count:
			if tb.get_tab_title(i) == tab_title:
				tb.current_tab = i
				break
	
	_refresh()
