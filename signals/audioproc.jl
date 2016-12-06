include("demo.jl")
using NodeEditor
using GLVisualize, GLWindow, GLAbstraction, Colors, Reactive, GeometryTypes
using PortAudio, SampledSignals, FileIO


function GLVisualize._default{T <: AbstractSampleBuf}(
        buf::Signal{T}, style::Style, data::Dict
    )
    chart = map(buf) do buf
        vec(convert(Matrix{Float32}, buf))
    end
    GLVisualize._default(chart, style, data)
end

screen = get_screen()

microfonstream = PortAudioStream("default", 1, 0)
 # fft size
t = 5.0 # display time range
Fs = samplerate(microfonstream)
N = 1024
gn1 = graphnode(
        every(1/30);
        color_map = colormap("RdBu", 10),
        color_norm = Vec2f0(-0.1, 1)
    ) do x
    read(microfonstream, N)
end


# we'll be plotting the RFFT, which has size N/2+1
data = zeros(div(N, 2)+1, trunc(Int, Fs*t/N))
xrange = linspace(-5, 5, size(data, 1))
yrange = linspace(-5, 5, size(data, 2))
gn2 = graphnode(
        Signal(value(gn1.output));
        style = Style{:surface}(),
        color_norm = Vec2f0(0, 3),
        color_map = colormap("RdBu", 10),
        ranges = (xrange, yrange)
    ) do buff
    data[:, 2:end] = data[:, 1:end-1]
    # read from the stream and add the spectrum
    tmp = rfft(buff)
    tmp .= (/).(log.(abs.(tmp)), -4.0)
    data[:, 1] = tmp
    map(Float32, data)
end

gn3 = graphnode(identity, Signal(value(gn2.output));
    ranges = (xrange, yrange),
    color_norm = GeometryTypes.Vec2f0(0, 3),
    color_map = [Colors.RGBA(1f0, 0f0,0f0,1f0), Colors.RGBA(0.2f0, 1f0,0.4f0,1f0)]
)

import GLVisualize: mm

view_node(gn1, screen, (0, 400, 200, 100))
view_node(gn2, screen, (350, 0))
view_node(gn3, screen, (350, 350))

area = (60mm, 30mm)
gn3 = graphnode(identity, Signal(linspace(10f0, 80f0, 70)); area = area)
view_node(gn3, screen, (20, 20, area...), add_menu = false)

using GLAbstraction
gn4 = graphnode(Signal(0.0); style = :surface) do d
    N = 60
    [begin
        x = ((x/N)-0.5f0)*d
        y = ((y/N)-0.5f0)*d
        r = sqrt(x*x + y*y)
        Float32(sin(r)/r)
    end for x = 1:N, y = 1:N]
end
view_node(gn4, screen, (100, 50))
