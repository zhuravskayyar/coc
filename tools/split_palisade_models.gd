extends SceneTree

const SOURCE_MODEL := "res://assets/buildings/palisade/wooden_cross_post.glb"
const POST_OUTPUT := "res://assets/buildings/palisade/fence_post.glb"
const BEAM_OUTPUT := "res://assets/buildings/palisade/fence_beam.glb"
const POST_CENTROID_MAX_X := -0.25
const RAIL_CENTROID_MIN_X := 0.27
const RAIL_MIN_Y := 0.22
const RAIL_MAX_Y := 0.49
const TARGET_BEAM_HALF_LENGTH := 0.49
const BEAM_CENTER_OVERLAP := 0.01


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source_scene := load(SOURCE_MODEL) as PackedScene
	if source_scene == null:
		push_error("Could not load the source palisade GLB")
		quit(1)
		return
	var source_root := source_scene.instantiate() as Node3D
	root.add_child(source_root)
	await process_frame
	var mesh_nodes := source_root.find_children("*", "MeshInstance3D", true, false)
	var source_instance := mesh_nodes[0] as MeshInstance3D if not mesh_nodes.is_empty() else null
	if source_instance == null or source_instance.mesh == null or source_instance.mesh.get_surface_count() != 1:
		push_error("Expected one mesh surface in the source palisade GLB")
		quit(1)
		return
	var source_mesh := source_instance.mesh
	var post_mesh := _build_post_mesh(source_mesh)
	var beam_mesh := _build_beam_mesh(source_mesh)
	if post_mesh == null or beam_mesh == null:
		push_error("Could not split post and beam geometry from the source GLB")
		quit(1)
		return
	var post_error := _write_glb("Fence_Post", post_mesh, POST_OUTPUT)
	var beam_error := _write_glb("Fence_Beam", beam_mesh, BEAM_OUTPUT)
	if post_error != OK or beam_error != OK:
		push_error("Could not export the split palisade GLBs")
		quit(1)
		return
	print("Created separate fence assets: ", POST_OUTPUT, " and ", BEAM_OUTPUT)
	quit(0)


func _build_post_mesh(source: Mesh) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var min_x := INF
	var max_x := -INF
	for index in range(0, indices.size(), 3):
		var a := indices[index]
		var b := indices[index + 1]
		var c := indices[index + 2]
		var center_x := (vertices[a].x + vertices[b].x + vertices[c].x) / 3.0
		if center_x >= POST_CENTROID_MAX_X:
			continue
		for vertex_index in [a, b, c]:
			min_x = minf(min_x, vertices[vertex_index].x)
			max_x = maxf(max_x, vertices[vertex_index].x)
	if min_x >= INF or max_x <= -INF:
		return null
	var center_x := (min_x + max_x) * 0.5
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(source.surface_get_material(0))
	for index in range(0, indices.size(), 3):
		var a := indices[index]
		var b := indices[index + 1]
		var c := indices[index + 2]
		var triangle_center_x := (vertices[a].x + vertices[b].x + vertices[c].x) / 3.0
		if triangle_center_x >= POST_CENTROID_MAX_X:
			continue
		for vertex_index in [a, b, c]:
			tool.set_normal(normals[vertex_index])
			tool.set_uv(uvs[vertex_index])
			tool.add_vertex(vertices[vertex_index] - Vector3(center_x, 0.0, 0.0))
	return tool.commit()


func _build_beam_mesh(source: Mesh) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var inner_x := INF
	var farthest_x := -INF
	for index in range(0, indices.size(), 3):
		var a := indices[index]
		var b := indices[index + 1]
		var c := indices[index + 2]
		var center_x := (vertices[a].x + vertices[b].x + vertices[c].x) / 3.0
		var center_y := (vertices[a].y + vertices[b].y + vertices[c].y) / 3.0
		if center_x <= RAIL_CENTROID_MIN_X or center_y < RAIL_MIN_Y or center_y > RAIL_MAX_Y:
			continue
		for vertex_index in [a, b, c]:
			inner_x = minf(inner_x, vertices[vertex_index].x)
			farthest_x = maxf(farthest_x, vertices[vertex_index].x)
	if inner_x >= INF or farthest_x <= inner_x:
		return null
	var half_scale := (TARGET_BEAM_HALF_LENGTH + BEAM_CENTER_OVERLAP * 0.5) / (farthest_x - inner_x)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(source.surface_get_material(0))
	for index in range(0, indices.size(), 3):
		var a := indices[index]
		var b := indices[index + 1]
		var c := indices[index + 2]
		var center_x := (vertices[a].x + vertices[b].x + vertices[c].x) / 3.0
		var center_y := (vertices[a].y + vertices[b].y + vertices[c].y) / 3.0
		if center_x <= RAIL_CENTROID_MIN_X or center_y < RAIL_MIN_Y or center_y > RAIL_MAX_Y:
			continue
		var triangle := [a, b, c]
		for mirrored in [false, true]:
			var order := triangle if not mirrored else [a, c, b]
			for vertex_index in order:
				var position := vertices[vertex_index]
				var normal := normals[vertex_index]
				position.x = -BEAM_CENTER_OVERLAP * 0.5 + (position.x - inner_x) * half_scale
				normal.x /= half_scale
				if mirrored:
					position.x = -position.x
					normal.x = -normal.x
				normal = normal.normalized()
				tool.set_normal(normal)
				tool.set_uv(uvs[vertex_index])
				tool.add_vertex(position)
	return tool.commit()


func _write_glb(asset_name: String, mesh: Mesh, output_path: String) -> Error:
	var asset_root := Node3D.new()
	asset_root.name = asset_name
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = mesh
	asset_root.add_child(mesh_instance)
	root.add_child(asset_root)
	var document := GLTFDocument.new()
	document.image_format = "JPEG"
	document.lossy_quality = 0.9
	var state := GLTFState.new()
	var error := document.append_from_scene(asset_root, state)
	if error == OK:
		error = document.write_to_filesystem(state, ProjectSettings.globalize_path(output_path))
	asset_root.free()
	return error
