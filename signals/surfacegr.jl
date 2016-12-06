using PortAudio, SampledSignals
using GR

stream = PortAudioStream(1, 0)
Fs = samplerate(stream)
N = 1024 # fft size
t = 5.0 # display time range

# we'll be plotting the RFFT, which has size N/2+1
data = zeros(Float32, 200, trunc(Int, Fs*t/N))
# datasig = Signal(data)

while true
    # scroll the surface
    data[:, 2:end] = data[:, 1:end-1]
    # read from the stream and add the spectrum
    data[:, 1] = rfft(read(stream, N))[1:200] |> abs |> log
    surface(data)
end
