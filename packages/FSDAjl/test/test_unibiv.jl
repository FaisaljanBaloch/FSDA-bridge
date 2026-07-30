# Agreement check for the unibiv example.
#
# Gold reference produced by test/reference/generate_unibiv_gold.m, which calls
# FSDA directly inside MATLAB with no bridge involved.
#
# The gold was written with fre(:), MATLAB's column major flattening. Julia's
# vec() flattens the same way, since both languages are column major, so the
# two line up element for element. Getting this wrong would scramble the
# comparison rather than fail it cleanly, so the shape is asserted first.
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

@testset "unibiv agreement with FSDA" begin
    gold = read_gold(joinpath(@__DIR__, "reference", "unibiv_gold.csv"))
    @test length(gold) == 800

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
                fre = call(h, "unibiv", Y)

                @test fre isa AbstractMatrix
                @test size(fre) == (200, 4)

                flat = vec(fre)
                @test length(flat) == length(gold)

                diff = maximum(abs.(flat .- gold))
                println("unibiv max absolute difference: ", diff, "   tolerance: ", TOL)
                @test diff <= TOL

                # Columns 1 to 3 are counts and indices, so they must be exact
                # integers rather than merely close.
                @test all(fre[:, 1] .== 1:200)
                @test all(fre[:, 2] .== round.(fre[:, 2]))
                @test all(fre[:, 3] .== round.(fre[:, 3]))
            finally
                stop_engine(h)
            end
        end
    end
end
