module FSDA

const _ENGINE_DIR = joinpath(@__DIR__, "engines")# absolute path to the engine directory

# Load the engine module
include(joinpath(_ENGINE_DIR, "engine.jl"))

# Re-export the mandatory API
export start_engine, call, eval_expr, stop_engine

end
