# tclust: robust clustering with trimming on the Old Faithful geyser data.
#
# Ordinary clustering forces every point into a cluster, so a handful of odd
# points can drag a centroid badly off. Trimmed clustering is allowed to discard
# a fixed proportion as noise, here 10 percent, and fits the rest.
#
# geyser2 records each eruption's length against the length of the previous one.
# The structure is famously bimodal: short eruptions follow long ones, and long
# eruptions follow either.
#
# tclust uses random starts, so the seed is fixed. restrfactor is passed
# explicitly rather than left to default, since a default that changes would
# silently change the result.
#
# Run from the repository root:
#   julia --project=code/fsda_engine packages/FSDAjl/examples/tclust_example.jl

include(joinpath(@__DIR__, "..", "src", "engines", "engine.jl"))

using Printf

h = start_engine()

try
    Y = eval_expr(h, "table2array(getfield(load('geyser2.mat'),'geyser2'))")
    n = size(Y, 1)
    @printf("geyser2: %d eruptions, %d variables\n", n, size(Y, 2))
    println("  column 1: this eruption's length")
    println("  column 2: the previous eruption's length\n")

    k, alpha, restr = 3, 0.1, 12

    call(h, "rng", 1234, nargout = 0)
    out = call(h, "tclust", Y, k, alpha, restr; msg = 0, plots = 0)
    @printf("tclust returned a Dict with keys: %s\n\n",
            join(sort(collect(keys(out))), ", "))

    idx = Int.(vec(out["idx"]))     # cluster label per unit, 0 means trimmed
    mu  = out["muopt"]              # k by v, one row per cluster

    ntrim = count(==(0), idx)
    @printf("trimmed as noise: %d of %d units (%.1f%%)\n\n",
            ntrim, n, 100 * ntrim / n)

    println("cluster centroids")
    println("  cluster   size   this eruption   previous")
    for c in 1:k
        @printf("  %7d  %5d  %14.4f  %9.4f\n",
                c, count(==(c), idx), mu[c, 1], mu[c, 2])
    end

    println("\nfirst twenty units and their cluster (0 = trimmed)")
    print("  ")
    for i in 1:20
        @printf("%d ", idx[i])
    end
    println()
finally
    stop_engine(h)
end
