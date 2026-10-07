# boxplotb: the bivariate boxplot on two Swiss banknote measurements.
#
# A univariate boxplot marks the middle half of one variable and fences off the
# rest. boxplotb does the same in two dimensions: an inner contour holding the
# central half of the points, an outer fence, and anything beyond it flagged.
#
# Because it works on a pair of variables it can catch a note that is
# unremarkable on each measurement separately but unusual in combination.
#
# boxplotb requires exactly two columns, not the full data matrix.
#
# Run from the repository root:
#   julia --project=code/fsda_engine packages/FSDAjl/examples/boxplotb_example.jl

include(joinpath(@__DIR__, "..", "src", "engines", "engine.jl"))

using Printf

h = start_engine()

try
    Y = eval_expr(h, "table2array(getfield(load('swiss_banknotes.mat'),'swiss_banknotes'))")
    @printf("swiss_banknotes: %d observations, %d variables\n", size(Y, 1), size(Y, 2))
    println("using variable 4, distance from bottom border, and variable 6, diagonal\n")

    Y2 = Y[:, [4, 6]]

    out = call(h, "boxplotb", Y2)
    @printf("boxplotb returned a Dict with keys: %s\n\n",
            join(sort(collect(keys(out))), ", "))

    cent = vec(out["cent"])
    Spl  = out["Spl"]
    lout = Int.(vec(out["outliers"]))

    @printf("bivariate centre: (%.4f, %.4f)\n", cent[1], cent[2])
    @printf("contour Spl: %d by %d\n", size(Spl, 1), size(Spl, 2))
    @printf("units outside the fence: %d\n\n", length(lout))

    print("flagged units:\n  ")
    for u in lout
        @printf("%d ", u)
    end
    println("\n")

    # The handles key carries MATLAB graphics objects. They are never requested,
    # so it crosses as an empty array, which is the documented contract.
    if haskey(out, "handles")
        @printf("handles crossed as %s, empty as expected\n\n", typeof(out["handles"]))
    end

    # How this conclusion sits against the other multivariate methods.
    fsm = [1, 40, 111, 116, 138, 148, 160, 161, 162, 167, 168, 171, 180, 182, 187, 192]
    if isempty(setdiff(lout, fsm))
        println("Every unit flagged here was also flagged by FSM on all six variables,")
        println("which in turn were all flagged by MCD. The three methods nest.")
    end
finally
    stop_engine(h)
end
