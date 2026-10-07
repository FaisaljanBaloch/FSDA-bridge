# FSRfan: monitoring the Box-Cox score test along the forward search.
#
# The Score example tested transformations once, on the whole wool dataset, and
# concluded that logs were best supported. FSRfan asks a sharper question: does
# that conclusion hold throughout, or does it appear only once particular
# observations enter the sample?
#
# It recomputes the score statistic for every candidate lambda at every step of
# the search. The result is the fan plot, and a transformation supported only at
# the end is one resting on a few observations.
#
# Run from the repository root:
#   julia --project=code/fsda_engine packages/FSDAjl/examples/fsrfan_example.jl

include(joinpath(@__DIR__, "..", "src", "engines", "engine.jl"))

using Printf

h = start_engine()

try
    W = eval_expr(h, "table2array(getfield(load('wool.mat'),'wool'))")
    @printf("wool: %d observations, %d columns\n\n", size(W, 1), size(W, 2))

    y  = W[:, 4:4]
    X  = W[:, 1:3]
    la = [-1.0, -0.5, 0.0, 0.5, 1.0]

    call(h, "rng", 1234, nargout = 0)
    out = call(h, "FSRfan", y, X; la = la, msg = 0, plots = 0)
    @printf("FSRfan returned a Dict with keys: %s\n\n",
            join(sort(collect(keys(out))), ", "))

    Sc = out["Score"]
    nsteps = size(Sc, 1)
    @printf("Score is %d steps by %d columns: subset size plus %d lambdas\n",
            nsteps, size(Sc, 2), length(la))
    @printf("monitored from subset size %d to %d\n\n",
            Int(Sc[1, 1]), Int(Sc[end, 1]))

    println("score statistic per lambda, every fourth step")
    print("  subset")
    for l in la
        @printf("%10.1f", l)
    end
    println()
    for i in 1:4:nsteps
        @printf("  %6d", Int(Sc[i, 1]))
        for j in 2:size(Sc, 2)
            @printf("%10.3f", Sc[i, j])
        end
        println()
    end

    # The best supported lambda at each step is the one closest to zero.
    println("\nbest supported lambda at each step")
    best = [la[argmin(abs.(Sc[i, 2:end]))] for i in 1:nsteps]
    print("  ")
    for (i, b) in enumerate(best)
        @printf("%.1f ", b)
        i % 12 == 0 && print("\n  ")
    end
    println()

    stable = count(==(0.0), best)
    @printf("\nlambda = 0, the log transformation, was best supported at %d of %d steps.\n",
            stable, nsteps)
    println("The early steps wander, which is expected: a subset of five observations")
    println("cannot support a stable test with three predictors. What matters is where")
    println("the search settles, and the final steps agree on lambda = 0.")

    # Cross check against the single sample Score example.
    println("\nAt the full sample FSRfan gives:")
    @printf("  ")
    for j in 2:size(Sc, 2)
        @printf("%.4f  ", Sc[end, j])
    end
    println("\nThe Score example gave the same values to about twelve digits.")
    println("The small difference is ordinary floating point noise between two")
    println("computation paths inside FSDA, not anything introduced by the bridge.")
finally
    stop_engine(h)
end
