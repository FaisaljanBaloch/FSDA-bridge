# Agreement check for the FSR example.
#
# Gold references produced by test/reference/generate_fsr_gold.m, which calls
# FSDA directly inside MATLAB with no bridge involved.
#
# The project defines agreement as same values, same flagged units, same
# structure, so this checks two things: the 100 minimum deletion residuals
# numerically at 1e-9, and the 42 flagged unit numbers exactly.
#
# FSR uses random subsampling on data this size, so the seed is fixed. If seed
# control did not survive the bridge, the flagged units would differ and this
# test would catch it.
#
# On a machine without MATLAB, Python or the venv, this skips rather than fails.

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

@testset "FSR agreement with FSDA" begin
    gold_mdr  = read_gold(joinpath(@__DIR__, "reference", "fsr_mdr_gold.csv"))
    gold_lout = read_gold(joinpath(@__DIR__, "reference", "fsr_listout_gold.csv"))
    @test length(gold_mdr) == 100
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
                out = call(h, "FSR", y, X; msg = 0, plots = 0)

                @test out isa Dict
                @test haskey(out, "mdr")
                @test haskey(out, "ListOut")

                mdr  = out["mdr"][:, 2]
                lout = vec(out["ListOut"])

                @test length(mdr) == length(gold_mdr)
                diff = maximum(abs.(mdr .- gold_mdr))
                println("FSR mdr max absolute difference: ", diff, "   tolerance: ", TOL)
                @test diff <= TOL

                # Flagged units are integers, so they must match exactly rather
                # than within a tolerance. This is the seed control check.
                @test length(lout) == length(gold_lout)
                println("FSR flagged units: ", length(lout), " expected ", length(gold_lout))
                @test Int.(lout) == Int.(gold_lout)
            finally
                stop_engine(h)
            end
        end
    end
end
