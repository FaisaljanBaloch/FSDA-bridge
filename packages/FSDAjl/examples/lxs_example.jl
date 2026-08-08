# LXS: Least Median of Squares regression on the Hawkins benchmark.
#
# Ordinary least squares minimises the SUM of squared residuals, so a single
# bad point can move the whole fit. LXS minimises the MEDIAN instead. Half the
# observations can be arbitrarily wrong without shifting the estimate, which is
# what makes it robust.
#
# Note on the relationship with FSR: the forward search uses LXS internally to
# choose where to start. So when both flag the same units here, that is not two
# independent methods agreeing, it is FSR reporting a conclusion built on this
# estimate. Worth knowing before reading too much into the match.
#
# LXS uses random subsampling, so the seed is fixed.
#
# Run from the repository root:
#   julia --project=code/fsda_engine packages/FSDAjl/examples/lxs_example.jl

include(joinpath(@__DIR__, "..", "src", "engines", "engine.jl"))

using Printf

h = start_engine()

try
    D = eval_expr(h, "table2array(getfield(load('hawkins.mat'),'hawkins'))")
    n = size(D, 1)
    @printf("hawkins: %d observations, %d columns\n\n", n, size(D, 2))

    # 9:9 keeps this two dimensional, since LXS expects an (n, 1) column.
    y = D[:, 9:9]
    X = D[:, 1:8]

    call(h, "rng", 1234, nargout = 0)
    out = call(h, "LXS", y, X; msg = 0)
    @printf("LXS returned a Dict with keys: %s\n\n",
            join(sort(collect(keys(out))), ", "))

    beta = vec(out["beta"])
    res  = vec(out["residuals"])
    lout = Int.(vec(out["outliers"]))
    scale = out["scale"]

    println("robust coefficients")
    @printf("  intercept  %10.6f\n", beta[1])
    for j in 2:length(beta)
        @printf("  X%-8d  %10.6f\n", j - 1, beta[j])
    end

    @printf("\nrobust scale estimate: %.6f\n", scale isa AbstractArray ? scale[1] : scale)
    @printf("units declared outliers: %d of %d\n\n", length(lout), n)

    print("outliers:\n  ")
    for (i, u) in enumerate(lout)
        @printf("%4d", u)
        i % 14 == 0 && println("\n  ")
    end
    println()

    println("\nfive largest absolute residuals")
    for i in sortperm(abs.(res), rev = true)[1:5]
        @printf("  unit %3d   residual = %10.4f\n", i, res[i])
    end
finally
    stop_engine(h)
end
