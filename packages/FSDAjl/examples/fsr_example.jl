# FSR: forward search outlier detection on the Hawkins benchmark.
#
# The forward search starts from a small subset that looks clean, then adds
# observations one at a time, always taking the ones that fit best. It watches
# the minimum deletion residual at each step. When that jumps above its
# confidence envelope, the search has been forced to admit an outlier.
#
# Hawkins is a constructed benchmark containing known contamination, which is
# why it shows the method working. On clean data such as stack loss, FSR
# correctly reports nothing.
#
# FSR uses random subsampling on data this size, so the seed is fixed.
#
# Run from the repository root:
#   julia --project=code/fsda_engine packages/FSDAjl/examples/fsr_example.jl

include(joinpath(@__DIR__, "..", "src", "engines", "engine.jl"))

using Printf

h = start_engine()

try
    D = eval_expr(h, "table2array(getfield(load('hawkins.mat'),'hawkins'))")
    @printf("hawkins: %d observations, %d columns\n\n", size(D, 1), size(D, 2))

    # 9:9 keeps this two dimensional. A 1-D vector would cross as a MATLAB row,
    # but FSR expects the response as an (n, 1) column.
    y = D[:, 9:9]
    X = D[:, 1:8]

    # Fix MATLAB's random number generator so the search is reproducible.
    call(h, "rng", 1234, nargout = 0)

    out = call(h, "FSR", y, X; msg = 0, plots = 0)
    @printf("FSR returned a Dict with keys: %s\n\n",
            join(sort(collect(keys(out))), ", "))

    mdr  = out["mdr"]
    lout = vec(out["ListOut"])

    @printf("forward search ran %d steps\n", size(mdr, 1))
    @printf("units flagged as outliers: %d of %d\n\n", length(lout), size(D, 1))

    # These are MATLAB unit numbers, already 1 based, so they are printed as is.
    println("flagged units")
    for (i, u) in enumerate(lout)
        @printf("%5d", Int(u))
        i % 14 == 0 && println()
    end
    length(lout) % 14 == 0 || println()

    println("\nminimum deletion residual, first five steps")
    for i in 1:5
        @printf("  step %3d   subset size %3d   mdr = %8.4f\n",
                i, Int(mdr[i, 1]), mdr[i, 2])
    end
finally
    stop_engine(h)
end
