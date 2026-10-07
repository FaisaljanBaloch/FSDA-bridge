# Agreement check for the FSMeda example.
#
# Gold references produced by test/reference/generate_fsmeda_gold.m.
#
# The starting subset is checked first and separately. It is derived by sorting
# unibiv scores, and if MATLAB and Julia ever ordered ties differently the
# subset would differ, the whole search would differ, and the failure would look
# like a numerical problem rather than an ordering one. Asserting the subset
# first makes that distinction visible.
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

@testset "FSMeda agreement with FSDA" begin
    gold_bsb = read_gold(joinpath(@__DIR__, "reference", "fsmeda_bsb_gold.csv"))
    gold_mmd = read_gold(joinpath(@__DIR__, "reference", "fsmeda_mmd_gold.csv"))
    @test length(gold_bsb) == 20
    @test length(gold_mmd) == 80

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
                ord = sortperm(fre[:, 4])
                bsb = reshape(fre[ord[1:20], 1], :, 1)

                # Unit numbers are integers, so exact equality, not a tolerance.
                println("FSMeda starting subset: ", Int.(vec(bsb)))
                @test Int.(vec(bsb)) == Int.(gold_bsb)

                out = call(h, "FSMeda", Y, bsb; plots = 0)
                @test out isa Dict
                @test haskey(out, "mmd")
                @test haskey(out, "MAL")

                mmd = out["mmd"][:, 2]
                MAL = out["MAL"]

                @test size(MAL) == (200, 81)
                @test length(mmd) == length(gold_mmd)

                diff = maximum(abs.(mmd .- gold_mmd))
                println("FSMeda mmd max absolute difference: ", diff, "   tolerance: ", TOL)
                @test diff <= TOL
            finally
                stop_engine(h)
            end
        end
    end
end
