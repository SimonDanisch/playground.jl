using Reactive


function alter(A, j)
	for i=1:length(A)
		A[i] = sin(A[i]*j)
	end
	A
end

function test(n)
	A = Input(ones(n,n))
	I = Input(0.0) 
	s_ = lift(alter, A, I)
	s__= lift(alter, s_, I)
	s___= lift(alter, s__, I)
	s___= lift(alter, s___, I)
	for i=0.0:0.01:10
		push!(I, i)
	end
end
function test2(n)
	A 	= ones(n,n)
	for i=0.0:0.01:10
		alter(A, i)
		alter(A, i)
		alter(A, i)
		alter(A, i)
	end
end

@time test(1)
@time test(500)
@time test2(1)
@time test2(500)
#elapsed time: 0.420320291 seconds (16 MB allocated, 3.46% gc time in 1 pauses with 0 full sweep)
#elapsed time: 11.112971423 seconds (3812 MB allocated, 1.03% gc time in 175 pauses with 0 full sweep)
#elapsed time: 11.671333387 seconds (3817 MB allocated, 1.14% gc time in 174 pauses with 0 full sweep)