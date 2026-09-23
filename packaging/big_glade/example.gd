extends Node3D
## Attach to an empty Node3D in a Godot 4.5 scene after importing the addon.
## Add a Camera3D and lighting to view this welcoming smith's cottage.

func _ready() -> void:
	var request := BuildingRequest.house(42, &"cottage", &"smith", 9.0, 12.0, 2.6)
	var document := BigGlade.generate_document(request)
	if document.is_ok():
		add_child(BigGlade.instantiate(document, false, true))
	else:
		push_error(str(document.errors))
