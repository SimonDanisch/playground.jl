abstract Parent
 
immutable ChildA <: Parent
end
 
immutable ChildB <: Parent
end
 
increment(c::ChildA, x) = x + 1
increment(c::ChildB, x) = x + 2
 
immutable Container{T <: Parent}
    p::T
end
 
increment(c::Container, x) = increment(c.p, x)
 
function run(n)
    sum = 0
    container = Container(ChildA())
    for i in 1:n
        sum = increment(container, sum)
    end
    container = Container(ChildB())
    for i in 1:n
        sum = increment(container, sum)
    end
    @show sum
end
 #elapsed time: 0.002140284 seconds (17 kB allocated)
run(10)
 
@time run(10000000)