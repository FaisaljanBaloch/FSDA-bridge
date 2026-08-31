# mcd: Minimum Covariance Determinant on the Swiss banknotes data.
#
# MCD reaches the same goal as the forward search by a different route. Rather
# than growing a clean subset one observation at a time, it searches for the
# subset of about half the data whose covariance matrix has the smallest
# determinant, meaning the tightest cloud, and estimates the centre and spread
# from that. Everything far from it is an outlier.
#
# Two methods that disagree in approach but agree in conclusion is a stronger
# result than either alone, so this example compares its findings with FSM's.
#
# MCD uses random subsampling, so the seed is fixed.
#
# Run from the repository root:
#   julia --project=code/fsda_engine packages/FSDAjl/examples/mcd_example.jl

include(joinpath(@__DIR__, "..", "src", "engines", "engine.jl"))

using Printf

h = start_engine()

try
    Y = eval_expr(h, "table2array(getfield(load('swiss_banknotes.mat'),'swiss_banknotes'))")
    n, v = size(Y)
    @printf("swiss_banknotes: %d observations, %d variables\n\n", n, v)

    call(h, "rng", 1234, nargout = 0)
    out = call(h, "mcd", Y; msg = 0, plots = 0)
    @printf("mcd returned a Dict with keys: %s\n\n",
            join(sort(collect(keys(out))), ", "))

    loc  = vec(out["loc"])
    md   = vec(out["md"])
    lout = Int.(vec(out["outliers"]))

    @printf("units declared outliers: %d of %d\n\n", length(lout), n)

    print("outliers:\n  ")
    for u in lout
        @printf("%d ", u)
    end
    println("\n")

    println("robust centroid versus the ordinary mean")
    plain = vec(sum(Y, dims = 1) ./ n)
    println("  var    MCD robust      plain mean      shift")
    for j in 1:v
        @printf("  %3d  %12.4f  %14.4f  %9.4f\n",
                j, loc[j], plain[j], plain[j] - loc[j])
    end

    println("\nfive largest robust distances")
    for i in sortperm(md, rev = true)[1:5]
        @printf("  unit %3d   distance = %9.4f\n", i, md[i])
    end

    # FSM's conclusion on the same data, for comparison.
    fsm = [1, 40, 111, 116, 138, 148, 160, 161, 162, 167, 168, 171, 180, 182, 187, 192]
    shared = intersect(lout, fsm)
    only_mcd = setdiff(lout, fsm)
    @printf("\nFSM flagged %d units on this data. MCD flagged %d.\n", length(fsm), length(lout))
    @printf("shared: %d units. Flagged by MCD only: ", length(shared))
    for u in only_mcd
        @printf("%d ", u)
    end
    println()
    if isempty(setdiff(fsm, lout))
        println("Every unit FSM flagged was also flagged by MCD.")
    end
finally
    stop_engine(h)
end
