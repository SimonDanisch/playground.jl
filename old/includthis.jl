module includthis
stagedfunction create{T}(x::T)
	@show x
	:(T(1,2,3))
end
export create
end