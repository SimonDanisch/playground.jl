using GLVisualize, Colors, Reactive, GLWindow, GeometryTypes, Images, StaticArrays, GLAbstraction
w = glscreen(); @async GLWindow.waiting_renderloop(w)

animate(t, A) = Scalar(t*eye(A) + (1-t)*A)

A = Mat{2}(1, 3, 4, 2) ./ 4
a = eigfact(Array(A))
eigvectors = map(1:size(a.vectors, 1)) do i
    Vec2f0(a.vectors[i, :]...)
end

function handle_drop(files::Vector{String})
    for f in files
        img = load(f)
        if isa(img, Image)
            empty!(w)
            A = Mat{2}(1, 3, 4, 2) ./ 4
            sv, t = GLVisualize.slider(0:0.01:1.0, w)
            _view(sv, camera = :fixed_pixel)
            prim_rect = SimpleRectangle(-250, -250, 500, 500)
            mesh = GLUVMesh(prim_rect)
            prim = map(t) do t
                ps = decompose(Point2f0, prim_rect)
                ps .= (*).(animate(1-t, A), ps)
                mesh.vertices[:] = map(x-> Point3f0(x..., 0), ps)
                mesh
            end
            _view(visualize(img, primitive = prim, boundingbox = nothing))
            cam = w.cameras[:orthographic_pixel]
            dragged_rect = drag_rect(cam, w, GLFW.MOUSE_BUTTON_RIGHT)
            lines = foldp(fill(Point2f0(NaN), 5), dragged_rect, t) do v0, rect, t
                w = widths(rect[2])
                points = Point2f0[
                    minimum(rect[2]),
                    (rect[2].x, rect[2].y + w[2]),
                    maximum(rect[2]),
                    (rect[2].x + w[1], rect[2].y),
                    minimum(rect[2])
                ]
                return (*).(animate(1-t, A), points)
            end
            lw = 4f0
            rect_vis = visualize(
                lines, :lines,
                camera = :fixed_pixel,
                thickness = lw,
                color = RGBA(0.7f0, 0.7f0, 0.7f0, 1.0f0),
            )
            _view(rect_vis)
            a = eigfact(Array(A))
            eigvectors = map(1:size(a.vectors, 1)) do i
                Vec2f0(a.vectors[i, :]...)
            end
            max_value = maximum(a.values)
            vecs = map(dragged_rect, t) do rect, t
                vecs = Point2f0[]
                for (val, vec) in zip(a.values, eigvectors)
                    vec = normalize(vec) * (val / max_value) * 500
                    m = animate(1-t, A).data
                    start = Vec2f0(0)
                    start = m * start
                    push!(vecs,
                        start,
                        start + vec,
                    )
                end
                vecs
            end
            _view(visualize(
                vecs, :linesegment,
                thickness = lw,
                color = RGBA(0.90f0, 0.90f0, 1f0, 1.0f0),
            ), camera = :orthographic_pixel)
        end
    end
end
preserve(map(handle_drop, w.inputs[:dropped_files]))



# it's time to have these defined in GeometryTypes
function Rect(x, y, w, h)
    SimpleRectangle(round(Int, x), round(Int, y), round(Int, w), round(Int, h))
end
function Rect(xy::StaticVector, w, h)
    Rect(xy[1], xy[2], w, h)
end
function Rect(x, y, wh::StaticVector)
    Rect(x, y, wh[1], wh[2])
end
function Rect(xy::StaticVector, wh::StaticVector)
    Rect(xy[1], xy[2], wh[1], wh[2])
end
import GLAbstraction: imagespace

function drag_rect(cam, screen, key = GLFW.MOUSE_BUTTON_LEFT)
    @materialize mouseposition, mouse_buttons_pressed = screen.inputs
    @materialize mouse_button_down, mouse_button_released = screen.inputs

    is_dragging = false
    rect = Rect(0,0,0,0)
    dragged_rect = foldp(
            (is_dragging, rect),
            mouse_buttons_pressed, mouseposition
        ) do v0, m_pressed, m_pos
        was_dragging, rect = v0
        keypressed = (length(m_pressed) == 1) && (key in m_pressed)
        p = imagespace(m_pos, cam)
        if was_dragging
            wh = p - minimum(rect)
            rect = Rect(minimum(rect), wh)
            if keypressed # was dragging and still dragging
                return true, rect
            else
                return false, rect # anything else will stop the dragging
            end
        elseif keypressed # was not dragging, but now key is pressed
            return true, Rect(p, 0, 0)
        end
        return v0
    end
    dragged_rect
end
