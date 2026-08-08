# FSMeda: monitoring the forward search on the Swiss banknotes data.
#
# FSM answers "which units are outliers". FSMeda answers "what happened along
# the way", recording diagnostics at every step so the search can be inspected
# rather than just trusted.
#
# It needs a clean starting subset. The documented FSDA way of building one is
# to score every unit with unibiv and take the least outlying, which is exactly
# what the unibiv example prints as its most typical units.
#
# Run from the repository root:
#   julia --project=code/fsda_engine packages/FSDAjl/examples/fsmeda_example.jl

include(joinpath(@__DIR__, "..", "src", "engines", "engine.jl"))

using Printf

h = start_engine()

try
    Y = eval_expr(h, "table2array(getfield(load('swiss_banknotes.mat'),'swiss_banknotes'))")
    n = size(Y, 1)
    @printf("swiss_banknotes: %d observations, %d variables\n\n", n, size(Y, 2))

    # Step 1: score every unit, then take the twenty most typical.
    fre = call(h, "unibiv", Y)
    ord = sortperm(fre[:, 4])
    bsb = reshape(fre[ord[1:20], 1], :, 1)

    print("starting subset, the 20 most typical units:\n  ")
    for u in bsb
        @printf("%d ", Int(u))
    end
    println("\n")

    # These are MATLAB unit numbers, already 1 based, handed straight back.
    out = call(h, "FSMeda", Y, bsb; plots = 0)
    @printf("FSMeda returned a Dict with keys: %s\n\n",
            join(sort(collect(keys(out))), ", "))

    mmd = out["mmd"]
    MAL = out["MAL"]

    @printf("search ran %d steps, from subset size %d to %d\n",
            size(mmd, 1), Int(mmd[1, 1]), Int(mmd[end, 1]))
    @printf("MAL is %d units by %d steps\n\n", size(MAL, 1), size(MAL, 2))

    println("minimum Mahalanobis distance, first five steps")
    for i in 1:5
        @printf("  subset size %3d   mmd = %8.4f\n", Int(mmd[i, 1]), mmd[i, 2])
    end

    println("\nlast five steps, where outliers enter")
    for i in (size(mmd, 1) - 4):size(mmd, 1)
        @printf("  subset size %3d   mmd = %8.4f\n", Int(mmd[i, 1]), mmd[i, 2])
    end

    # A sharp rise at the end means the search was forced to admit units that
    # do not belong with the rest.
    @printf("\nmmd rose from %.4f to %.4f across the search\n",
            minimum(mmd[:, 2]), maximum(mmd[:, 2]))
finally
    stop_engine(h)
end
