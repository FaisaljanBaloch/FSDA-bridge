# Check for the yXplot example.
#
# This test is deliberately different from the other fifteen, and it is worth
# being explicit about why rather than implying more than it does.
#
# yXplot returns no data. There is nothing to compare against a reference, so
# there is no 1e-9 agreement gate here. What is verified instead:
#
#   1. the data crosses the bridge unchanged, checked against a gold copy of
#      the response vector recorded in MATLAB
#   2. the call succeeds without error
#   3. it returns nothing, meaning no graphics handle was marshalled, which is
#      the contract in CONSTITUTION.md section 4
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

@testset "yXplot graphics contract" begin
    gold_y = read_gold(joinpath(@__DIR__, "reference", "yxplot_y_gold.csv"))
    @test length(gold_y) == 21

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
                D = eval_expr(h, "table2array(getfield(load('stack_loss.mat'),'stack_loss'))")
                y = D[:, 4:4]
                X = D[:, 1:3]

                # 1. the data itself crossed unchanged
                d = maximum(abs.(vec(y) .- gold_y))
                println("yXplot input data max difference: ", d, "   tolerance: ", TOL)
                @test d <= TOL

                # 2 and 3. the call succeeds and returns nothing
                result = call(h, "yXplot", y, X; nargout = 0)
                println("yXplot returned: ",
                        result === nothing ? "nothing" : string(typeof(result)))
                @test result === nothing

                eval_expr(h, "close all", nargout = 0)
            finally
                stop_engine(h)
            end
        end
    end
end
