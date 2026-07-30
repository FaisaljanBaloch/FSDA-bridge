# Agreement check for the FSRfan example.
#
# Gold reference produced by test/reference/generate_fsrfan_gold.m, which ran
# FSRfan twice under a fixed seed and refused to write unless both runs agreed.
#
# Score is 23 by 6 and the gold is Score(:), flattened column major, so Julia's
# vec() lines up element for element. Shape is asserted first.
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

@testset "FSRfan agreement with FSDA" begin
    gold = read_gold(joinpath(@__DIR__, "reference", "fsrfan_score_gold.csv"))
    @test length(gold) == 138

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
                W = eval_expr(h, "table2array(getfield(load('wool.mat'),'wool'))")
                y  = W[:, 4:4]
                X  = W[:, 1:3]
                la = [-1.0, -0.5, 0.0, 0.5, 1.0]

                call(h, "rng", 1234, nargout = 0)
                out = call(h, "FSRfan", y, X; la = la, msg = 0, plots = 0)

                @test out isa Dict
                @test haskey(out, "Score")

                Sc = out["Score"]
                @test size(Sc) == (23, 6)

                flat = vec(Sc)
                @test length(flat) == length(gold)

                diff = maximum(abs.(flat .- gold))
                println("FSRfan Score max difference: ", diff, "   tolerance: ", TOL)
                @test diff <= TOL

                # Column 1 is the subset size, exact integers 5 to 27.
                @test Int.(Sc[:, 1]) == collect(5:27)
            finally
                stop_engine(h)
            end
        end
    end
end
