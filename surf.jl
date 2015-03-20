module scratch
using JFinEALE
#


rho=1.21*phun("kg/m^3");# mass density
c =343.0*phun("m/s");# sound speed
bulk= c^2*rho;
omega= 7500*phun("rev/s");      # frequency of the piston
a_piston= -1.0*phun("mm/s")     # amplitude of the piston acceleration
R=50.0*phun("mm");# radius of the piston
Ro=150.0*phun("mm"); # radius of the enclosure
nref=4;#number of refinements of the sphere around the piston
nlayers=35;                     # number of layers of elements surrounding the piston
tolerance=R/(2^nref)/100

println("""
Baffled piston in a half-sphere domain with ABC.
Hexahedral mesh. Algorithm version.
""")

t0 = time()

# Hexahedral mesh
fens,fes = H8sphere(R,nref); 
bfes = meshboundary(fes)
File =  "baffledabc_boundary.vtk"
vtkexportmesh (File, bfes.conn, fens.xyz, JFinEALE.MeshExportModule.Q4)
 @async run(`"C:/Program Files (x86)/ParaView 4.2.0/bin/paraview.exe" $File`)

l=feselect(fens,bfes,facing=true,direction=[1.0 1.0  1.0]) 
ex(xyz, layer)=(R+layer/nlayers*(Ro-R))*xyz/norm(xyz)
fens1,fes1 = H8extrudeQ4(fens,subset(bfes,l),nlayers,ex); 
fens,newfes1,fes2= mergemeshes(fens1, fes1, fens, fes, tolerance)
fes=cat(newfes1,fes2)

# Piston surface mesh
bfes = meshboundary(fes)
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
modeldata=JFinEALE.AlgoAcousticsModule.steadystate(modeldata)

println("Computing time elapsed = ",time() - t1,"s")
println("Total time elapsed = ",time() - t0,"s")

geom=modeldata["geom"]
P=modeldata["P"]

File =  "baffledabc.vtk"
#vtkexportmesh (File, fes.conn, geom.values, JFinEALE.MeshExportModule.H8; scalars=abs(P.values), scalars_name ="absP")
# @async run(`"C:/Program Files (x86)/ParaView 4.2.0/bin/paraview.exe" $File`)

nfens,bfes = Q4toT3(fens,meshboundary(fes))
File =  "baffledabc_boundary_sol_T3.vtk"
#vtkexportmesh (File, bfes.conn, nfens.xyz, JFinEALE.MeshExportModule.T3; scalars=abs(P.values), scalars_name ="absP")

using Meshes, GLPlot, ImmutableArrays, GLAbstraction
window = createdisplay(w=1500, h=1000, lookat=Vec3(0), eyeposition=Vec3(0.5))

const ind = Face[Face(bfes.conn[i,:]...) for i=1:size(bfes.conn,1)]
const vts = Vector3{Float64}[Vector3{Float64}(nfens.xyz[i,:]...) for i=1:size(nfens.xyz, 1)]

const msh = Mesh(vts, ind, false)

ro = glplot(msh)

renderloop(window)

# using Winston
# pl = FramedPlot(title="Matrix",xlabel="x",ylabel="Re P, Im P")
# setattr(pl.frame, draw_grid=true)
# add(pl, Curve([1:length(C[:])],vec(C[:]), color="blue"))

# # pl=plot(geom.values[nLx,1][ix],scalars[nLx][ix])
# # xlabel("x")
# # ylabel("Pressure")
# display(pl)

end