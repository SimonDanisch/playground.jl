using GLVisualize, Colors, Reactive, GLWindow, GeometryTypes
using Images, StaticArrays, GLAbstraction, Iterators
import GeometryTypes: intersects
w = glscreen(); @async GLWindow.waiting_renderloop(w)
animate(t, A) = t*eye(A) + (1-t)*A
animate(t, A) = Scalar(t*eye(A) + (1-t)*A)
img = loadasset("racoon.png")
A = Mat{2}(1, 3, 4, 2) ./ 4
sv, t = GLVisualize.slider(0:0.01:1.0, w)
_view(sv, camera = :fixed_pixel)
prim_rect = SimpleRectangle(-250, -250, 500, 500)
mesh = GLUVMesh(prim_rect)
prim = map(t) do t
    points = decompose(Point2f0, prim_rect)
    points .= (*).(animate(1-t, A), points)
    mesh.vertices[:] = map(x-> Point3f0(x[1], x[2], 0), points)
    mesh
end
_view(visualize(img, fxaa = true, primitive = prim, boundingbox = nothing))

a = eigfact(Array(A))
eigvectors = map(1:size(a.vectors, 1)) do i
    normalize(Vec2f0(a.vectors[i, :]...))
end
v1 = eigvectors[1] * 1000f0
v2 = eigvectors[2] * 1000f0
origin = Point2f0(0)
lines = Point2f0[]

function vec_angle(origin, a, b)
    diff0 = a - origin
    diff1 = b - origin
    d = dot(diff0, diff1)
    det = cross(diff0, diff1)
    atan2(det, d)
end
function sort_rectangle!(points)
    middle = mean(points)
    p1 = first(points)
    sort!(points, by = p-> vec_angle(middle, p, p1))
end
eigvectpoly = map(prim) do prim
    # bring vertices in correct order and close rectangle
    points = sort_rectangle!(map(Point2f0, vertices(prim)))
    push!(points, points[1]) # close points
    eigseg1 = LineSegment(origin, Point2f0(v1))
    eigseg2 = LineSegment(origin, Point2f0(v2))
    seg1cut = seg2cut = (0, origin)
    for (i, (a, b)) in enumerate(partition(points, 2, 1))
        seg = LineSegment(a,b)
        intersected, p = intersects(eigseg1, seg)
        intersected && (seg1cut = (i, p))
        intersected, p = intersects(eigseg2, seg)
        intersected && (seg2cut = (i, p))
    end
    pop!(points) #remove closing point
    cutout = Point2f0[seg2cut[2], origin, seg1cut[2]]
    i1, i2 = seg1cut[1], seg2cut[1]
    imin, imax = min(i1, i2), max(i1, i2)
    i = if imax - imin <= 1
        (imin:(imax-imin)) + 1
    else
        1:(imin + 4 - imax)
    end
    splice!(points, i, cutout)
    GLPlainMesh(points), Point2f0[seg2cut[2], origin, seg1cut[2]]
end
_view(visualize(
    map(first, eigvectpoly),
    color = RGBA(1f0, 1f0, 1f0, 0.6f0),
), camera = :orthographic_pixel)

_view(visualize(
    map(last, eigvectpoly), :linesegment,
    indices = [2, 1, 2, 3],
    thickness = 3f0,
    color = RGBA(0.60, 0.3f0, 0.4f0, 1f0),
), camera = :orthographic_pixel)

_view(visualize(
    (Circle(Point2f0(0), 5f0), map(x-> map(Point2f0, vertices(x)), prim)),
    color = RGBA(0.7f0, 0.2f0, 0.9f0, 1f0),
), camera = :orthographic_pixel)
