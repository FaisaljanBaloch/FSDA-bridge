# yXplot: scatter plot of the response against each predictor.
#
# Before any robust method runs, it is worth looking at the data. yXplot draws
# the response against each explanatory variable in turn, so patterns, curvature
# and obvious outliers are visible immediately.
#
# This example is different from the other fifteen in one important way.
#
# yXplot returns NO DATA. It is called for its side effect, the plot. So there
# is no output to compare against a reference, and it cannot pass a 1e-9
# agreement gate the way the others do. What can be verified is that the call
# succeeds, that it returns nothing rather than leaking a graphics handle across
# the bridge, and that the data going in arrived unchanged.
#
# That is the graphics handle contract in CONSTITUTION.md section 4: plotting
# routines are called with nargout = 0 for their side effect, and their handles
# are never requested.
#
# Run from the repository root:
#   julia --project=code/fsda_engine packages/FSDAjl/examples/yxplot_example.jl

include(joinpath(@__DIR__, "..", "src", "engines", "engine.jl"))

using Printf

h = start_engine()

try
    D = eval_expr(h, "table2array(getfield(load('stack_loss.mat'),'stack_loss'))")
    n = size(D, 1)
    @printf("stack_loss: %d observations, %d columns\n", n, size(D, 2))
    println("  X1 air flow, X2 water temperature, X3 acid concentration")
    println("  y  stack loss\n")

    y = D[:, 4:4]
    X = D[:, 1:3]

    # nargout = 0 asks for the side effect only. No handle is requested, so
    # none is marshalled.
    result = call(h, "yXplot", y, X; nargout = 0)

    @printf("yXplot returned: %s\n", result === nothing ? "nothing" : string(typeof(result)))
    println("No graphics handle crossed the bridge, which is the contract.\n")

    # Simple summaries, so the example says something about the data as well as
    # drawing it.
    yv = vec(y)
    @printf("response ranges from %g to %g\n\n", minimum(yv), maximum(yv))

    println("correlation of the response with each predictor")
    ybar = sum(yv) / n
    yc = yv .- ybar
    for j in 1:3
        xj = X[:, j]
        xc = xj .- sum(xj) / n
        r = sum(xc .* yc) / sqrt(sum(xc .^ 2) * sum(yc .^ 2))
        @printf("  X%d  r = %+.4f\n", j, r)
    end

    println("\nThe plot shows what those numbers cannot: the shape of each")
    println("relationship, and which points sit away from it.")
finally
    stop_engine(h)
end
