using GLVisualize, PortAudio, SampledSignals, GeometryTypes, Colors, GLAbstraction
# initialize GL display and plot data as a surface
w = glscreen(); @async GLWindow.waiting_renderloop(w)
stream = PortAudioStream(1, 0)
Fs = samplerate(stream)
N = 1024 # fft size
t = 5.0 # display time range

# we'll be plotting the RFFT, which has size N/2+1
data = zeros(div(N, 2)+1, trunc(Int, Fs*t/N))
empty!(w)
surfplot = visualize(
    data, :surface,
    color_norm = Vec2f0(0, 3),
    color_map = colormap("RdBu", 10),
    ranges = ((-5f0, 5f0), (-5f0, 5f0))
)
 _view(surfplot)

function test(data, surfplot)
    for i = 1:100
        # scroll the surface
        gc()
        data[:, 2:end] = view(data, :, 1:size(data,2)-1)
        # read from the stream and add the spectrum
        tmp = rfft(read(stream, N))
        tmp .= (/).(log.(abs.(tmp)), -4.0)
        data[:, 1] = tmp
        set_arg!(surfplot, :position_z, map(Float32, data))
        yield()
    end
end
test(data, surfplot)
