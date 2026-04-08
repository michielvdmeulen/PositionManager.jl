# To build the documentation locally and serve it with live updates:
# - Make sure to have LiveServer in your global environment
# - From inside a julia session in the project root, run:
#   include("docs/serve_locally.jl")

using Pkg
if Pkg.project().name != "docs"
    Pkg.activate(@__DIR__)
    Pkg.resolve()  # Automatically update deps
end

using PositionManager
using LiveServer

servedocs()
