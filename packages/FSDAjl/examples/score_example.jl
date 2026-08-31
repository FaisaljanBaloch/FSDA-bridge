# Score: the Box-Cox transformation test on the wool data.
#
# Box and Cox (1964) asked whether a regression fits better after transforming
# the response. Score tests candidate lambdas: lambda = 1 means no transformation,
# lambda = 0 means take logs. The lambda whose score statistic is closest to zero
# is the best supported transformation.
#
# Run from the repository root:
#   julia --project=code/fsda_engine packages/FSDAjl/examples/score_example.jl

include(joinpath(@__DIR__, "..", "src", "engines", "engine.jl"))

using Printf

h = start_engine()

try
    W = eval_expr(h, "table2array(getfield(load('wool.mat'),'wool'))")
    @printf("wool: %d observations, %d columns\n\n", size(W, 1), size(W, 2))

    # 4:4 keeps this two dimensional. A 1-D vector would cross as a MATLAB row,
    # but Score expects the response as an (n, 1) column.
    y  = W[:, 4:4]
    X  = W[:, 1:3]
    la = [-1.0, -0.5, 0.0, 0.5, 1.0]

    out = call(h, "Score", y, X; la = la, intercept = true)
    @printf("Score returned a Dict with keys: %s\n\n",
            join(sort(collect(keys(out))), ", "))

    sc = vec(out["Score"])

    println("score test statistic per lambda")
    for (lam, s) in zip(la, sc)
        @printf("  lambda = %+4.1f    score = %9.4f\n", lam, s)
    end

    best = la[argmin(abs.(sc))]
    @printf("\nbest supported transformation: lambda = %+.1f\n", best)
    if best == 0.0
        println("lambda = 0 means the log transformation is preferred")
    end
finally
    stop_engine(h)
end
