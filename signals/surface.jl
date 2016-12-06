if length(workers()) == 1
    addprocs(1)
end

using GLVisualize, PortAudio, SampledSignals, GeometryTypes, Colors, GLAbstraction
using GLVisualize.GLParallel
# initialize GL display and plot data as a surface
w = GLParallel.glscreen()
wait(w) # make sure screen is created
stream = PortAudioStream("default", 1, 0)
Fs = samplerate(stream)
N = 1024 # fft size
t = 5.0 # display time range

# we'll be plotting the RFFT, which has size N/2+1
data = zeros(div(N, 2)+1, trunc(Int, Fs*t/N))

surfplot = GLParallel._view(
    data, :surface,
    color_norm = Vec2f0(0, 3),
    color_map = colormap("RdBu", 10),
    ranges = ((-5f0, 5f0), (-5f0, 5f0))
)

function test(data, surfplot, stream)
    while GLParallel.is_current_open()
        # scroll the surface
        gc()
        data[:, 2:end] = data[:, 1:end-1]
        # read from the stream and add the spectrum
        tmp = rfft(read(stream, N))
        tmp .= (/).(log.(abs.(tmp)), -4.0)
        data[:, 1] = tmp
        GLParallel.set_arg!(surfplot, :position_z, map(Float32, data))
    end
end

test(data, surfplot, stream)
