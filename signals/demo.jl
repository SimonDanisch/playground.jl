module NodeEditor

using GLVisualize, GLWindow, GLAbstraction, Colors, Reactive, GeometryTypes
using FileIO, GLFW
import GLVisualize: mm

include(GLVisualize.dir("examples", "texthighlight.jl"))

type GraphNode
    inputs::Dict{Symbol, Signal}
    output
    func::Function
    source::String
    attributes::Dict{Symbol, Any}
    style::Style
end


function get_method(f, types)
    if !all(isleaftype, types)
        error("Not all types are concrete: $types")
    end
    precompile(f, types) # make sure there is a specialization
    x = methods(f, types)
    if length(x) != 1
        error("
            More than one method found for signature $f $types.
            Please use more specific types!
        ")
    end
    first(x)
end


function macro_form(f, types)
    m = get_method(f, types)
    file = string(m.file)
    if !isfile(file)
        file = joinpath(JULIA_HOME, "..", "..", "base", file)
        if !isfile(file)
            error("No idea where $file is supposed to be")
        end
    end
    linestart = m.line
    code, str = open(file) do io
        line = ""
        for i=1:linestart-1
            line = readline(io)
        end
        try # lines can be one off, which will result in a parse error
            parse(line)
        catch e
            line = readline(io)
        end
        while !eof(io)
            line = line*readline(io)
            e = Base.parse_input_line(line; filename=file)
            if !(isa(e,Expr) && e.head === :incomplete)
                return e, line
            end
        end
    end
    code, str
end

function graphnode(f, args...; kw_args...)
    result = map(f, args...)

    types = map(x-> typeof(value(x)), args)
    expr, str = macro_form(f, types)
    f_lambda = code_lowered(f, types)[]
    argnames = f_lambda.slotnames[2:f_lambda.nargs]

    source = str
    kw_args = Dict{Symbol, Any}(kw_args)
    style = get(kw_args, :style, :default)
    delete!(kw_args, :style)
    inputs = Dict(zip(argnames, args))
    GraphNode(
        inputs,
        result,
        f,
        source,
        kw_args,
        Style{style}(),
    )
end

const nodes = Tuple{Range{Int}, GraphNode}[] # graph nodes corresponding to ranges in the slots
const slot_names = Symbol[]
const slot_connected_s = Signal(Bool[])
const slot_positions_s = Signal(Point2f0[])
const slot_offsets_s = Signal(Vec2f0[])
const slot_connections_s = Signal(Int[])

const not_connect_char = '◌'
const connected_char = '●'

function get_key(idx)
    checkbounds(Bool, slot_names, idx) || return Symbol("")
    slot_names[idx]
end

function get_node(idx)
    for (r, node) in nodes
        if idx in r
            return node
        end
    end
    return nothing
end
function get_signal(idx)
    key = get_key(idx)
    node = get_node(idx)
    if key == :output
        node.output
    else
        node.inputs[key]
    end
end

function add_node(node, names::Vector, positions::Vector)
    len = length(names)
    start = length(slot_names) + 1
    push!(slot_connected_s, append!(value(slot_connected_s), repeated(false, len)))
    push!(slot_positions_s, append!(value(slot_positions_s), positions))
    offsets = fill(Vec2f0(0, -2.5mm), len)
    offsets[end] = Vec2f0(-4mm, -2.5mm) # output gets different offset
    push!(slot_offsets_s, append!(value(slot_offsets_s), offsets))
    append!(slot_names, names)
    insertion_range = start:length(slot_names)
    push!(nodes, (insertion_range, node))
    insertion_range
end


function update_nodepos!(rect, nodes, node_range)
    slot_positions = value(slot_positions_s)
    for (i, j) in enumerate(node_range)
        p = Point2f0(minimum(rect)) + nodes[i] # move with window
        # we got the output node, we need to move it to the other side
        if j == last(node_range)
            w = widths(rect)
            p += Point2f0(w[1], w[2]/2)
        end
        slot_positions[j] = p
    end
    push!(slot_positions_s, slot_positions) # update nodepos signal
end

function view_node(
        gn, window, startpos = (50, 50);
        io_width = 10mm,
        icon_size = 5mm,
        gap = 2mm,
        text_size = 3mm,
        menu_height = 6mm,
        add_menu = true
    )

    node_positions = Point2f0[]; slotnames = Symbol[]
    pos = Point2f0(0, icon_size)
    offset = Point2f0(-icon_size, 0) # offset
    for (k, v) in gn.inputs
        push!(node_positions, pos + offset)
        push!(slotnames, k)
        pos += Point2f0(gap, icon_size + gap)
    end
    # add output node
    push!(node_positions, -offset)
    push!(slotnames, :output)

    node_range = add_node(gn, slotnames, node_positions)
    slot_positions = value(slot_positions_s)

    mousestart = Vec2f0(0), Vec2f0(0)
    drag_started = false; resizing = false; showing_resize = false;
    panning = false; waspressed = false

    mpressed = window.inputs[:mouse_buttons_pressed]
    startrect = if length(startpos) == 4
        SimpleRectangle(startpos...)
    else
        SimpleRectangle(startpos..., 300, 300)
    end
    update_nodepos!(startrect, node_positions, node_range)
    area = foldp(startrect, window.inputs[:mouseposition]) do rect, mp
        menu_area = SimpleRectangle(
            rect.x, rect.y + rect.h - menu_height,
            rect.w, menu_height
        )
        d = 2mm
        rect_edges = (
            Vec2f0(minimum(rect)),
            Vec2f0(rect.x, rect.y + rect.h),
            Vec2f0(maximum(rect)),
            Vec2f0(rect.x + rect.w, rect.y),
        )
        in_menu = isinside(menu_area, mp[1], mp[2])
        in_resize = false; edge = Vec2f0(0); i = 0
        for (i, edge) in enumerate(rect_edges)
            dist = norm(Vec2f0(mp) - edge)
            if dist <= 2mm
                in_resize = true; break
            end
        end
        if !isempty(value(mpressed))
            if !waspressed && (in_menu || in_resize)
                pos = in_resize ? rect : Vec2f0(minimum(rect))
                mousestart = Vec2f0(mp), pos, i
                resizing = in_resize; panning = in_menu
            elseif waspressed && (resizing || panning)
                diff = Vec2f0(mp) - mousestart[1]
                rect = if resizing
                    md = round(Int, diff)
                    r0 = mousestart[2]
                    rect = if mousestart[3] == 1
                        x0, y0 = maximum(r0)
                        x, y = r0.x + md[1], r0.y + md[2]
                        w, h = max(x0 - x, 3mm), max(y0 - y, 3mm)
                        x, y = x0 - w, y0 - h
                        SimpleRectangle(x, y, w, h)
                    elseif mousestart[3] == 2
                        x = max(r0.x + md[1], 3mm)
                        h = max(r0.h + md[2], 3mm)
                        w = r0.w + r0.x - x
                        SimpleRectangle(x, rect.y, w, h)
                    elseif mousestart[3] == 3
                        w, h = max(r0.w + md[1], 3mm), max(r0.h + md[2], 3mm)
                        SimpleRectangle(r0.x, r0.y, w, h)
                    elseif mousestart[3] == 4
                        x0, y0 = maximum(r0)
                        w = max(r0.w + md[1], 3mm)
                        y = r0.y + md[2]
                        h = max(y0 - y, 3mm)
                        y = y0 - h
                        SimpleRectangle(r0.x, y, w, h)
                    else
                        error("wrong corner, jeez!")
                    end
                    show_resize(edge, i)
                    showing_resize = true
                    rect
                elseif panning
                    xy = round(Int, mousestart[2] + diff)
                    SimpleRectangle(xy[1], xy[2], rect.w, rect.h)
                else
                    rect
                end
            else
                waspressed = true
                return rect # nothing to be done
            end
            waspressed = true
            # if we're here, the rect has changed, so we need to update node positions
            update_nodepos!(rect, node_positions, node_range)
        else
            if in_resize
                show_resize(edge, i); showing_resize = true
            elseif showing_resize
                hide_resize()
                showing_resize = false
            end
            resizing = false; panning = false; waspressed = false
        end
        rect
    end

    screen = Screen(
        window, area = area,
        stroke = (2f0, RGBA(0f0, 0f0, 0f0, 1f0))
    )
    color = RGBA(0.95f0, 0.95f0, 0.95f0, 1f0)

    menu = Screen(
        screen,
        area = map(a-> SimpleRectangle(0, a.h-menu_height, a.w, menu_height), area),
        color = color,
        stroke = (2f0, RGBA(0f0, 0f0, 0f0, 1f0))
    )
    viewarea = map(a-> SimpleRectangle(0, 0, a.w, a.h-menu_height), area)
    view_hide = if add_menu
        code_toggle, code_s = widget(
            Signal(["code", "visual"]), menu,
            color = RGBA(0f0, 0f0, 0f0, 1f0),
            area = (6*text_size, menu_height),
            relative_scale = text_size
        )
        view_hide = map(sym-> sym == "visual", code_s)
        code_hide = map(sym-> sym == "code", code_s)
        code_screen = Screen(screen, area = viewarea, hidden = code_hide)
        code, colors = highlight_text(gn.source)
        code_obj = visualize(
            code, color = colors,
            relative_scale = 4mm
        ).children[]
        _view(code_obj, code_screen, camera = :orthographic_pixel)
        _view(code_toggle, menu, camera = :fixed_pixel)
        center!(code_screen, :orthographic_pixel)
        view_hide
    else
        Signal(false)
    end

    view_screen = Screen(screen, area = viewarea, hidden = view_hide)
    cam = if applicable(widget, gn.output, view_screen)
        obj, s = widget(gn.output, view_screen)
        gn.output = s # sometimes in != out for widgets :(
        _view(obj, view_screen)
        obj.children[1][:preferred_camera]
    else
        obj = visualize(gn.output, gn.style, gn.attributes)
        _view(obj, view_screen)
        obj.children[1][:preferred_camera]
    end

    center!(view_screen, cam)
    screen
end

function center_nocode!(screen, cam, code_obj)
    camera = screen.cameras[cam]
    rlist = GLAbstraction.robj_from_camera(screen, cam)
    filter!(x-> x != code_obj, rlist)
    bb = GLAbstraction.renderlist_boundingbox(rlist)
    w = widths(bb)
    border = w * 0.1 # 10% border
    bb = AABB(minimum(bb) .- border, w .+ 2border)
    center!(camera, bb)
end

function connect_sigs(a, b)
    push!(a, b)
end

"""
Removes all connections from `node_idx`
"""
function remove_all_connections(node_idx)
    slot_connected = value(slot_connected_s)
    slot_connected[node_idx] = false

    slot_connections = value(slot_connections_s)
    signal = get_signal(node_idx)
    to_delete = Int[]; other = isodd(node_idx) ? 2 : 1 # signal connections are always inserted as pairs
    for i = 1:2:length(slot_connections)
        ab = slot_connections[i], slot_connections[i + 1]
        if node_idx in ab
            push!(to_delete, i, i + 1)
            other_idx = ab[other]
            other_s = get_signal(other_idx)
            signals = other_s, signal
            output, input = isodd(other) ? signals : reverse(signals)
            filter!(output.actions) do a
                a.recipient.value != input
            end
            if length(other_s.actions) == 1 # there is always one action left
                slot_connected[other_idx] = false
            end
        end
    end
    deleteat!(slot_connections, to_delete)
    push!(slot_connections_s, slot_connections) # update signal
    push!(slot_connected_s, slot_connected)
end

function connection_mapper(screen)
    mousepos_s = screen.inputs[:mouseposition]
    # add mouse pos as one position to make dragging connections easy
    slot_positions = value(slot_positions_s)
    # should be empty. Assert because otherwise it will mess with mouse node
    @assert length(slot_positions) == 0
    push!(slot_positions_s, push!(slot_positions, value(mousepos_s)))
    push!(slot_offsets_s, push!(value(slot_offsets_s), Vec2f0(0)))
    push!(slot_connected_s, push!(value(slot_connected_s), false))
    push!(slot_names, :mouse)

    node_string = map(slot_connected_s) do is_connected
        join(map(is_connected) do is_connected
            is_connected ? connected_char : not_connect_char
        end, "")
    end
    node_vis = visualize(
        node_string,
        position = slot_positions_s,
        offset = slot_offsets_s,
        relative_scale = 5mm,
        color = RGBA(0f0, 0f0, 0f0, 1f0),
        indices = map(x-> [2:length(x)], slot_positions_s) # never show mouse
    ).children[]

    connection_vis = visualize(
        node_vis[:position], # share the gpu object
        :linesegment,
        thickness = 2f0,
        color = RGBA(0.6f0, 0.6f0, 0.6f0, 1f0),
        indices = slot_connections_s
    )
    _view(node_vis, screen, camera = :fixed_pixel)
    _view(connection_vis, screen, camera = :fixed_pixel)

    m2id_s = mouse2id(screen) # get mouse to id signal
    drag_started = false
    mpressed = screen.inputs[:mouse_buttons_pressed]
    s1 = Signal(0); s2 = Signal(0)
    slot_connections = value(slot_connections_s)
    slot_connected = value(slot_connected_s)
    preserve(map(mpressed) do mpressed_v
        id, idx = value(m2id_s)
        # if clicked on a node
        if id == node_vis.id && !isempty(mpressed_v) && first(mpressed_v) == GLFW.MOUSE_BUTTON_RIGHT
            remove_all_connections(idx)
        end
        nothing
    end)
    mouse_node = map(mousepos_s) do mp
        id, idx = value(m2id_s)
        mpressed_v = value(mpressed)
        if length(mpressed_v) == 1 # if clicked
            leftclicked = first(mpressed_v) == GLFW.MOUSE_BUTTON_LEFT
            if id == node_vis.id # if clicked on a node
                if !drag_started && leftclicked# drag hasn't started
                    key = get_key(idx)
                    node = get_node(idx)
                    # no node, or no input found
                    if !(node != nothing && key == :output)
                        println("no node or no output node? Node key: $key")
                        return mp
                    end
                    s1 = node.output
                    # now that we start draggin, we first connect the input to mouse node
                    # one should be guaranteed to be the mouse
                    push!(slot_connections_s, push!(slot_connections, idx, 1))
                    drag_started = true
                end
            end
            if drag_started && leftclicked # drag_started && ispressed --> dragging
                # if we're here, the mouse is in hovering connection mode and needs updates
                slot_positions[1] = (mp - 1f0) # minus one so it isn't directly under mouse
                push!(slot_positions_s, slot_positions) # update signal
            end
        else
            if drag_started
                if id == node_vis.id # we just stopped dragging and ended on another node
                    key = get_key(idx)
                    node = get_node(idx)
                    if !(
                            node != nothing && haskey(node.inputs, key) &&
                            typeof(node.inputs[key]) == typeof(s1)
                        )
                        if !isempty(slot_connections)
                            resize!(slot_connections, length(slot_connections) - 2)
                            push!(slot_connections_s, slot_connections)
                        else
                            warning("slot_connections are empty, but want to remove")
                        end
                        drag_started = false
                        return mp
                    end
                    # okay, so now we have to signals we need to connect!
                    # we can rewire now from the mouse node to the real node!
                    slot_connections[end] = idx
                    push!(slot_connections_s, slot_connections) # update!
                    idxa, idxb = slot_connections[end-1], idx
                    slot_connected[idxa] = true
                    slot_connected[idxb] = true
                    push!(slot_connections_s, slot_connections) # update!
                    push!(slot_connected_s, slot_connected) # update!
                    # now connect the signals for realz!
                    Reactive.connect_map(identity, node.inputs[key], s1)
                    push!(s1, value(s1)) # update
                else # dragg stopped without being over any node. reset connection!!
                    if !isempty(slot_connections)
                        resize!(slot_connections, length(slot_connections) - 2)
                        push!(slot_connections_s, slot_connections)
                    else
                        warning("slot_connections are empty, but want to remove")
                    end
                end
            end
            # mouse not pressed anymore, dragging stops
            drag_started = false
        end
        mp
    end
    preserve(mouse_node)
    node_vis
end


function hide_resize()
    set_arg!(screen_resize_edge, :visible, false)
end
function show_resize(_edge, edge_idx)
    gap = 1mm; len = 2mm
    edge = Point2f0(_edge)
    dir = if edge_idx == 1
        Point2f0(gap)
    elseif edge_idx == 2
        Point2f0(gap, -gap)
    elseif edge_idx == 3
        Point2f0(-gap)
    elseif edge_idx == 4
        Point2f0(-gap, gap)
    else
        error("wrong corner, jeez!")
    end
    xpart, ypart = Point2f0(dir[1]*4, 0), Point2f0(0, dir[2]*4)
    moved = edge - dir
    edges = [moved + xpart, moved, moved, moved + ypart]
    set_arg!(screen_resize_edge, :vertex, edges)
    set_arg!(screen_resize_edge, :visible, true)
    nothing
end


function handle_drop(files::Vector{String})
    for f in files
        try
            obj = load(f)
            if applicable(visualize, obj)
                screen = get_screen()
                gn = graphnode(identity, Signal(obj))
                mp = value(screen.inputs[:mouseposition])
                view_node(gn, screen, (round(Int, mp)..., 200, 200))
            end
        catch e
            warn(e)
        end
    end
end

const screen_ref = Ref{Screen}()
get_screen() = screen_ref[]

function arglabel_hover(noderobj, screen)
    mh = GLWindow.mouse2id(screen)
    text_scale = 4mm
    not_over_node = droprepeats(map(mh, init = false) do mh
        id, idx = mh
        id != noderobj.id || get_key(idx) == :output
    end)

    label = map(not_over_node, init = "no label") do non
        if !non
            id, idx = value(mh)
            string(get_key(idx))
        else
            "no label"
        end
    end
    area = map(screen.inputs[:mouseposition], label) do mp, label
        len = length(label) + 2
        w = text_scale * len
        SimpleRectangle{Int}(
            round(Int, mp + Vec2f0(-w+1mm, 2mm, ))...,
            w, text_scale + 2mm
        )
    end

    popup = GLWindow.Screen(
        screen,
        hidden = not_over_node,
        area = area,
        stroke = (2f0, RGBA(0f0, 0f0, 0f0, 0.8f0))
    )

    robj = visualize(
        label,
        relative_scale = text_scale,
        model = translationmatrix(Vec3f0(text_scale, 1mm, 0))
    )
    _view(robj, popup, camera = :fixed_pixel)
    nothing
end

function __init__()
    screen = glscreen(); @async GLWindow.waiting_renderloop(screen)
    screen_ref[] = screen
    # jeez, could I not use globals for once?
    global const screen_resize_edge = visualize(
        zeros(Point2f0, 3), :linesegment,
        color = RGBA(0f0, 0f0, 0f0, 0.4f0),
        thickness = 2f0,
        visible = false
    ).children[]

    _view(screen_resize_edge, screen, camera = :fixed_pixel)

    node_vis = connection_mapper(screen)
    arglabel_hover(node_vis, screen)

    s = map(handle_drop, screen.inputs[:dropped_files])

    preserve(s)
end

export graphnode, view_node, get_screen

end
