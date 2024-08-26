extends Node

func _ready():
	
	# We will be using our own RenderingDevice to handle the compute commands
	var rd = RenderingServer.create_local_rendering_device()
	
	# Create shader and pipeline
	var shader_file = load("res://minimal_compute.glsl")
	var shader_bytecode = shader_file.get_bytecode()
	var shader = rd.shader_create(shader_bytecode)
	var pipeline = rd.compute_pipeline_create(shader)
	
	# Data for compute shaders has to come as an array of bytes
	var pba = PackedByteArray()
	pba.resize(64)
	for i in range(16):
		pba.encode_float(i*4, 2.0)
	
	# Create storage buffer
	# Data not needed, can just create with length
	var storage_buffer = rd.storage_buffer_create(64, pba)
	
	# Create uniform set using the storage buffer
	var u = RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u.binding = 0
	u.add_id(storage_buffer)
	var uniform_set = rd.uniform_set_create([u], shader, 0)
	
	# Start compute list to start recording our compute commands
	var compute_list = rd.compute_list_begin()
	# Bind the pipeline, this tells the GPU what shader to use
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	# Binds the uniform set with the data we want to give our shader
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	# Dispatch 1x1x1 (XxYxZ) work groups
	rd.compute_list_dispatch(compute_list, 2, 1, 1)
	#rd.compute_list_add_barrier(compute_list)
	# Tell the GPU we are done with this compute task
	rd.compute_list_end()
	# Force the GPU to start our commands
	rd.submit()
	# Force the CPU to wait for the GPU to finish with the recorded commands
	rd.sync()
	
	# Now we can grab our data from the storage buffer
	var byte_data = rd.buffer_get_data(storage_buffer)
	for i in range(16):
		print(byte_data.decode_float(i*4))
