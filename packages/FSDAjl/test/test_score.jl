# Agreement check for the Score example.
#
# Gold reference produced by test/reference/generate_score_gold.m, which calls
# FSDA directly inside MATLAB with no bridge involved.
#
# Tolerance is 1e-9, the project wide agreement gate.
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

@testset "Score agreement with FSDA" begin
    gold = read_gold(joinpath(@__DIR__, "reference", "score_gold.csv"))
    @test length(gold) == 5

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
                W  = eval_expr(h, "table2array(getfield(load('wool.mat'),'wool'))")
                y  = W[:, 4:4]
                X  = W[:, 1:3]
                la = [-1.0, -0.5, 0.0, 0.5, 1.0]

                out = call(h, "Score", y, X; la = la, intercept = true)
                @test out isa Dict
                @test haskey(out, "Score")

                sc = vec(out["Score"])
                @test length(sc) == length(gold)

                diff = maximum(abs.(sc .- gold))
                println("Score max absolute difference: ", diff, "   tolerance: ", TOL)
                @test diff <= TOL
            finally
                stop_engine(h)
            end
        end
    end
end
