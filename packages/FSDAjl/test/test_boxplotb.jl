# Agreement check for the boxplotb example.
#
# Gold references produced by test/reference/generate_boxplotb_gold.m.
#
# Spl is 16000 by 4. Its shape is asserted rather than its 64,000 values, for
# the same reason as MAL in the malfwdplot test: a large data file inside a
# package headed for a public registry is disproportionate when the centre and
# the outlier list already pin the result down.
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

@testset "boxplotb agreement with FSDA" begin
    gold_cent = read_gold(joinpath(@__DIR__, "reference", "boxplotb_cent_gold.csv"))
    gold_lout = read_gold(joinpath(@__DIR__, "reference", "boxplotb_outliers_gold.csv"))
    @test length(gold_cent) == 2
    @test length(gold_lout) == 10

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
                Y2 = Y[:, [4, 6]]

                out = call(h, "boxplotb", Y2)
                @test out isa Dict
                for k in ("cent", "Spl", "outliers")
                    @test haskey(out, k)
                end

                cent = vec(out["cent"])
                Spl  = out["Spl"]
                lout = vec(out["outliers"])

                d = maximum(abs.(cent .- gold_cent))
                println("boxplotb centre max difference: ", d, "   tolerance: ", TOL)
                @test d <= TOL

                @test size(Spl) == (16000, 4)

                println("boxplotb outliers: ", length(lout), " expected ", length(gold_lout))
                @test Int.(lout) == Int.(gold_lout)

                eval_expr(h, "close all", nargout = 0)
            finally
                stop_engine(h)
            end
        end
    end
end
