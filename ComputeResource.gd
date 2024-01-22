extends Resource
class_name ComputeResource

var rd :RenderingDevice 
var shader_file_path:String=""
var shader_file = null
var spirv: RDShaderSPIRV = null
var shader = null
## the uniforms being passed into the compute shader
var uniform_sets:Array[RID]=[]
##the uniform ids themselves
var uniforms:Array[RDUniform]=[]
## the buffers in the compute shader.
## if you are passing data from compute shader to a Texture2DRD you use this RID
## same for if you are using it for vertex data for a mesh.
var buffers:Array[RID]=[]

var pipeline:RID

var thread_count:Vector3i=Vector3i.ONE


var run_count:int=0

## stores the formats of anything created for the rendering device.
## bit cumbersome but i'm working on it.
var data_formats:Array=[]


## running on render thread allows passing data between the shader and renderer directly
## meaning no grab from shader process put in texture, now you can just 
## run it, put that texture RID in the rid of the Texture2DRD, and be done.
## also useful for procedural mesh generation
var run_on_render_thread:bool=false


func _init(on_render_thread:bool=false,file_used:String="null")->void:
	
	shader_file_path=file_used
	#not much but hey if it works it works
	run_on_render_thread=on_render_thread
	if run_on_render_thread:RenderingServer.call_on_render_thread(_init_from_used_thread)


func _init_from_used_thread()->void:
	
	if run_on_render_thread:
		rd=RenderingServer.get_rendering_device()
	else:
		rd=RenderingServer.create_local_rendering_device()
	shader_file=load(shader_file_path)
	spirv=shader_file.get_spirv()
	shader=rd.shader_create_from_spirv(spirv)
	pipeline=rd.compute_pipeline_create(shader)


func create_texture_format(
	width:int=1,
	height:int=1,
	depth:int=1,
	usage_bits:RenderingDevice.TextureUsageBits=0,
	texture_type:RenderingDevice.TextureType=0,
	texture_format:RenderingDevice.DataFormat=RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM,
	array_layers:int=1,
	minimaps:int=1,
)->int:
	
	var format_created=RDTextureFormat.new()
	format_created.width=width
	format_created.height=height
	format_created.depth=depth
	format_created.array_layers=array_layers
	format_created.mipmaps=minimaps
	format_created.usage_bits=usage_bits
	format_created.texture_type=texture_type
	format_created.format=texture_format
	
	return add_format(format_created)

## allows swapping a format.
func replace_format(format_id:int,new_format):
	#free the old rid if it doesn't exist anymore
	if data_formats[format_id]!=new_format and data_formats[format_id] is RID:
		rd.free_rid(data_formats[format_id])
	data_formats[format_id]=new_format


func add_format(format)->int:
	data_formats.push_back(format)
	
	return len(data_formats)-1


func create_uniform_set(uniform_ids:Array[int],shader_set:int=0)->int:
	var set_uniforms=[]
	for i in uniform_ids:
		set_uniforms.push_back(uniforms[i])
	
	var created_set=rd.uniform_set_create(set_uniforms,shader,shader_set)
	uniform_sets.push_back(created_set)
	return len(uniform_sets)-1

func create_uniform(uniform_type:RenderingDevice.UniformType,uniform_binding:int,attached_buffers:Array[int]=[])->int:
	var uniform = RDUniform.new()
	
	uniform.uniform_type=uniform_type
	uniform.binding=uniform_binding
	#attach any buffers to it here, you can update it later but this
	#is to let me keep it shorter for the user
	for buffer_to_attach in attached_buffers:
		uniform.add_id(buffers[buffer_to_attach])
	
	
	uniforms.push_back(uniform)
	return len(uniforms)-1

func clear_uniform_buffer_ids(uniform_id:int):
	uniforms[uniform_id].clear_ids()
func add_uniform_buffer_id(uniform_id:int,buffer_id:int):
	uniforms[uniform_id].add_id(buffers[buffer_id])
func add_uniform_buffer_rid(uniform_id:int,buffer:RID):
	uniforms[uniform_id].add_id(buffer)

func create_storage_buffer(total_size:int)->int:
	var created_buffer=rd.storage_buffer_create(total_size,PackedByteArray())
	buffers.push_back(created_buffer)
	return len(buffers)-1
func create_storage_buffer_filled(total_size:int,data_provided:PackedByteArray)->int:
	var created_buffer=rd.storage_buffer_create(max(total_size,len(data_provided)),data_provided)
	buffers.push_back(created_buffer)
	return len(buffers)-1


## not sure the difference from storage buffers but if you want it then here you go i guess.
func create_uniform_buffer(total_size:int)->int:
	var created_buffer=rd.uniform_buffer_create(total_size,PackedByteArray())
	buffers.push_back(created_buffer)
	return len(buffers)-1
func create_uniform_buffer_filled(total_size:int,data_provided:PackedByteArray)->int:
	var created_buffer=rd.uniform_buffer_create(max(total_size,len(data_provided)),data_provided)
	buffers.push_back(created_buffer)
	return len(buffers)-1


## textures are treated as buffer bor ease of use by me.
## bit awkward but i'll work on figuring out the texture_buffer itself later. :\
func create_texture(using_format:int)->int:
	var created_texture=rd.texture_create(get_format(using_format),RDTextureView.new())
	buffers.push_back(created_texture)
	return len(buffers)-1
func create_texture_filled(using_format:int,data_provided:Array[PackedByteArray])->int:
	var created_texture=rd.texture_create(get_format(using_format),RDTextureView.new(),data_provided)
	buffers.push_back(created_texture)
	return len(buffers)-1


## never used vertex buffer much, but heres for those of you who do.
func create_vertex_buffer(total_size:int,as_storage:bool=false)->int:
	var created_buffer=rd.vertex_buffer_create(total_size,PackedByteArray(),as_storage)
	buffers.push_back(created_buffer)
	return len(buffers)-1
func create_vertex_buffer_filled(total_size:int,data_provided:PackedByteArray,as_storage:bool=false)->int:
	var created_buffer=rd.vertex_buffer_create(max(total_size,len(data_provided)),data_provided,as_storage)
	buffers.push_back(created_buffer)
	return len(buffers)-1


##sets how many threads to use in xyz on the shader
func set_thread_dimensions(x:int=1,y:int=1,z:int=1):
	thread_count=Vector3i(x,y,z)


## gets the generated format from the id that is provided
func get_format(format_id:int):
	return data_formats[format_id]

## gets the generated uniform from its id that is provided
func get_uniform(uniform_id:int)->RDUniform:
	return uniforms[uniform_id]

## gets the RID of the generated buffer.
## useful for grabbing the one made from the create_buffer functions
func get_buffer(buffer_id:int)->RID:
	return buffers[buffer_id]


func run_compute(call_back=null)->void:
	if run_on_render_thread:
		RenderingServer.call_on_render_thread(_actually_run_compute.bind(call_back))
	else:
		_actually_run_compute(call_back)
	run_count+=1

var used_uniforms:Array[int]=[]
##sets the uniforms to be used by the compute shader and their order
func set_uniform_used_order(used:Array[int])->void:
	used_uniforms=used

var used_constants:PackedByteArray
func set_constants(constants:PackedByteArray)->void:
	used_constants=constants

func _actually_run_compute(call_back:Callable)->void:
	var compute_list=rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	for i in len(used_uniforms):
		rd.compute_list_bind_uniform_set(compute_list, uniform_sets[used_uniforms[i]], i)
	#rd.compute_list_set_push_constant(compute_list,used_constants,used_constants.size())
	rd.compute_list_dispatch(compute_list, thread_count.x, thread_count.y, 1)
	rd.compute_list_end()
	if call_back:
		call_back.call()

