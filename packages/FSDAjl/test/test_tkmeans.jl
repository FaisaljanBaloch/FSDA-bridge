# Agreement check for the tkmeans example.
#
# Gold references produced by test/reference/generate_tkmeans_gold.m, which ran
# tkmeans twice under the same seed and refused to write unless both runs agreed.
#
# Cluster labels are integers and must match exactly, which is also the seed
# control check. Centroids are continuous and compared at 1e-9.
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

@testset "tkmeans agreement with FSDA" begin
    gold_idx = read_gold(joinpath(@__DIR__, "reference", "tkmeans_idx_gold.csv"))
    gold_mu  = read_gold(joinpath(@__DIR__, "reference", "tkmeans_mu_gold.csv"))
    @test length(gold_idx) == 271
    @test length(gold_mu) == 6

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
                Y = eval_expr(h, "table2array(getfield(load('geyser2.mat'),'geyser2'))")

                call(h, "rng", 1234, nargout = 0)
                out = call(h, "tkmeans", Y, 3, 0.1; msg = 0, plots = 0)

                @test out isa Dict
                @test haskey(out, "idx")
                @test haskey(out, "muopt")

                idx = Int.(vec(out["idx"]))
                mu  = out["muopt"]

                @test length(idx) == length(gold_idx)
                println("tkmeans trimmed: ", count(==(0), idx),
                        "   expected ", count(==(0), Int.(gold_idx)))
                @test idx == Int.(gold_idx)

                @test size(mu) == (3, 2)
                diff = maximum(abs.(vec(mu) .- gold_mu))
                println("tkmeans centroid max difference: ", diff, "   tolerance: ", TOL)
                @test diff <= TOL
            finally
                stop_engine(h)
            end
        end
    end
end
