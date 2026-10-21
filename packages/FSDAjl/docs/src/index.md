# FSDABridge.jl

FSDABridge.jl lets you call the MATLAB [FSDA toolbox](https://github.com/UniprJRC/FSDA) from Julia through a thin wrapper over [FSDA-bridge](https://github.com/UniprJRC/FSDA-bridge)'s generic Python engine.

FSDA itself runs inside MATLAB at call time. FSDABridge.jl does not reimplement the statistical routines; it passes data to FSDA and returns the results as Julia values.

## Requirements

Before installing, make sure you have:

- MATLAB installed and licensed, with the FSDA Add-On installed and available on the MATLAB path.
- A Python environment with `numpy` and a `matlabengine` release matching your MATLAB version (for example, `matlabengine==26.1.*` for MATLAB R2026a).
- Julia with the package dependencies available.

**FSDABridge.jl can be installed without MATLAB**, but calls into FSDA will fail until MATLAB, FSDA, and the matching MATLAB Engine API for Python are configured.

MATLAB and the MATLAB Engine API for Python are proprietary MathWorks software and are not distributed with this package; see [THIRD_PARTY_NOTICE.md](https://github.com/UniprJRC/FSDA-bridge/blob/main/packages/FSDAjl/THIRD_PARTY_NOTICE.md).

## Install matrix

| MATLAB release | Required `matlabengine` |
| -------------- | ----------------------- |
| R2026a         | `matlabengine==26.1.*`  |

Match `matlabengine` to your installed MATLAB release; do not assume the example version applies to every MATLAB release.

## Installation

```julia
using Pkg
Pkg.add("FSDABridge")
```

## Configure PythonCall

FSDABridge.jl uses [PythonCall.jl](https://github.com/JuliaPy/PythonCall.jl) to call the existing Python environment. Configure PythonCall to use the virtual environment above instead of provisioning its own Python through Conda: Conda cannot install MATLAB's `matlabengine` package.

```bash
export JULIA_CONDAPKG_BACKEND=Null
export FSDA_DEV_VENV=/path/to/your/venv/bin/python
export JULIA_PYTHONCALL_EXE=/path/to/your/venv/bin/python
```

Set these **before** starting Julia / loading the package. FSDABridge.jl checks `JULIA_CONDAPKG_BACKEND` at load time and will warn loudly if it isn't set to `"Null"`.

## A first call

The first call starts the MATLAB engine automatically. Call `stop_engine()` when you are finished to shut it down.

```julia
using FSDABridge
using Statistics

Y = [ 0.52 -1.10;  1.83  0.14; -0.09  1.53;  0.32 -0.77;  1.10  0.37;
     -0.86  0.26;  0.15 -1.44;  0.79  0.33; -1.21  0.71;  0.46 -0.05]

μ = median(Y, dims = 1)
Σ = [0.3 0.4; 0.4 1.0]

d = mahalFS(Y, μ, Σ)

stop_engine()
```

## Quick start: explicit engine

You can also manage the MATLAB engine explicitly and reuse it across calls:

```julia
using FSDABridge
using Statistics

h = FSDABridge.start_engine()

Y = randn(10, 2)
MU = median(Y, dims = 1)
SIGMA = [0.3 0.4; 0.4 1.0]

d = FSDABridge.call(h, "mahalFS", Y, MU, SIGMA)

FSDABridge.stop_engine(h)
```

## Reaching MATLAB directly

FSDA routines are called by name, as above. For anything else in MATLAB, such
as loading a dataset or seeding the random number generator, use `eval_expr`
and `call`. Both use the same engine, so nothing extra needs starting.

```julia
Y = eval_expr("table2array(getfield(load('geyser2.mat'),'geyser2'))")
call("rng", 1234, nargout = 0)
```

## Examples

Every function has a page of its own, listed in the sidebar. Each gives the
input arguments, a worked example with its output, and links to the
corresponding page of the FSDA documentation.

## License

[EUPL-1.2](https://github.com/UniprJRC/FSDA-bridge/blob/main/packages/FSDAjl/LICENSE), consistent with FSDA's own licensing.
