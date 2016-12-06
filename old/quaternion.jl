using GLAbstraction, GeometryTypes, ModernGL, Compat, Reactive, Quaternions
using GLFW # <- need GLFW for context initialization.. Hopefully replaced by some native initialization
using Base.Test

# initilization,  with GLWindow this reduces to "createwindow("name", w,h)"
GLFW.Init()
GLFW.WindowHint(GLFW.SAMPLES, 4)

@osx_only begin
	GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
	GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 3)
	GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE)
	GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)
end
window = GLFW.CreateWindow(512,512, "test")
GLFW.MakeContextCurrent(window)
GLFW.ShowWindow(window)

init_glutils()
function transrot(q::DualQuaternion, p::Point3)
	result = (q*DualQuaternion([p...])*conj(q)).q0
	Vec3(result.v1,result.v2, result.v3) 
end

# Test for creating a GLBuffer with a 1D Julia Array
# You need to supply the cardinality, as it can't be inferred
# indexbuffer is a shortcut for GLBuffer(GLUint[0,1,2,2,3,0], 1, buffertype = GL_ELEMENT_ARRAY_BUFFER)
indexes = indexbuffer(GLuint[0,1,2])
# Test for creating a GLBuffer with a 1D Julia Array of Vectors
#v = Vec2f[Vec2f(0.0, 0.5), Vec2f(0.5, -0.5), Vec2f(-0.5,-0.5)]

v = Point3{Float32}[Point3{Float32}(0.0, 0.5, 0.0), Point3{Float32}(0.5, -0.5, 0.0), Point3{Float32}(-0.5,-0.5, 0.0)]

trans = DualQuaternion(Quaternion(1f0, 0f0, 0f0, 0f0), Vec3(0.1, 0.0, 0))
v = map(x->transrot(trans, x), v)
verts = GLBuffer(v)
# lets define some uniforms
# uniforms are shader variables, which are supposed to stay the same for an entire draw call

const vert = vert"
{{GLSL_VERSION}}

in vec3 vertex;

void main() {
gl_Position = vec4(vertex, 1.0);
}"
const frag = frag"
{{GLSL_VERSION}}
uniform vec4 color;

out vec4 frag_color;

void main() {
	frag_color = color;
}"

function view{T}(position::Point3{T}, xaxis::Vector3{T}, yaxis::Vector3{T}, zaxis::Vector3{T}, xtheta::T, ytheta::T, ztheta::T)
	rot   = qrotation(xtheta, xaxis) * qrotation(ytheta, yaxis) * qrotation(ztheta, zaxis)
	DualQuaternion(rot, -position)
end
 

program = TemplateProgram([frag, vert])
p = program.id

const triangle = RenderObject(
	Dict(
		:vertex => verts,
		:name_doesnt_matter_for_indexes => indexes
	),
	Input(program))

prerender!(triangle, gluniform, GLAbstraction.get_uniform_location(p, "color"), Vec4(0,1,0,1))
postrender!(triangle, render, triangle.vertexarray)

glClearColor(0,0,0,1)
while !GLFW.WindowShouldClose(window)
  	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
	render(triangle)
	GLFW.SwapBuffers(window)
	GLFW.PollEvents()
	sleep(0.01)
end



GLFW.Terminate()
