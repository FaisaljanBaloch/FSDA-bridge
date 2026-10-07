# Agreement check for the LXS example.
#
# Gold references produced by test/reference/generate_lxs_gold.m, which ran LXS
# twice under a fixed seed and refused to write unless both runs agreed.
#
# Three things checked: the nine coefficients, the 128 residuals, and the
# outlier unit numbers exactly.
#
# Skips rather than fails when MATLAB is unavailable.

using Test

const TOL = 1e-9
const ENGINE = joinpath(@__DIR__, "..", "src", "engines", "engine.jl")

read_gold(path) =
    [parse(Float64, strip(l)) for l in eachline(path) if !isempty(strip(l))]

engine_loaded = try
    include(ENGINE)
    true
catch err
    @info "engine.jl could not load, skipping MATLAB dependent tests" err
    false
end

@testset "LXS agreement with FSDA" begin
    gold_beta = read_gold(joinpath(@__DIR__, "reference", "lxs_beta_gold.csv"))
    gold_res  = read_gold(joinpath(@__DIR__, "reference", "lxs_residuals_gold.csv"))
    gold_lout = read_gold(joinpath(@__DIR__, "reference", "lxs_outliers_gold.csv"))
    @test length(gold_beta) == 9
    @test length(gold_res) == 128
    @test length(gold_lout) == 42

    if !engine_loaded
        @info "skipped: no engine"
    else
        h = try
            start_engine()
        catch err
            @info "MATLAB session would not start, skipping" err
            nothing
        end

        if h === nothing
            @info "skipped: no MATLAB"
        else
            try
                D = eval_expr(h, "table2array(getfield(load('hawkins.mat'),'hawkins'))")
                y = D[:, 9:9]
                X = D[:, 1:8]

                call(h, "rng", 1234, nargout = 0)
                out = call(h, "LXS", y, X; msg = 0)

                @test out isa Dict
                for k in ("beta", "residuals", "outliers")
                    @test haskey(out, k)
                end

                beta = vec(out["beta"])
                res  = vec(out["residuals"])
                lout = vec(out["outliers"])

                d1 = maximum(abs.(beta .- gold_beta))
                println("LXS coefficients max difference: ", d1, "   tolerance: ", TOL)
                @test d1 <= TOL

                @test length(res) == length(gold_res)
                d2 = maximum(abs.(res .- gold_res))
                println("LXS residuals max difference: ", d2, "   tolerance: ", TOL)
                @test d2 <= TOL

                println("LXS outliers: ", length(lout), " expected ", length(gold_lout))
                @test Int.(lout) == Int.(gold_lout)
            finally
                stop_engine(h)
            end
        end
    end
end
