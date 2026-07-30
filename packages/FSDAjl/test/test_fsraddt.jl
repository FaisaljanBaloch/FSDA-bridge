# Agreement check for the FSRaddt example.
#
# Gold reference produced by test/reference/generate_fsraddt_gold.m, which ran
# FSRaddt twice under a fixed seed and refused to write unless both runs agreed.
#
# Tdel is 48 by 4 and the gold is Tdel(:), flattened column major. Julia's vec()
# flattens the same way, so the two line up element for element. The shape is
# asserted first, since a wrong shape would misalign the comparison rather than
# fail honestly.
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

@testset "FSRaddt agreement with FSDA" begin
    gold = read_gold(joinpath(@__DIR__, "reference", "fsraddt_tdel_gold.csv"))
    @test length(gold) == 192

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
                D = eval_expr(h, "table2array(getfield(load('multiple_regression.mat'),'multiple_regression'))")
                y = D[:, 4:4]
                X = D[:, 1:3]

                call(h, "rng", 1234, nargout = 0)
                out = call(h, "FSRaddt", y, X; msg = 0, plots = 0)

                @test out isa Dict
                @test haskey(out, "Tdel")

                Tdel = out["Tdel"]
                @test size(Tdel) == (48, 4)

                flat = vec(Tdel)
                @test length(flat) == length(gold)

                diff = maximum(abs.(flat .- gold))
                println("FSRaddt Tdel max difference: ", diff, "   tolerance: ", TOL)
                @test diff <= TOL

                # Column 1 is the subset size, so it must be exact integers
                # running consecutively.
                @test all(Tdel[:, 1] .== round.(Tdel[:, 1]))
                @test Int.(Tdel[:, 1]) == collect(13:60)
            finally
                stop_engine(h)
            end
        end
    end
end
