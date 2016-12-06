# Note: The east-west distance of 2139km is measured at the southern latitude
# the distance is only 1741km at the northern latitude due to the curvature of the earth.
scale = (2139, 2004, 19.8) # Km
longitude = (83, 62) # W
latitude = (23.7, 41.7) # L
height_scale = 50f0

height = (0.035*height_scale, 19.835*height_scale) # Km


variables = Dict(
    "QCLOUD" => (0.00000, 0.00332),
    "QGRAUP" => (0.00000, 0.01638),
    "QICE" => (0.00000, 0.00099),
    "QSNOW" => (0.00000, 0.00135),
    "QVAPOR" => (0.00000, 0.02368),
    "CLOUD" => (0.00000, 0.00332),
    "PRECIP" => (0.00000, 0.01672),
    "P" => (-5471.85791, 3225.42578),
    "TC" => (-83.00402, 31.51576),
    "U" => (-79.47297, 85.17703),
    "V" => (-76.03391, 82.95293),
    "W" => (-9.06026, 28.61434)
)

using GLVisualize, GeometryTypes, Colors, Reactive, GLAbstraction, ModernGL, FileIO
w = glscreen(); #@async GLWindow.waiting_renderloop(w)

dir = dirname(@__FILE__)*"/data/"
t1 = open(deserialize, dir*"QCLOUDf34.jls")
xrange = linspace(-scale[1], scale[1], 251)
yrange = linspace(-scale[2], scale[2], 251)
area = GLVisualize.Grid(
    xrange,
    yrange,
    linspace(height[1], height[2], 51),
)
r = variables["QCLOUD"]
empty!(w)
GLAbstraction.empty_shader_cache!()
img = load(dir*"feathered_brush.jpg").data
soft_particle = map(img) do val
    RGBA{U8}(0,0,0, 1 - gray(val))
end
particles = visualize(
    (RECTANGLE, area),
    image = soft_particle,
    intensity = vec(t1),
    color_norm = Vec2f0(r),
    scale = Vec2f0(20), offset = Vec2f0(-10),
    color_map = [
        RGBA(1f0, 1f0, 1f0, 0.0f0),
        [RGBA(1f0, 1f0, 1f0, a) for a in linspace(0.5f0, 1f0, 20)]...
    ],
    prerender = () -> begin
        glDisable(GL_DEPTH_TEST)
        glDepthMask(GL_TRUE)
        glDisable(GL_CULL_FACE)
        enabletransparency()
    end
)
_view(particles, camera = :perspective)
surf = open(deserialize, dir*"surface.jls")
surf /= 1000f0
surf *= height_scale
maximum(surf)
surfcol = load(dir*"surf.jpg").data
_view(visualize(
    surf, :surface,
    ranges = (xrange, yrange),
    color = surfcol,
    color_map = nothing,
    color_norm = nothing,

))
center!(w)

for i=1:48
    ti = open(deserialize, dir*"QCLOUDf$i.jls")
    set_arg!(particles, :intensity, vec(ti))
    yield()
    sleep(0.05)
end
@async GLWindow.waiting_renderloop(w)
w.color = RGBA(0.85f0, 0.9f0, 1f0, 1f0)
set_arg!(particles, :scale, Vec2f0(30))
