# tkmeans: trimmed k-means on the Old Faithful geyser data.
#
# tkmeans is the simpler sibling of tclust. Both discard a fixed proportion of
# the data as noise rather than forcing every point into a cluster. The
# difference is what they assume about cluster shape: tkmeans measures plain
# distance to a centroid, so it looks for round clusters of similar size, while
# tclust models each cluster's covariance and can find elongated ones.
#
# Running both on the same data shows what that extra flexibility costs and
# buys. Here they agree on the structure and differ on the boundaries.
#
# tkmeans uses random starts, so the seed is fixed.
#
# Run from the repository root:
#   julia --project=code/fsda_engine packages/FSDAjl/examples/tkmeans_example.jl

include(joinpath(@__DIR__, "..", "src", "engines", "engine.jl"))

using Printf

h = start_engine()

try
    Y = eval_expr(h, "table2array(getfield(load('geyser2.mat'),'geyser2'))")
    n = size(Y, 1)
    @printf("geyser2: %d eruptions, %d variables\n", n, size(Y, 2))
    println("  column 1: this eruption's length")
    println("  column 2: the previous eruption's length\n")

    k, alpha = 3, 0.1

    call(h, "rng", 1234, nargout = 0)
    out = call(h, "tkmeans", Y, k, alpha; msg = 0, plots = 0)
    @printf("tkmeans returned a Dict with keys: %s\n\n",
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

    # Cluster numbering is arbitrary and differs between methods, so the
    # centroids are what to compare, not the labels.
    println("\ntclust found the same three structures on this data:")
    println("  short after long   tclust (2.0065, 4.5121)")
    println("  long after short   tclust (4.3500, 1.9946)")
    println("  long after long    tclust (4.2898, 4.1142)")
    println("\nAgreement on structure, difference on where the boundaries fall.")
finally
    stop_engine(h)
end
