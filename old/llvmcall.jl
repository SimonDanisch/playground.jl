immutable Matrix4x4
	i_1::Float64
	i_2::Float64
	i_3::Float64
	i_4::Float64
	i_5::Float64
	i_6::Float64
	i_7::Float64
	i_8::Float64
	i_9::Float64
	i_10::Float64
	i_11::Float64
	i_12::Float64
	i_13::Float64
	i_14::Float64
	i_15::Float64
	i_16::Float64
end

function mulllvm(a::Matrix4x4, b::Matrix4x4)
    Base.llvmcall("""
    	%ptr = getelementptr <4 double>, %Matrix4x4* %0, i64 0, i64 0
      	%3 = load <4 x double>, <4 double>* %ptr
      	ret <4 x double> %3
      	""", NTuple{4, Float64},
      	(Matrix4x4, Matrix4x4),
    	a,b)
end
const x = Matrix4x4(rand(16)...)
println(mulllvm(x,x)) 
#=

function add1234(a::NTuple{4, Float64}, b::NTuple{4, Float64})
    Base.llvmcall("""
      %3 = fadd <4 x double> %1, %0
      ret <4 x double> %3
      """,NTuple{4,Float64},
      (NTuple{4,Float64},NTuple{4,Float64}),
        a,b)
end
function mul1234(a::NTuple{4, Float64}, b::NTuple{4, Float64})
    Base.llvmcall("""
      %3 = fmul <4 x double> %1, %0
      ret <4 x double> %3
      """,NTuple{4,Float64},
      (NTuple{4,Float64},NTuple{4,Float64}),
        a,b)
end
=#