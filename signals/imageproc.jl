include("demo.jl")
using NodeEditor
using GLVisualize, GLWindow, GLAbstraction, Colors, Reactive, GeometryTypes
using FileIO, Images

import GLVisualize: mm

screen = get_screen()
area = (60mm, 30mm)
gn3 = graphnode(identity, Signal(linspace(1f0, 50f0, 70)); area = area)
view_node(gn3, screen, (20, 20, area...), add_menu = false)


gn4 = graphnode(Signal(map(RGB{U8}, loadasset("racoon.png"))), Signal(1.0f0)) do img, sigma
    imfilter_gaussian(img, [sigma, sigma])
end
s = view_node(gn4, screen, (100, 50, 100, 100))

gn5 = graphnode(Signal(map(RGB{U8}, loadasset("racoon.png")))) do img
    map(RGB{U8}, restrict(img))
end
s = view_node(gn5, screen, (500, 50, 100, 100))

gn6 = graphnode(Signal(map(RGB{Float64}, loadasset("racoon.png"))); style = :surface) do img
    map(img) do color
        Float32(Gray(color))
    end.data
end
s = view_node(gn6, screen, (500, 50, 100, 100))
