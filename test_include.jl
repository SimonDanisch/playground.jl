module Test
immutable V3{T}
	x::T
	y::T
	z::T
end
export V3
end

using Test, includthis
@show create(V3(1,2,3))