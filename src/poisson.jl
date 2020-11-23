# In this tutorial, we will learn
# 
#    -  How to solve a simple PDE in Julia with Gridap
#    -  How to load a discrete model (aka a FE mesh) from a file
#    -  How to build a conforming Lagrangian FE space
#    -  How to define the different terms in a weak form
#    -  How to impose Dirichlet and Neumann boundary conditions
#    -  How to visualize results
# 
# 
# ## Problem statement
#
# In this first tutorial, we provide an overview of a complete simulation pipeline in Gridap: from the construction of the FE mesh to the visualization of the computed results. To this end, we consider a simple model problem: the Poisson equation.
#  We want to solve the Poisson equation on the 3D domain depicted in next figure with Dirichlet and Neumann boundary conditions. Dirichlet boundary conditions are applied on $\Gamma_{\rm D}$, being the outer sides of the prism (marked in red). Non-homogeneous Neumann conditions are applied to the internal boundaries $\Gamma_{\rm G}$, $\Gamma_{\rm Y}$, and $\Gamma_{\rm B}$ (marked in green, yellow and blue respectively). And homogeneous Neumann boundary conditions are applied in $\Gamma_{\rm W}$, the remaining portion of the boundary (marked in white).
# 
# ![](../assets/poisson/model-r1-2.png)
# 
#  Formally, the problem to solve is: find the scalar field $u$ such that
# 
# ```math
# \left\lbrace
# \begin{aligned}
# -\Delta u = f  \ &\text{in} \ \Omega,\\
# u = g \ &\text{on}\ \Gamma_{\rm D},\\
# \nabla u\cdot n = h \ &\text{on}\  \Gamma_{\rm N},\\
# \end{aligned}
# \right.
# ```
#  being $n$ the outwards unit normal vector to the Neumann boundary $\Gamma_{\rm N} \doteq \Gamma_{\rm G}\cup\Gamma_{\rm Y}\cup\Gamma_{\rm B}\cup\Gamma_{\rm W}$. In this example, we chose $f(x) = 1$, $g(x) = 2$, and $h(x)=3$ on $\Gamma_{\rm G}\cup\Gamma_{\rm Y}\cup\Gamma_{\rm B}$ and $h(x)=0$ on $\Gamma_{\rm W}$. The variable $x$ is the position vector $x=(x_1,x_2,x_3)$.
# 
#  ## Numerical scheme
# 
#  To solve this PDE, we use a conventional Galerkin finite element (FE) method with conforming Lagrangian FE spaces (see, e.g., [1] for specific details on this formulation). The weak form associated with this formulation is: find $u\in U_g$ such that $ a(u,v) = b(v) $ for all $v\in V_0$, where $U_g$ and $V_0$ are the subset of functions in $H^1(\Omega)$ that fulfill the Dirichlet boundary condition $g$ and $0$ respectively. The bilinear and linear forms for this problems are
# ```math
#   a(u,v) \doteq \int_{\Omega} \nabla v \cdot \nabla u \ {\rm d}\Omega, \quad b(v) \doteq \int_{\Omega} v\ f  \ {\rm  d}\Omega + \int_{\Gamma_{\rm N}} v\ h \ {\rm d}\Gamma_{\rm N}.
# ```
# The problem is solved numerically by approximating the spaces $U_g$ and $V_0$ by their discrete counterparts associated with a FE mesh of the computational domain $\Omega$. As we have anticipated, we consider standard conforming Lagrangian FE spaces for this purpose.
# 
# The implementation of this numerical scheme in Gridap is done in a user-friendly way thanks to the abstractions provided by the library. As it will be seen below, all the mathematical objects involved in the definition of the discrete weak problem have a correspondent representation in the code.
# 
#  ## Setup
# 
#  The step number 0 in order to solve the problem is to load the Gridap library in the code. If you have configured your Julia environment properly, it is simply done with the line:

using Gridap

# ## Discrete model
# 
# As in any FE simulation, we need a discretization of the computational domain (i.e., a FE mesh). All geometrical data needed for solving a FE problem is provided in Gridap by types inheriting from the abstract type `DiscreteModel`. In the following line, we build an instance of `DiscreteModel` by loading a `json` file.

model = DiscreteModelFromFile("../models/model.json")

# The file `"model.json"` is a regular `json` file that includes a set of fields that describe the discrete model. It was generated by using together the [GMSH](http://gmsh.info/) mesh generator and the [GridapGmsh](https://github.com/gridap/GridapGmsh.jl) package. First, we generate a `"model.msh"` file with GMSH (which contains a FE mesh and information about user-defined physical boundaries in {GMSH} format). Then, this file is converted to the Gridap-compatible `"model.json"` file using the conversion tools available in the GridapGmsh package. See the documentation of the [GridapGmsh](https://github.com/gridap/GridapGmsh.jl) for more information.
# 
# You can easily inspect the generated discrete model in [Paraview](https://www.paraview.org/) by writing it in `vtk` format.

writevtk(model,"model")

# The previous line generates four different files `model_0.vtu`, `model_1.vtu`, `model_2.vtu`, and `model_3.vtu` containing the vertices, edges, faces, and cells present in the discrete model. Moreover, you can easily inspect which boundaries are defined within the model.
# 
# For instance, if you want to see which faces of the model are on the boundary $\Gamma_{\rm B}$ (i.e., the walls of the circular perforation), open the file `model_2.vtu` and chose coloring by the element field "circle". You should see that only the faces on the circular hole have a value different from zero (see next figure).
# 
# ![](../assets/poisson/fig_faces_on_circle.png)
# 
# It is also possible to see which vertices are on the Dirichlet boundary $\Gamma_{\rm D}$. To do so, open the file `model_0.vtu` and chose coloring by the field "sides" (see next figure).
# 
# ![](../assets/poisson/fig_vertices_on_sides.png)
# 
# That is, the boundary $\Gamma_{\rm B}$ (i.e., the walls of the circular hole) is called "circle" and the Dirichlet boundary $\Gamma_{\rm D}$ is called "sides" in the model. In addition, the walls of the triangular hole $\Gamma_{\rm G}$ and the walls of the square hole $\Gamma_{\rm Y}$ are identified in the model with the names "triangle" and "square" respectively. You can easily check this by opening the corresponding file in Paraview.
# 
# 
# ## FE spaces
# 
#  Once we have a discretization of the computational domain, the next step is to generate a discrete approximation of the finite element spaces $V_0$ and $U_g$ (i.e. the test and trial FE spaces) of the problem. To do so, first, we are going to build a discretization of $V_0$ as the standard Conforming Lagrangian FE space (with zero boundary conditions) associated with the discretization of the computational domain. The approximation of the FE space $V_0$ is built as follows:

order = 1
reffe = ReferenceFE(:Lagrangian,Float64,order)
V0 = TestFESpace(model,reffe;conformity=:H1,dirichlet_tags="sides")

# Here, we have used the `TestFESpace` constructor, which constructs a particular FE space (to be used as a test space) from a set of options described as positional and key-word arguments. The first positional argument is the model on top of which we want to build the space. The second positional argument contains information about the type of FE interpolation (the reference FE in this case). With `ReferenceFE(:Lagrangian,Float64,order)` We select a scalar-valued Lagrangian reference FE of order 1, where the value of the shape functions will be represented with  64-bit floating point numbers. With the key-word argument `conformity` we define the regularity of the interpolation at the boundaries of the cells in the mesh. Here, we use `conformity=:H1`, which means that the resulting interpolation space is a subset of $H^1(\Omega)$ (i.e., continuous shape functions). On the other hand, we pass the identifiers of the Dirichlet boundary via the `dirichlet_tags` argument. In this case, we mark as Dirichlet all objects of the discrete model identified with the `"sides"` tag. Since this is a test space, the corresponding shape functions vanishes at the Dirichlet boundary.
# 
# Once the space $V_0$ is discretized in the code, we proceed with the approximation of the trial space $U_g$.

g(x) = 2.0
Ug = TrialFESpace(V0,g)

# To this end, we have used the `TrialFESpace` constructors. Note that we have passed a function representing the value of the Dirichlet boundary condition, when building the trial space.
# 
# 
# ## Numerical integration
# 
# Once we have built the interpolation spaces, the next step is to set up the machinery to perform the integrals in the weak form numerically. Here, we need to compute integrals on the interior of the domain $\Omega$ and on the Neumann boundary $\Gamma_{\rm N}$. In both cases, we need two main ingredients. We need to define an integration mesh (i.e. a triangulation of the integration domain), plus a Gauss-like quadrature in each of the cells in the triangulation. In Gridap, integration meshes are represented by types inheriting from the abstract type `Triangulation`. For integrating on the domain $\Omega$, we build the following triangulation and the corresponding Lebesgue measure, which will allow to write down integrals in a syntax similar to the usual mathematical notation.

degree = 2
Ω = Triangulation(model)
dΩ = LebesgueMeasure(Ω,degree)

# Here, we build a triangulation from the cells of the model and build (an approximation of) the Lebesgue measure using a quadrature rule of degree 2 in the cells of this triangulation. This is enough for integrating the corresponding terms of the weak form exactly for an interpolation of order 1.
# 
# On the other hand, we need a special type of triangulation, represented by the type `BoundaryTriangulation`, to integrate on the boundary. Essentially, a `BoundaryTriangulation` is a particular type of `Triangulation` that is aware of which cells in the model are touched by faces on the boundary. We build an instance of this type from the discrete model and the names used to identify the Neumann boundary as follows:

neumanntags = ["circle", "triangle", "square"]
Γ = BoundaryTriangulation(model,tags=neumanntags)
dΓ = LebesgueMeasure(Γ,degree)

# In addition, we have created a quadrature of degree 2 on top of the cells in the triangulation for the Neumann boundary.
# 
# ## Weak form
# 
# With all the ingredients presented so far, we are ready to define the weak form. This is done by defining to functions representing the bi-linear and linear forms:

f(x) = 1.0
h(x) = 3.0
a(u,v) = ∫( ∇(v)⋅∇(u) )*dΩ
b(v) = ∫( v*f )*dΩ + ∫( v*h )*dΓ

# Note that by using the integral function `∫`, the Lebesgue measures `dΩ`, `dΓ`, and the gradient function `∇`, the weak form is written with an obvious relation with the corresponding mathematical notation.

#  ## FE Problem
#
#  At this point, we can built the FE problem that, once solved, will provide the numerical solution we are looking for. A FE problem is represented in Gridap by types inheriting from the abstract type `FEOperator` (both for linear and nonlinear cases). Since we want to solve a linear problem, we use the concrete type `AffineFEOperator`, i.e., a problem represented by a matrix and a right hand side vector.

op = AffineFEOperator(a,b,Ug,V0)

# Note that the `AffineFEOperator` object representing our FE problem is built from the function `a` and `b` representing the weak form and test and trial FE spaces `V0` and `Ug`. 
# 
#  ## Solver phase
# 
#  We have constructed a FE problem, the last step is to solve it. In Gridap, FE problems are solved with types inheriting from the abstract type `FESolver`. Since this is a linear problem, we use a `LinearFESolver`:

ls = LUSolver()
solver = LinearFESolver(ls)

#  `LinearFESolver` objects are built from a given algebraic linear solver. In this case, we use a LU factorization. Now we are ready to solve the FE problem with the FE solver as follows:

uh = solve(solver,op)

# The `solve` function returns the computed numerical solution `uh`. This object is an instance of `FEFunction`, the type used to represent a function in a FE space. We can inspect the result by writing it into a `vtk` file:

writevtk(Ω,"results",cellfields=["uh"=>uh])

#  which will generate a file named `results.vtu` having a nodal field named `"uh"` containing the solution of our problem (see next figure). 
#
# ![](../assets/poisson/fig_uh.png)
#
# ## References
#
# [1] C. Johnson. *Numerical Solution of Partial Differential Equations by the Finite Element Method*. Dover Publications, 2009.
