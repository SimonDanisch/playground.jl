using ModernGL, GLAbstraction, GLWindow, GLFW
println("befor123")

window = createwindow("test", 500, 500)
println("befor11")

vsh = "
{{GLSL_VERSION}}
in vec2 vertex;
void main() {
gl_Position = vec4(vertex, 0.0, 1.0);
}
"

fsh = "
{{GLSL_VERSION}}
out vec4 frag_color;
void main() {
frag_color = vec4(1.0, 0.0, 1.0, 1.0);
}
"
println("befor1")

# Test for creating a GLBuffer with a 1D Julia Array
# You need to supply the cardinality, as it can't be inferred
# indexbuffer is a shortcut for GLBuffer(GLUint[0,1,2,2,3,0], 1, buffertype = GL_ELEMENT_ARRAY_BUFFER)
indexes = indexbuffer(GLuint[0,1,2])
println("befor12")

# Test for creating a GLBuffer with a 1D Julia Array of Vectors
#v = Vec2f[Vec2f(0.0, 0.5), Vec2f(0.5, -0.5), Vec2f(-0.5,-0.5)]

v = Float32[0.0, 0.5, 0.5, -0.5, -0.5,-0.5]
println("befor13")

verts = GLBuffer(v, 2)
println("befor14")

# lets define some uniforms
# uniforms are shader variables, which are supposed to stay the same for an entire draw call
println("befor2")

data = Dict(
:vertex => verts,
:name_doesnt_matter_for_indexes => indexes
)
println("befor")
program = TemplateProgram(vsh, fsh, "vertex", "fragment")
println("after")

const triangle = RenderObject(data, program)

postrender!(triangle, render, triangle.vertexarray)

while window.inputs[:open].value
	render(triangle)
	GLFW.SwapBuffers(window.nativewindow)
	GLFW.PollEvents()
end