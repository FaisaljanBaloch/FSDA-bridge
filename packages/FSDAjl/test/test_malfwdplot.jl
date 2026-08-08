# Agreement check for the malfwdplot example.
#
# malfwdplot returns no data, so what is verified is the matrix it draws plus
# the fact that the call succeeds. The MAL matrix is 200 by 81, 16,200 values.
# Storing all of them would put a 400 KB file inside a package headed for a
# public registry, and mmd from the same computation is already fully checked by
# the FSMeda test. So the gold holds the final column, 200 values, and the shape
# is asserted separately.
#
# The whole chain runs inside the MATLAB workspace. A struct cannot currently be
# passed from Julia into MATLAB, so the example uses eval_expr throughout. This
# test exercises that same route, which is the point.
#
# Tolerance is 1e-9. Skips rather than fails when MATLAB is unavailable.

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

@testset "malfwdplot agreement with FSDA" begin
    gold = read_gold(joinpath(@__DIR__, "reference", "malfwdplot_final_gold.csv"))
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
                eval_expr(h, "Y = table2array(getfield(load('swiss_banknotes.mat'),'swiss_banknotes'));",
                          nargout = 0)
                eval_expr(h, "fre = sortrows(unibiv(Y),4); bsb = fre(1:20,1);", nargout = 0)
                eval_expr(h, "outEDA = FSMeda(Y, bsb, 'plots', 0);", nargout = 0)

                # If this throws, the workspace route has stopped working.
                eval_expr(h, "malfwdplot(outEDA);", nargout = 0)
                @test true

                MAL = eval_expr(h, "outEDA.MAL")
                @test MAL isa AbstractMatrix
                @test size(MAL) == (200, 81)

                final = MAL[:, end]
                @test length(final) == length(gold)

                diff = maximum(abs.(final .- gold))
                println("malfwdplot MAL final column max difference: ", diff,
                        "   tolerance: ", TOL)
                @test diff <= TOL

                # Close the figure so repeated test runs do not pile up windows.
                eval_expr(h, "close all", nargout = 0)
            finally
                stop_engine(h)
            end
        end
    end
end
