using FixedSizeArrays

type Vector3{T} <: FixedVector{T, 3}
    x::T
    y::T
    z::T
end

#Base.convert{T}(::Type{Vector6{T}}, array::Array{T, 1}) = pointer_to_array(convert(Ptr{T}, pointer_from_objref(v))+sizeof(T), SIZE)


function test()
    #a = Vector6(1f0,2f0,3f0, 4f0, 5f0, 6f0)
    @show convert(Vector,Vector3{Float32}([1,2,3]))
    @show convert(Vector{Float64}, Vector3([1,2,3]))
    @show convert(Vector, Vector3{Float32}([1,2,3]))

   # @code_native  convert(Array{Float32, 1}, a)
end
test()
