extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var noise:=FastNoiseLite.new()
 noise.seed=73191
 noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
 noise.frequency=0.035
 noise.fractal_type=FastNoiseLite.FRACTAL_FBM
 noise.fractal_octaves=5
 noise.fractal_gain=0.5
 var source:=NoiseTexture3D.new()
 source.width=128
 source.height=128
 source.depth=128
 source.seamless=true
 source.noise=noise
 await create_timer(0.1).timeout
 while source.get_data().is_empty():await create_timer(0.05).timeout
 var data:=source.get_data()
 var texture:=ImageTexture3D.new()
 var result:=texture.create(data[0].get_format(),128,128,128,false,data)
 print("VOLUME ",result," slices ",data.size())
 print("SAVE ",ResourceSaver.save(texture,"res://assets/ui/nebula_volume.res",ResourceSaver.FLAG_COMPRESS))
 quit()
