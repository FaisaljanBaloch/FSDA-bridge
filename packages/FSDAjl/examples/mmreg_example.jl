# MMreg: MM estimation of regression coefficients on the Hawkins benchmark.
#
# Robust estimators trade efficiency for resistance. LXS tolerates up to half
# the data being wrong, but pays for it with noisier estimates when the data is
# actually clean. MM estimation is a two stage answer: start from a high
# breakdown estimate, then refine it to recover most of the efficiency of least
# squares without giving up the resistance.
#
# Unlike LXS, this is an independent comparison. MMreg computes its own S
# estimate to start from rather than borrowing the LXS fit, so when both flag
# the same units that is two methods agreeing rather than one reporting the
# other.
#
# MMreg has no msg option, so its progress text appears in the output.
#
# Run from the repository root:
#   julia --project=code/fsda_engine packages/FSDAjl/examples/mmreg_example.jl

include(joinpath(@__DIR__, "..", "src", "engines", "engine.jl"))

using Printf

h = start_engine()

try
    D = eval_expr(h, "table2array(getfield(load('hawkins.mat'),'hawkins'))")
    n = size(D, 1)
    @printf("hawkins: %d observations, %d columns\n\n", n, size(D, 2))

    y = D[:, 9:9]
    X = D[:, 1:8]

    call(h, "rng", 1234, nargout = 0)
    out = call(h, "MMreg", y, X)
    @printf("\nMMreg returned a Dict with keys: %s\n\n",
            join(sort(collect(keys(out))), ", "))

    beta  = vec(out["beta"])
    Sbeta = vec(out["Sbeta"])
    res   = vec(out["residuals"])
    lout  = Int.(vec(out["outliers"]))
    aux   = out["auxscale"]

    println("coefficients: the S estimate MM starts from, and the refined result")
    @printf("  term        S estimate       MM final        change\n")
    labels = vcat("intercept", ["X$(j)" for j in 1:(length(beta) - 1)])
    for j in 1:length(beta)
        @printf("  %-10s %11.6f  %13.6f  %12.6f\n",
                labels[j], Sbeta[j], beta[j], beta[j] - Sbeta[j])
    end

    @printf("\nauxiliary scale: %.6f\n", aux isa AbstractArray ? aux[1] : aux)
    @printf("units declared outliers: %d of %d\n\n", length(lout), n)

    print("outliers:\n  ")
    for (i, u) in enumerate(lout)
        @printf("%4d", u)
        i % 14 == 0 && print("\n  ")
    end
    println("\n")

    # LXS reached the same conclusion on this data by a different route.
    lxs = [2,4,5,14,19,21,28,34,38,40,43,45,46,59,60,61,62,63,66,69,72,73,74,
           75,76,77,79,92,94,99,100,101,106,107,108,111,112,115,122,124,126,128]
    if lout == lxs
        println("MMreg flags exactly the units LXS flags, reached independently.")
    else
        @printf("MMreg and LXS differ on %d units.\n",
                length(symdiff(lout, lxs)))
    end
finally
    stop_engine(h)
end
