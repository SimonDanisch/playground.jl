using ModernGL
using GLAbstraction, GLWindow, Reactive

window = createwindow("asd", 700,700, debugging=false)

cam = PerspectiveCamera(window.inputs, Vec3(1,0,0), Vec3(0))

vert = vert" 
{{GLSL_VERSION}}
struct Circle{
	vec3 lol;
};

struct Test{
	vec3 t;
}test;
uniform Camera{
	mat4 projection; 
	mat4 view;
};
uniform Cube{
	mat4 projection; 
	mat4 view;
}cube;
uniform vec2 te;


in vec3 vertex;

void main() {
	gl_Position = cube.projection * cube.view * projection * view * vec4(vertex+test.t, te.x);
}
"

frag = frag"
{{GLSL_VERSION}}
out vec4 frag_color;
void main() {
frag_color = vec4(1.0,0.0, 1.0, 1.0);
}
"


v, uvw, idx = gencube(1f0,1f0,1f0)
indexes 	= indexbuffer(idx)
verts 		= GLBuffer(v)


printdict(enum::GLENUM, intend::Integer) = string(enum.name)
printdict(x, intend::Integer) = string(x)
function printdict(keyvalue::Tuple, intend::Integer)
	string(" "^intend, keyvalue[1], ": ", printdict(keyvalue[2], intend), "\n")
end

function printdict(d::Dict, intend::Integer = 1)
	intend += 1
	result = ""
	for elem in d
		result *= printdict(elem, intend) * "\n"
	end
	result
end
p = TemplateProgram([vert, frag])
glGetProgramiv(p.id, GL_ACTIVE_UNIFORM_BLOCKS)

getAttributesInfo(p)
println(printdict(getUniformsInfo(p)))


const vbo = GLVertexArray(
	Dict{Symbol, GLBuffer}(
		:vertex => verts,
		:name_doesnt_matter_for_indexes => indexes
	), p
	)

immutable Cam
	projection::Mat4
	view::Mat4
end

bindingPoint 	= 1
myFloats 		= Mat4[cam.projection.value, cam.view.value] 
blockIndex 		= glGetUniformBlockIndex(p.id, "Camera")
#glGetActiveUniformsiv(p,1,[blockIndex], GL_UNIFORM_TYPE)
@assert blockIndex != GL_INVALID_INDEX "shiit not a valid index"
glUniformBlockBinding(p.id, blockIndex, bindingPoint)

buffer = GLuint[0]
glGenBuffers(1, buffer)
glBindBuffer(GL_UNIFORM_BUFFER, buffer[1])

glBufferData(GL_UNIFORM_BUFFER, sizeof(myFloats), myFloats, GL_DYNAMIC_DRAW)
glBindBufferBase(GL_UNIFORM_BUFFER, bindingPoint, buffer[1])

lift(cam.projection, cam.view) do projection, view
	myFloats 		= [projection, view]
	glBindBuffer(GL_UNIFORM_BUFFER, buffer[1])
	glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(myFloats), myFloats)
end


glUseProgram(p.id)

glClearColor(0,0,0,1)
while window.inputs[:open].value
  	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
	render(vbo)
	GLFW.SwapBuffers(window.nativewindow)
	GLFW.PollEvents()
	sleep(0.01)
end
GLFW.Terminate()