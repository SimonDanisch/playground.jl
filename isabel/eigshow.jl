
using GLVisualize, Colors, Reactive, GLWindow, GeometryTypes
w = glscreen(); @async GLWindow.waiting_renderloop(w)
A = [1 3; 4 2] / 4

blue = RGBA(0., 0., 9., 0.4)
red = RGBA(9., 0., 0.)

place(point) = ((Point2f0(point) .+ 1) ./ 4 .+ .25) * 1000

function drawpoints(points, c)
    [place(points[:, i]) for i = 1:size(points, 2)]
end

sv, ss = GLVisualize.slider(0:.01:2π, w)
_view(sv, camera = :fixed_pixel)

xs = Float64[0.1]
points = foldp((Point2f0[0], [red]), ss) do v0, val
    push!(xs, val)
    _xs = [cos(xs) sin(xs)]'
    Axs = A*_xs
    points = [drawpoints(_xs, blue); drawpoints(Axs, red)]
    colors = [fill(blue, size(_xs, 2)); fill(red, size(Axs, 2))]
    points, colors
end
_view(visualize(
    (Circle(Point2f0(0), 4f0), map(first, points)),
    color = map(last, points)
))
using GLAbstraction
center!(w, :orthographic_pixel)
