# unibiv: univariate and bivariate outlier detection on the Swiss banknotes data.
#
# unibiv examines each variable on its own using robust boxplot limits, and each
# pair of variables together using robust confidence ellipses. For every unit it
# reports how often that unit fell outside those limits, and an overall score.
#
# Method: Riani, M. and Zani, S. (1997), "An iterative method for the detection
# of multivariate outliers", Metron, Vol. LV, pp. 101-117.
#
# The score is often used to choose a clean starting subset for the forward
# search, which is how the FSMeda example uses it.
#
# Run from the repository root:
#   julia --project=code/fsda_engine packages/FSDAjl/examples/unibiv_example.jl

include(joinpath(@__DIR__, "..", "src", "engines", "engine.jl"))

using Printf

h = start_engine()

try
    Y = eval_expr(h, "table2array(getfield(load('swiss_banknotes.mat'),'swiss_banknotes'))")
    @printf("swiss_banknotes: %d observations, %d variables\n\n", size(Y, 1), size(Y, 2))

    # A numeric matrix crosses back as a Julia Matrix, one row per observation.
    #   column 1: unit index
    #   column 2: times declared a univariate outlier
    #   column 3: times declared a bivariate outlier
    #   column 4: pseudo Mahalanobis distance, the sum of bivariate distances
    fre = call(h, "unibiv", Y)
    @printf("unibiv returned a %s of size %s\n\n", typeof(fre), size(fre))

    # Column 1 holds MATLAB unit numbers, already 1 based, so they are used as is.
    ord = sortperm(fre[:, 4], rev = true)

    println("ten most unusual banknotes")
    println("   unit   univariate   bivariate   pseudo MD")
    for i in ord[1:10]
        @printf("  %5d  %11d  %10d  %10.4f\n",
                Int(fre[i, 1]), Int(fre[i, 2]), Int(fre[i, 3]), fre[i, 4])
    end

    nuni = count(>(0), fre[:, 2])
    nbiv = count(>(0), fre[:, 3])
    @printf("\n%d units flagged at least once univariately, %d bivariately\n", nuni, nbiv)

    # The lowest scoring units are the most typical, and make a natural clean
    # starting subset for a forward search.
    least = sortperm(fre[:, 4])[1:20]
    print("\ntwenty most typical units, a natural starting subset:\n  ")
    for u in least
        @printf("%d ", Int(fre[u, 1]))
    end
    println()
finally
    stop_engine(h)
end
