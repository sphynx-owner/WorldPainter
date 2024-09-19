extends Node
class_name WorldBrush

@export var brush_size : float = 1

@export var paint_texture : Texture2D

var paint_texture_uniform : RDUniform 

func _ready():
	RenderingServer.call_on_render_thread(initialize_compute)

func initialize_compute():
	# We will be using our own RenderingDevice to handle the compute commands
	var rd : RenderingDevice = RenderingServer.get_rendering_device()
	
	var sampler_state := RDSamplerState.new()
	
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	
	var linear_sampler : RID = rd.sampler_create(sampler_state)
	
	var paint_image : Image = paint_texture.get_image()
	paint_image.clear_mipmaps()
	paint_image.decompress()
	paint_image.convert(Image.FORMAT_RGBAF)
	
	var paint_texture_format : RDTextureFormat = RDTextureFormat.new()
	paint_texture_format.width = paint_image.get_width()
	paint_texture_format.height = paint_image.get_height()
	paint_texture_format.depth = 1
	
	paint_texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	
	paint_texture_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	
	paint_texture_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	
	var paint_texture_view : RDTextureView = RDTextureView.new()
	
	var paint_texture_rd = rd.texture_create(paint_texture_format, paint_texture_view, [paint_image.get_data()])
	
	paint_texture_uniform = RDUniform.new()
	paint_texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	paint_texture_uniform.binding = 1
	paint_texture_uniform.add_id(linear_sampler)
	paint_texture_uniform.add_id(paint_texture_rd)
