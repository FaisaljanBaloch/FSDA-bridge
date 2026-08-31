# Agreement check for the tclust example.
#
# Gold references produced by test/reference/generate_tclust_gold.m.
#
# tclust uses random starts. The project allows a structural check for
# stochastic routines, but seed control has already been shown to survive the
# bridge, and the gold generator verified reproducibility by running tclust
# twice inside MATLAB and refusing to write unless both runs agreed. So this
# checks exact agreement rather than settling for structure.
#
# Cluster labels are integers and must match exactly. Centroids are continuous
# and are compared at 1e-9.
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

@testset "tclust agreement with FSDA" begin
    gold_idx = read_gold(joinpath(@__DIR__, "reference", "tclust_idx_gold.csv"))
    gold_mu  = read_gold(joinpath(@__DIR__, "reference", "tclust_mu_gold.csv"))
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
                out = call(h, "tclust", Y, 3, 0.1, 12; msg = 0, plots = 0)

                @test out isa Dict
                @test haskey(out, "idx")
                @test haskey(out, "muopt")

                idx = Int.(vec(out["idx"]))
                mu  = out["muopt"]

                # Labels are integers. Exact equality, and this is also the
                # seed control check: a different random start would reassign units.
                @test length(idx) == length(gold_idx)
                println("tclust trimmed: ", count(==(0), idx),
                        "   expected ", count(==(0), Int.(gold_idx)))
                @test idx == Int.(gold_idx)

                @test size(mu) == (3, 2)
                diff = maximum(abs.(vec(mu) .- gold_mu))
                println("tclust centroid max difference: ", diff, "   tolerance: ", TOL)
                @test diff <= TOL
            finally
                stop_engine(h)
            end
        end
    end
end
