# Agreement check for the mahalFS example.
#
# Gold reference produced by test/reference/generate_mahalfs_gold.m, which calls
# FSDA directly inside MATLAB with no bridge involved. Comparing against it
# tests the bridge rather than testing the bridge against itself.
#
# Tolerance is 1e-9, the project wide agreement gate.
#
# On a machine without MATLAB, Python or the venv, this skips rather than fails.

using Test

const TOL = 1e-9
const ENGINE = joinpath(@__DIR__, "..", "src", "engines", "engine.jl")

read_gold(path) =
    [parse(Float64, strip(l)) for l in eachline(path) if !isempty(strip(l))]

# engine.jl reaches into Python the moment it loads, so loading it is itself the
# availability test. A failure here means no MATLAB stack, which is a skip.
engine_loaded = try
    include(ENGINE)
    true
catch err
    @info "engine.jl could not load, skipping MATLAB dependent tests" err
    false
end

@testset "mahalFS agreement with FSDA" begin
    gold = read_gold(joinpath(@__DIR__, "reference", "mahalfs_gold.csv"))
    @test length(gold) == 200

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
                n = size(Y, 1)
                MU    = sum(Y, dims = 1) ./ n
                Yc    = Y .- MU
                SIGMA = (Yc' * Yc) ./ (n - 1)

                d = vec(call(h, "mahalFS", Y, MU, SIGMA))

                @test length(d) == length(gold)
                diff = maximum(abs.(d .- gold))
                println("mahalFS max absolute difference: ", diff, "   tolerance: ", TOL)
                @test diff <= TOL
            finally
                stop_engine(h)
            end
        end
    end
end
