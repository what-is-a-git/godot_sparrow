@tool
class_name SparrowSpriteFrames extends EditorImportPlugin


func _get_importer_name() -> String:
	return 'com.what-is-a-git.godot-sparrow'


func _get_visible_name() -> String:
	return 'Sparrow Atlas'


func _get_recognized_extensions() -> PackedStringArray:
	return ['xml',]


func _get_save_extension() -> String:
	return 'res'


func _get_resource_type() -> String:
	return 'SpriteFrames'


func _get_preset_count() -> int:
	return 1


func _get_preset_name(preset_index: int) -> String:
	return 'Default'


func _get_import_options(path: String, preset_index: int):
	return [
		{'name': 'use_offsets', 'default_value': true},
		{'name': 'animation_framerate', 'default_value': 24,
				'property_hint': PROPERTY_HINT_RANGE,
				'hint_string': '0,128,1,or_greater'},
		{'name': 'animations_looped', 'default_value': false},
		{'name': 'store_external_spriteframes', 'default_value': false},]


func _get_priority() -> float:
	return 1.0


func _get_import_order() -> int:
	return 16


func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true


func _import(source_file: String, save_path: String, options: Dictionary, 
		platform_variants: Array[String], gen_files: Array[String]) -> Error:
	if not FileAccess.file_exists(source_file):
		return ERR_FILE_NOT_FOUND
	
	var xml: XMLParser = XMLParser.new()
	xml.open(source_file)
	
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation('default')
	
	var texture: Texture2D = null
	
	# This is done to prevent reuse of atlas textures.
	# The actual difference this makes may be unnoticable but it is still done.
	var frames_cache: Array[SparrowFrame] = []
	
	while xml.read() == OK:
		if xml.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		
		var node_name: String = xml.get_node_name().to_lower()
		
		if node_name == 'textureatlas':
			var image_name: StringName = xml.get_named_attribute_value_safe('imagePath')
			var image_path: String = '%s/%s' % [source_file.get_base_dir(), image_name]
			
			if not FileAccess.file_exists(image_path):
				return ERR_FILE_NOT_FOUND
			
			# We need to ignore the cache to prevent potential issues with corrupted textures.
			texture = ResourceLoader.load(image_path, 'CompressedTexture2D', ResourceLoader.CACHE_MODE_IGNORE)
			continue
		
		if node_name != 'subtexture':
			continue
		
		# Couldn't find texture from imagePath in TextureAtlas.
		if texture == null:
			return ERR_FILE_MISSING_DEPENDENCIES
		
		var frame: SparrowFrame = SparrowFrame.new()
		frame.name = xml.get_named_attribute_value_safe('name')
		
		if frame.name == '':
			continue
		
		frame.source = Rect2i(
			Vector2i(xml.get_named_attribute_value_safe('x').to_int(),
					xml.get_named_attribute_value_safe('y').to_int(),),
			Vector2i(xml.get_named_attribute_value_safe('width').to_int(),
					xml.get_named_attribute_value_safe('height').to_int(),),)
		frame.offsets = Rect2i(
			Vector2i(xml.get_named_attribute_value_safe('frameX').to_int(),
					xml.get_named_attribute_value_safe('frameY').to_int(),),
			Vector2i(xml.get_named_attribute_value_safe('frameWidth').to_int(),
					xml.get_named_attribute_value_safe('frameHeight').to_int(),),)
		frame.has_offsets = xml.has_attribute('frameX') and options.get('use_offsets', true)
		
		var frame_number: StringName = frame.name.right(4)
		var animation_name: StringName = frame.name.left(frame.name.length() - 4)
		
		# By default we support animations with name0000, name0001, etc.
		# We should still allow other sprites to be exported properly however.
		if not frame_number.is_valid_int():
			animation_name = frame.name
		
		for cached_frame in frames_cache:
			if cached_frame.source == frame.source and \
					cached_frame.offsets == frame.offsets:
				frame = cached_frame
		
		# Unique new frame! Awesome.
		if frame.atlas == null:
			frame.atlas = AtlasTexture.new()
			
			# Just used to not have to reference frame 24/7.
			var atlas: AtlasTexture = frame.atlas
			atlas.atlas = texture
			atlas.filter_clip = true
			atlas.region = frame.source
			
			if frame.has_offsets:
				if frame.offsets.size == Vector2i.ZERO:
					frame.offsets.size = frame.source.size
				
				# Once again just not referencing frame constantly.
				var source: Rect2i = frame.source
				var offsets: Rect2i = frame.offsets
				
				var margin: Rect2i = Rect2i(
					-offsets.position.x, -offsets.position.y,
					offsets.size.x - source.size.x, offsets.size.y - source.size.y)
				
				margin.size = margin.size.clamp(margin.position.abs(), Vector2i.MAX)
				atlas.margin = margin
		
		if not frames.has_animation(animation_name):
			frames.add_animation(animation_name)
			frames.set_animation_loop(animation_name, options.get('animations_looped', false))
			frames.set_animation_speed(animation_name, options.get('animation_framerate', 24))
		
		frames.add_frame(animation_name, frame.atlas)

	var filename: StringName = &'%s.%s' % [save_path, _get_save_extension()]
	
	if options.get('store_external_spriteframes', false):
		filename = &'%s.%s' % [source_file.get_basename(), _get_save_extension()]
		return ResourceSaver.save(frames, filename, ResourceSaver.FLAG_COMPRESS)
	
	return ResourceSaver.save(frames, filename, ResourceSaver.FLAG_COMPRESS)
