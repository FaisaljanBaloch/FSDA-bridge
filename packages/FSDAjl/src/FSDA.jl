module FSDA

const _ENGINE_DIR = joinpath(@__DIR__, "engines")# absolute path to the engine directory

# Load the engine module
include(joinpath(_ENGINE_DIR, "engine.jl"))

# CondaPkg guard
function __init__()
    conda_backend = get(ENV, "JULIA_CONDAPKG_BACKEND", "unset")
    if conda_backend != "Null"
        @warn """
        JULIA_CONDAPKG_BACKEND is set to '$(conda_backend)' (expected 'Null').
        PythonCall might silently try to provision its own Python via Conda, 
        which will NOT include the matlabengine.
        Please set `export JULIA_CONDAPKG_BACKEND=Null` before starting Julia.
        """
    end
end

# Re-export the mandatory API
export start_engine, call, eval_expr, stop_engine

end
