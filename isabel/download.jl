using Images
import GZip

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
dir = dirname(@__FILE__)
url = "http://www.vets.ucar.edu/vg/isabeldata/"
# download

files = Any[]
for (k, r) in variables
    for i = 1:48
        n = @sprintf("f%02d.bin.gz", i)
        push!(files, (url*"$(k)"*n, joinpath(dir, "data", "$(k)f$i.bin.gz"), r))
    end
end
@everywhere inrange(v, range) = v <= range[1] || v >= range[2]
@everywhere function preprocess(vol, r)
    @inbounds for z = 1:100, y = 1:500, x = 1:500
        v = ntoh(vol[x, y, z]) # convert from big endian
        if v == 1.0f35 # replace nans by surrounding values
            sum = 0f0; vals = 0
            for i = -1:1, j = -1:1, k = -1:1
                _i = clamp(z + i, 1, 100)
                _j = clamp(y + i, 1, 500)
                _k = clamp(x + i, 1, 500)
                val = vol[_k, _j, _i]
                if inrange(val, r) # only sum if in range
                    sum += val; vals += 1
                end
            end
            v = if vals == 0
                0f0 # damn,nothing in range?!
            else
                sum / vals
            end
        end
        vol[x, y, z] = clamp(v, r[1], r[2])
    end
    vol
    Images.restrict(vol)
end
@everywhere function loadandprocess(url_file_range)
    url, file, range = url_file_range
    if !isfile(file)
        download(url, file)
    end
    f, ext = splitext(file) # remove .gz
    f, ext = splitext(f) # remove .bin
    if !isfile(f*".jls")
        vol = read(GZip.open(file), Float32, (500, 500, 100))
        preproc = preprocess(vol, range)
        open(f*".jls", "w") do io
            serialize(io, preproc)
        end
    end
    nothing
end
pmap(loadandprocess, files)
