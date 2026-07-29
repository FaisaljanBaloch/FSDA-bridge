# mahalFS: Mahalanobis distances on the Swiss banknotes data.
#
# FSDA is a MATLAB toolbox. This script starts one MATLAB session, makes a
# single call to mahalFS, prints the result, and shuts the session down.
# The distances are squared, so large values mark unusual banknotes.
#
# Run from the repository root:
#   julia --project=code/fsda_engine packages/FSDAjl/examples/mahalfs_example.jl

include(joinpath(@__DIR__, "..", "src", "engines", "engine.jl"))

using Printf

h = start_engine()

try
    # The FSDA datasets ship as MATLAB tables, so convert on the MATLAB side.
    Y = eval_expr(h, "table2array(getfield(load('swiss_banknotes.mat'),'swiss_banknotes'))")
    n, v = size(Y)
    @printf("swiss_banknotes: %d observations, %d variables\n\n", n, v)

    # Centroid and covariance, matching MATLAB's mean() and cov() definitions.
    MU    = sum(Y, dims = 1) ./ n
    Yc    = Y .- MU
    SIGMA = (Yc' * Yc) ./ (n - 1)

    # One call to FSDA. A numeric array crosses back as a Julia Matrix.
    d = call(h, "mahalFS", Y, MU, SIGMA)
    dv = vec(d)

    @printf("mahalFS returned a %s of size %s\n\n", typeof(d), size(d))

    println("first five distances")
    for i in 1:5
        @printf("  unit %3d   d = %10.6f\n", i, dv[i])
    end

    # Row order is preserved across the bridge, so Julia index i is MATLAB unit i.
    println("\nfive most distant units")
    for i in sortperm(dv, rev = true)[1:5]
        @printf("  unit %3d   d = %10.6f\n", i, dv[i])
    end
finally
    stop_engine(h)
end
