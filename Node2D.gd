extends Node2D

var compute_resource:ComputeResource
var uniform_light_inputs
var light_input
# Called when the node enters the scene tree for the first time.
func _ready():
	compute_resource=ComputeResource.new(
		true,"res://compute_light.glsl"
	)
	var map_size=$TileMap.get_used_rect()
	var map_format=compute_resource.create_texture_format(
		map_size.size.x,map_size.size.y,1,RenderingDevice.TEXTURE_USAGE_STORAGE_BIT+RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT+RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT+RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT,
		RenderingDevice.TEXTURE_TYPE_2D,
		RenderingDevice.DATA_FORMAT_R8_UNORM
	)
	var light_map_format=compute_resource.create_texture_format(
		map_size.size.x*8,map_size.size.y*8,1,RenderingDevice.TEXTURE_USAGE_STORAGE_BIT+RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT+RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT+RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT+RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT,
		RenderingDevice.TEXTURE_TYPE_2D,
		RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	)
	
	var map_data=Image.create(map_size.size.x,map_size.size.y,false,Image.FORMAT_R8)
	map_data.fill(Color.BLACK)
	var used_cells=$TileMap.get_used_cells(0)
	for cell in used_cells:
		map_data.set_pixelv(cell,Color.WHITE)
	
	var map_buffer=compute_resource.create_texture_filled(map_format,[map_data.get_data()])
	
	var v=PackedByteArray()
	v.resize(1792)
	v.fill(0)
	var input_lights=compute_resource.create_storage_buffer(1792)
	
	
	light_input=input_lights
	var light_map_buffer=compute_resource.create_texture(light_map_format)
	var light_map_other_buffer=compute_resource.create_texture(light_map_format)
	var map_uniform=compute_resource.create_uniform(RenderingDevice.UNIFORM_TYPE_IMAGE,0,[map_buffer])
	var light_uniform=compute_resource.create_uniform(RenderingDevice.UNIFORM_TYPE_IMAGE,0,[light_map_buffer])
	var light_other_uniform=compute_resource.create_uniform(RenderingDevice.UNIFORM_TYPE_IMAGE,0,[light_map_other_buffer])
	var light_buff_uni=compute_resource.create_uniform(RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,0,[input_lights])
	
	var uniform_set=compute_resource.create_uniform_set([map_uniform],0)
	var uniform_set_light_a=compute_resource.create_uniform_set([light_uniform],1)
	var uniform_set_light_b=compute_resource.create_uniform_set([light_other_uniform],1)
	
	
	
	uniform_light_inputs=compute_resource.create_uniform_set([light_buff_uni],2)
	
	
	compute_resource.set_uniform_used_order([uniform_set,uniform_set_light_a,uniform_light_inputs])
	var constant_bytes=PackedByteArray()
	constant_bytes.resize(16)
	constant_bytes.encode_u32(0,256)
	
	compute_resource.set_constants(constant_bytes)
	
	RenderingServer.call_on_render_thread(create_img)
	RenderingServer.call_on_render_thread(update_img)
	
	compute_resource.set_thread_dimensions(floor(map_size.size.x),floor(map_size.size.y))
	#compute_resource.set_thread_dimensions(8,8)
	
	
	compute_resource.run_compute()
	RenderingServer.call_on_render_thread(update_img)
	compute_resource.run_compute()
	RenderingServer.call_on_render_thread(update_img)
func create_img():
	var t:=Texture2DRD.new()
	$Sprite2D.texture=t

func update_img():
	compute_resource.set_uniform_used_order([0,compute_resource.run_count%2 +1,uniform_light_inputs])
	
	$Sprite2D.texture.texture_rd_rid=compute_resource.get_buffer((compute_resource.run_count+1)%2 +2)


var t:float=0
func _physics_process(delta):
	t+=delta
	var constant_bytes=PackedByteArray()
	constant_bytes.resize(16)
	constant_bytes.encode_u32(0,int(128+16*sin(t)))
	constant_bytes.encode_float(8,get_global_mouse_position().x*0.0625)
	constant_bytes.encode_float(12,get_global_mouse_position().y*0.0625)
	compute_resource.set_constants(constant_bytes)
	
	var light_input_buffer=compute_resource.get_buffer(light_input)
	var updated_light=PackedByteArray()
	updated_light.resize(48)
	updated_light.encode_float(0,get_global_mouse_position().x*0.03125)
	updated_light.encode_float(4,get_global_mouse_position().y*0.03125)
	updated_light.encode_u32(8,64)
	updated_light.encode_float(12,1)
	updated_light.encode_float(16,0)
	updated_light.encode_float(20,0)
	updated_light.encode_float(24,12)
	updated_light.encode_float(28,12)
	updated_light.encode_u32(32,128)
	updated_light.encode_float(36,1)
	updated_light.encode_float(40,0)
	updated_light.encode_float(44,0.0)
	compute_resource.rd.buffer_update(light_input_buffer,0,48,updated_light)
	
	
	
	compute_resource.run_compute(update_img)
