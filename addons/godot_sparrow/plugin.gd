@tool
extends EditorPlugin


var sparrow_spriteframes: SparrowSpriteFrames


func _enter_tree() -> void:
	sparrow_spriteframes = SparrowSpriteFrames.new()
	add_import_plugin(sparrow_spriteframes)


func _exit_tree() -> void:
	remove_import_plugin(sparrow_spriteframes)
	sparrow_spriteframes = null
