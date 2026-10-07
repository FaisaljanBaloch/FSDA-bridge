# FSM: multivariate outlier detection by forward search on the Swiss banknotes.
#
# FSM and FSMeda run the same forward search but answer different questions.
# FSMeda records diagnostics at every step so the search can be inspected. FSM
# runs it to completion and reports the conclusion: which units are outliers,
# and what the centroid and covariance look like once they are excluded.
#
# The robust centroid is the useful part. An ordinary mean is pulled toward
# outliers by construction; this one is computed from the clean subset only.
#
# Run from the repository root:
#   julia --project=code/fsda_engine packages/FSDAjl/examples/fsm_example.jl

include(joinpath(@__DIR__, "..", "src", "engines", "engine.jl"))

using Printf

h = start_engine()

try
    Y = eval_expr(h, "table2array(getfield(load('swiss_banknotes.mat'),'swiss_banknotes'))")
    n, v = size(Y)
    @printf("swiss_banknotes: %d observations, %d variables\n\n", n, v)

    call(h, "rng", 1234, nargout = 0)
    out = call(h, "FSM", Y; plots = 0, msg = 0)
    @printf("FSM returned a Dict with keys: %s\n\n",
            join(sort(collect(keys(out))), ", "))

    lout = vec(out["outliers"])
    mmd  = out["mmd"]
    loc  = vec(out["loc"])

    @printf("search ran %d monitored steps\n", size(mmd, 1))
    @printf("units declared outliers: %d of %d\n\n", length(lout), n)

    # MATLAB unit numbers, already 1 based, printed as they arrived.
    print("outliers:\n  ")
    for u in lout
        @printf("%d ", Int(u))
    end
    println("\n")

    # Compare the robust centre with the ordinary mean of all the data.
    plain = vec(sum(Y, dims = 1) ./ n)

    println("robust centroid versus the ordinary mean")
    println("  var   FSM robust      plain mean      shift")
    for j in 1:v
        @printf("  %3d  %12.4f  %14.4f  %9.4f\n",
                j, loc[j], plain[j], plain[j] - loc[j])
    end
    println("\nThe shift is how far the outliers drag the ordinary mean.")
finally
    stop_engine(h)
end
