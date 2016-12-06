#=

using Meshes

N1 = 10
N = 400
const volume1  = Float32[sin(x/15f0)+sin(y/15f0)+sin(z/15f0) for x=1:N1, y=1:N1, z=1:N1]
const volume2  = Float32[sin(x/15f0)+sin(y/15f0)+sin(z/15f0) for x=1:N, y=1:N, z=1:N]

@time isosurface(volume1, 0.5f0, 0.001f0)
@time isosurface(volume2, 0.5f0, 0.001f0)
=#
using JFinEALE, ImmutableArrays
# JFFoundationModule
# using FESetModule
# using MeshHexahedronModule
# using MeshSelectionModule
# using MeshModificationModule
# using MeshExportModule
# using NodalFieldModule
# using IntegRuleModule
# using PropertyAcousticFluidModule
# using MaterialAcousticFluidModule
# using FEMMBaseModule
# using FEMMAcousticsModule
# using ForceIntensityModule
# using PhysicalUnitModule
# phun=PhysicalUnitModule.phun


rho=1.21*phun("kg/m^3");# mass density
c =343.0*phun("m/s");# sound speed
bulk= c^2*rho;
omega= 7500*phun("rev/s");      # frequency of the piston
a_piston= -1.0*phun("mm/s")     # amplitude of the piston acceleration
R=50.0*phun("mm");# radius of the piston
Ro=150.0*phun("mm"); # radius of the enclosure
nref=4;#number of refinements of the sphere around the piston
nlayers=18;                     # number of layers of elements surrounding the piston
tolerance=R/(2^nref)/100

println("""

Baffled piston in a half-sphere domain with ABC.

Hexahedral mesh. Algorithm version.
""")

t0 = time()

# Hexahedral mesh
fens,fes = H8sphere(R,nref); 
bfes = meshboundary(fes)

l=feselect(fens,bfes,facing=true,direction=[1.0 1.0  1.0]) 
ex(xyz, layer)=(R+layer/nlayers*(Ro-R))*xyz/norm(xyz)
fens1,fes1 = H8extrudeQ4(fens,subset(bfes,l),nlayers,ex); 
fens,newfes1,fes2= mergemeshes(fens1, fes1, fens, fes, tolerance)
fes=cat(newfes1,fes2)

# Piston surface mesh
bfes = meshboundary(fes)
show(count(bfes))
l1=feselect(fens,bfes,facing=true,direction=[-1.0 0.0 0.0])
l2=feselect(fens,bfes,distance=R,from=[0.0 0.0 0.0],inflate=tolerance) 
piston_fes=subset(bfes,intersect(l1,l2));

# Outer spherical boundary
louter=feselect(fens,bfes,facing=true,direction=[1.0 1.0  1.0])
outer_fes=subset(bfes,louter);

println("Pre-processing time elapsed = ",time() - t0,"s")

t1 = time()

# Region of the fluid
region1= dmake(fes=fes,integration_rule=GaussRule(order=2,dim=3));

# Surface for the ABC             # 
abc1 = dmake(fes=outer_fes, integration_rule=GaussRule(order=2,dim=2))

# Surface of the piston
flux1 = dmake(fes=piston_fes, integration_rule=GaussRule(order=2,dim=2),
              normal_flux=-rho*a_piston+0.0im);

# Make model data
modeldata= dmake(fens= fens,
                 bulk_modulus=bulk,
                 mass_density=rho,
                 omega=omega,
                 region=[region1],
                 boundary_conditions=dmake(flux=[flux1], ABC=[abc1]));

# Call the solver
modeldata=JFinEALE.AcousticsAlgorithmModule.steadystate(modeldata)

println("Computing time elapsed = ",time() - t1,"s")
println("Total time elapsed = ",time() - t0,"s")

geom=modeldata["geom"]
P=modeldata["P"]

println("fes: ", size(fes.conn))
println("fes: ", typeof(fes.conn))

scalars = abs(P.values)
println(size(geom.values))
println(size(scalars))

smax 	= maximum(scalars)
smin 	= minimum(scalars)
scalars = (scalars-smin) / (smax-smin)


using GLWindow, GLAbstraction, GLFW, ModernGL, GLPlot

immutable AABB{T}
    min::Vector3{T}
    max::Vector3{T}
end
function AABB{T}(geometry::Vector{Vector3{T}}) 
    vmin = Vector3(typemax(T))
    vmax = Vector3(typemin(T))
    @inbounds for i=1:length(geometry)
         vmin = min(geometry[i], vmin)
         vmax = max(geometry[i], vmax)
    end
    AABB(vmin, vmax)
end


unit{T}( geometry::Vector{Vector3{T}})                = unit!(copy(geometry))
unit{T}( geometry::Vector{Vector3{T}}, aabb::AABB{T}) = unit!(copy(geometry), aabb)
unit!{T}(geometry::Vector{Vector3{T}})                = unit!(geometry, AABB(geometry))

function unit!{T}(geometry::Vector{Vector3{T}}, aabb::AABB{T})
    isempty(geometry) && return geometry
    const two = convert(T, 2)
    middle = aabb.min + (aabb.max-aabb.min) / two
    scale  = two / maximum(aabb.max-aabb.min)
    @simd for i = 1:length(geometry)
       @inbounds geometry[i] = (geometry[i] - middle) * scale
    end
    geometry
end
Base.isless(a::Vector3, b::Vector3) = (a.(1) <= b.(1)) && (a.(2) <= b.(2)) && (a.(3) <= b.(3)) 

verts = Vec3[Vec3(geom.values[i,:]...) for i=1:size(geom.values,1)]
verts  = unit!(vertsp)
verts = (verts + 1f0) / 2f0
verts = (verts * 255) + 1
println("max: ", maximum(verts))
println("min: ", minimum(verts))
N = 256
volume = zeros(Float32, N, N, N)
for (i,vert) in enumerate(verts
	ind = round(Int, vert)
	volume[ind...] = float32(scalars[i])
end

println("max: ", maximum(volume))
println("min: ", minimum(volume))
global const window = createdisplay(w=1500, h=1000)

#Filter keydown events
keypressed = window.inputs[:buttonspressed]

#Make some attributes intseractive
algorithm 	= foldl( (v0, v1) -> in('I', v1) ? 2f0 : in('M', v1) ? 1f0 : v0, 2f0, keypressed) # i for isosurface, m for MIP#
isovalue 	= foldl( (v0, v1) -> in(GLFW.KEY_UP, v1) ? (v0 + 0.01f0) : (in(GLFW.KEY_DOWN, v1) ? (v0 - 0.01f0) : v0), 0.5f0, keypressed)
stepsize 	= foldl( (v0, v1) -> in(GLFW.KEY_LEFT, v1) ? (v0 + 0.0001f0) : (in(GLFW.KEY_RIGHT, v1)  ? (v0 - 0.0001f0) : v0), 0.005f0, keypressed)

glplot(volume, algorithm=algorithm, isovalue=isovalue, stepsize=stepsize, color=Vec3(1,0,0))


#particles = Vec4[Vec4(geom.values[i,:]..., scalars[i]) for i=1:size(geom.values,1)]
#vertex = reinterpret(Meshes.Face, )


#gpuobj = glplot(particles)
renderloop(window)

# using Winston
# pl = FramedPlot(title="Matrix",xlabel="x",ylabel="Re P, Im P")
# setattr(pl.frame, draw_grid=true)
# add(pl, Curve([1:length(C[:])],vec(C[:]), color="blue"))

# # pl=plot(geom.values[nLx,1][ix],scalars[nLx][ix])
# # xlabel("x")
# # ylabel("Pressure")
# display(pl)
#=

immutable Vector4{T}
	a::T
	b::T
	c::T
	d::T
end
immutable Mat4x4{T}
	a::Vector4{T}
	b::Vector4{T}
	c::Vector4{T}
	d::Vector4{T}
end

Base.getindex(x::Vector4, i::Integer) = x.(i)
Base.getindex(x::Mat4x4,  i::Integer, j::Integer) = x.(i).(j)

Base.setindex!{T}(x::Vector4{T}, val::T, i::Integer) = Vector4(
	ifelse(i==1, val, x.(1)),
	ifelse(i==2, val, x.(2)),
	ifelse(i==3, val, x.(3)),
	ifelse(i==4, val, x.(4)),
)
Base.setindex!{T}(x::Mat4x4{T}, val::T, i::Integer, j::Integer) = Mat4x4(
	ifelse(i==1, setindex!(x.(1), val, j), x.(1)),
	ifelse(i==2, setindex!(x.(2), val, j), x.(2)),
	ifelse(i==3, setindex!(x.(3), val, j), x.(3)),
	ifelse(i==4, setindex!(x.(4), val, j), x.(4))
)
@show const a = Vector4(1,2,3,4)
@show const b = Mat4x4(a,a,a,a)
@show b[2,3]
@show
c =  a[2] = 77
println(c)
# elapsed time: 5.170104708 seconds (840096464 bytes allocated, 2.57% gc time)
# elapsed time: 5.57285752 seconds (1533691192 bytes allocated, 2.56% gc time)
# elapsed time: 4.76077465 seconds (1297868744 bytes allocated, 1.72% gc time)

immutable Word
	x1::Uint8
	x2::Uint8
	x3::Uint8
	x4::Uint8

	x5::Uint8
	x6::Uint8
	x7::Uint8
	x8::Uint8
end
count1(text, tofind) = foldl(0, text) do counter, character
	character==tofind && return counter + 1
	return counter
end
function count2(text, tofind)
  	counter = 0
	@simd for i=1:length(text)
	    @inbounds if text[i]==tofind
	    	counter += 1
	    end
	end
	return counter
end



function byfoot1(text, tofind)
  	r = 0
	@simd for i=1:length(text)
		@inbounds begin
	  		text[i].(1)==tofind && (r += 1)
		    text[i].(2)==tofind && (r += 1)
		    text[i].(3)==tofind && (r += 1)
		    text[i].(4)==tofind && (r += 1)
		    text[i].(5)==tofind && (r += 1)
		    text[i].(6)==tofind && (r += 1)
		    text[i].(7)==tofind && (r += 1)
		    text[i].(8)==tofind && (r += 1)
		end
	end
	return r
end



N1 = 40
N2 = 10^9
const tofind1 	= '\n'
const the_char 	= uint8('\n')
const s3 		= fill(the_char, N1)
const s4 		= fill(the_char, N2)
const tofind2 	= the_char

const s5 = reinterpret(Word, s3, (div(N1,8),))
const s6 = reinterpret(Word, s4, (div(N2,8),))


#println("foldl")
#@time count1(s3, tofind2)
#@time result = count1(s4, tofind2)
#println(result)

println("looped")
@time count2(s3, tofind2)
@time result = count2(s4, tofind2)
println(result)
println("vectorized count")
@time byfoot1(s5, tofind2)
@time result = byfoot1(s6, tofind2)
println(result)

immutable myfunc <: Base.Func{1} end 
Base.call(::myfunc, x) = x == tofind2
const mf = myfunc()

println("julia count")
@time count(mf, s3)
@time result = count(mf, s4)
println(result)
=#