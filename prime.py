from timeit import default_timer as timer

from numba import jit
from numpy import arange

# jit decorator tells Numba to compile this function.
# The argument types will be inferred by Numba when function is called.
@jit
def sum2d(arr):
    M, N = arr.shape
    result = 0.0
    for i in range(M):
        for j in range(N):
            result += arr[i,j]
    return result

N = 1000
Z = arange(N*N).reshape(N,N)

a = timer() 
f = sum2d(Z)
b = timer()
print(b-a)

a = timer() 
f = sum2d(Z)
b = timer()
print(b-a)

a = timer() 
f = sum2d(Z)
b = timer()
print(b-a)

a = timer() 
f = sum2d(Z)
b = timer()
print(b-a)

a = timer() 
f = sum2d(Z)
b = timer()
print(b-a)