module FSDA

const _ENGINE_DIR = joinpath(@__DIR__, "engines")

# Load the engine module
include(joinpath(_ENGINE_DIR, "engine.jl"))

function __init__()
    conda_backend = get(ENV, "JULIA_CONDAPKG_BACKEND", "unset")
    if conda_backend != "Null"
        @warn """
        JULIA_CONDAPKG_BACKEND is set to '$(conda_backend)' (expected 'Null').
        PythonCall has likely already provisioned its own Python via Conda, 
        which will NOT include the matlabengine.
        
        To prevent this on your next run, set the environment variable before starting Julia:
        - Mac/Linux:        export JULIA_CONDAPKG_BACKEND=Null
        - Windows (CMD):    set JULIA_CONDAPKG_BACKEND=Null
        - Windows (PS):     \$env:JULIA_CONDAPKG_BACKEND="Null"
        """
    end
end


# We need a global reference to store the engine, otherwise users would 
# have to pass the handle to every routine.
const _GLOBAL_ENGINE = Ref{Any}(nothing)

"""
    start_global_engine(; kwargs...)

Starts the FSDA engine and stores it globally so routine wrappers can use it automatically.
"""
function start_global_engine(; kwargs...)
    _GLOBAL_ENGINE[] = start_engine(; kwargs...)
    return _GLOBAL_ENGINE[]
end

"""
    stop_global_engine()

Stops the global FSDA engine if it is running.
"""
function stop_global_engine()
    if _GLOBAL_ENGINE[] !== nothing
        stop_engine(_GLOBAL_ENGINE[])
        _GLOBAL_ENGINE[] = nothing
    end
end

# Re-export the mandatory API
export start_engine, call, eval_expr, stop_engine, start_global_engine, stop_global_engine

# List of FSDA routines we want to wrap automatically.
# Add any new routine name here and Julia will create the function and export it.
const FSDA_ROUTINES = [
    :mahalFS,
    :Score,
    :FSR,
    :FSRaddt,
    :tclust,
    :getYahoo
]

# Generate the facade functions dynamically at compile time
for routine in FSDA_ROUTINES
    @eval begin
        function $routine(args...; kwargs...)
            if _GLOBAL_ENGINE[] === nothing
                error("Engine not started. Call `FSDA.start_global_engine()` first.")
            end
            return call(_GLOBAL_ENGINE[], $(string(routine)), args...; kwargs...)
        end
        export $routine
    end
end

end
