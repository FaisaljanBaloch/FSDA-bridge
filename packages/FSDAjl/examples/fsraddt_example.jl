# FSRaddt: added variable deletion t tests along the forward search.
#
# Every other example here asks which observations are unusual. This one asks a
# different question: is each predictor actually needed?
#
# A deletion t test asks what happens to the fit if one variable is dropped. A
# large absolute t means the variable is carrying real information. What makes
# this version useful is that the test is recomputed at every step of the
# forward search, so you can see whether a variable looks significant only
# because of a handful of observations, or genuinely throughout.
#
# Run from the repository root:
#   julia --project=code/fsda_engine packages/FSDAjl/examples/fsraddt_example.jl

include(joinpath(@__DIR__, "..", "src", "engines", "engine.jl"))

using Printf

h = start_engine()

try
    D = eval_expr(h, "table2array(getfield(load('multiple_regression.mat'),'multiple_regression'))")
    n = size(D, 1)
    @printf("multiple_regression: %d observations, %d columns\n\n", n, size(D, 2))

    y = D[:, 4:4]
    X = D[:, 1:3]

    call(h, "rng", 1234, nargout = 0)
    out = call(h, "FSRaddt", y, X; msg = 0, plots = 0)
    @printf("FSRaddt returned a Dict with keys: %s\n\n",
            join(sort(collect(keys(out))), ", "))

    Tdel = out["Tdel"]
    nsteps, ncols = size(Tdel)
    npred = ncols - 1

    @printf("Tdel is %d steps by %d columns: subset size plus %d predictors\n",
            nsteps, ncols, npred)
    @printf("search monitored from subset size %d to %d\n\n",
            Int(Tdel[1, 1]), Int(Tdel[end, 1]))

    println("deletion t statistic, first three steps and last three")
    println("  subset      X1        X2        X3")
    for i in vcat(1:3, (nsteps - 2):nsteps)
        @printf("  %6d  %8.4f  %8.4f  %8.4f\n",
                Int(Tdel[i, 1]), Tdel[i, 2], Tdel[i, 3], Tdel[i, 4])
    end

    # Roughly, |t| above 2 counts as significant at the usual 5 percent level.
    println("\nat the full sample")
    for j in 1:npred
        t = Tdel[end, j + 1]
        verdict = abs(t) > 2 ? "significant" : "not significant"
        @printf("  X%-2d  t = %8.4f   %s\n", j, t, verdict)
    end

    println("\nhow often each predictor was significant across the whole search")
    for j in 1:npred
        cnt = count(>(2), abs.(Tdel[:, j + 1]))
        @printf("  X%-2d  %3d of %d steps (%.0f%%)\n",
                j, cnt, nsteps, 100 * cnt / nsteps)
    end
    println("\nA predictor significant at only some steps is one whose importance")
    println("depends on which observations are included.")
finally
    stop_engine(h)
end
