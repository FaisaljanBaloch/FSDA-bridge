# Agreement check for the FSM example.
#
# Gold references produced by test/reference/generate_fsm_gold.m, which ran FSM
# twice under a fixed seed and refused to write unless both runs agreed.
#
# Three things are checked: the monitored distances numerically, the outlier
# unit numbers exactly, and the robust centroid numerically.
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

@testset "FSM agreement with FSDA" begin
    gold_mmd  = read_gold(joinpath(@__DIR__, "reference", "fsm_mmd_gold.csv"))
    gold_lout = read_gold(joinpath(@__DIR__, "reference", "fsm_outliers_gold.csv"))
    gold_loc  = read_gold(joinpath(@__DIR__, "reference", "fsm_loc_gold.csv"))
    @test length(gold_mmd) == 80
    @test length(gold_lout) == 16
    @test length(gold_loc) == 6

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
                out = call(h, "FSM", Y; plots = 0, msg = 0)

                @test out isa Dict
                @test haskey(out, "mmd")
                @test haskey(out, "outliers")
                @test haskey(out, "loc")

                mmd  = out["mmd"][:, 2]
                lout = vec(out["outliers"])
                loc  = vec(out["loc"])

                @test length(mmd) == length(gold_mmd)
                d1 = maximum(abs.(mmd .- gold_mmd))
                println("FSM mmd max difference: ", d1, "   tolerance: ", TOL)
                @test d1 <= TOL

                # Unit numbers are integers, so exact equality rather than a tolerance.
                println("FSM outliers: ", length(lout), " expected ", length(gold_lout))
                @test Int.(lout) == Int.(gold_lout)

                @test length(loc) == length(gold_loc)
                d2 = maximum(abs.(loc .- gold_loc))
                println("FSM robust centroid max difference: ", d2, "   tolerance: ", TOL)
                @test d2 <= TOL
            finally
                stop_engine(h)
            end
        end
    end
end
