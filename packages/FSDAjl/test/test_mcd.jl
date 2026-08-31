# Agreement check for the mcd example.
#
# Gold references produced by test/reference/generate_mcd_gold.m, which ran mcd
# twice under a fixed seed and refused to write unless both runs agreed.
#
# Four things checked: robust centroid, the full 6 by 6 robust covariance,
# the 200 robust distances, and the outlier unit numbers exactly.
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

@testset "mcd agreement with FSDA" begin
    gold_loc  = read_gold(joinpath(@__DIR__, "reference", "mcd_loc_gold.csv"))
    gold_cov  = read_gold(joinpath(@__DIR__, "reference", "mcd_cov_gold.csv"))
    gold_md   = read_gold(joinpath(@__DIR__, "reference", "mcd_md_gold.csv"))
    gold_lout = read_gold(joinpath(@__DIR__, "reference", "mcd_outliers_gold.csv"))
    @test length(gold_loc) == 6
    @test length(gold_cov) == 36
    @test length(gold_md) == 200
    @test length(gold_lout) == 22

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
                Y = eval_expr(h, "table2array(getfield(load('swiss_banknotes.mat'),'swiss_banknotes'))")

                call(h, "rng", 1234, nargout = 0)
                out = call(h, "mcd", Y; msg = 0, plots = 0)

                @test out isa Dict
                for k in ("loc", "cov", "md", "outliers")
                    @test haskey(out, k)
                end

                loc  = vec(out["loc"])
                cv   = out["cov"]
                md   = vec(out["md"])
                lout = vec(out["outliers"])

                d1 = maximum(abs.(loc .- gold_loc))
                println("mcd centroid max difference: ", d1, "   tolerance: ", TOL)
                @test d1 <= TOL

                @test size(cv) == (6, 6)
                d2 = maximum(abs.(vec(cv) .- gold_cov))
                println("mcd covariance max difference: ", d2, "   tolerance: ", TOL)
                @test d2 <= TOL

                @test length(md) == length(gold_md)
                d3 = maximum(abs.(md .- gold_md))
                println("mcd distances max difference: ", d3, "   tolerance: ", TOL)
                @test d3 <= TOL

                println("mcd outliers: ", length(lout), " expected ", length(gold_lout))
                @test Int.(lout) == Int.(gold_lout)
            finally
                stop_engine(h)
            end
        end
    end
end
