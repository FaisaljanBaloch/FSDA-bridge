# Spec 025 — Julia signature code generation

> Read `CONSTITUTION.md` first. This spec adds a static, completion-friendly
> facade to the existing generic Julia engine without changing output
> marshalling.

## Contract

- **Deliverable:** generated Julia wrappers for hardcoded `FSDABridge` routines
  that also have records in the supplied IR JSON file.
- **Done when:** generated routines expose their required positional and
  name-value inputs in Julia method signatures and forward only explicitly
  supplied name-value arguments; hardcoded routines without IR records retain
  the existing variadic facade.
- **Out of scope:** output-field completion, MATLAB type annotations in Julia
  dispatch, changing the generic engine, and generating wrappers for routines
  absent from the supplied IR JSON file.

## Design

- **Files:** `tools/codegen/gen_julia.py`,
  `packages/FSDAjl/src/generated/routines.jl`,
  `packages/FSDAjl/src/FSDABridge.jl`.
- **Input:** a caller-supplied IR JSON path; the generator reads the
  hardcoded `FSDA_ROUTINES` list from `FSDABridge.jl`.
- **Generated signatures:** `required` inputs are positional arguments;
  `namevalue` inputs are keyword arguments with an internal `_UNSET` sentinel.
  `nargout`, `echo_output`, and `options` remain explicit bridge controls.
- **Forwarding:** `_set_only` removes `_UNSET` keyword values before calling the
  existing generic `call` function. MATLAB remains authoritative for defaults.
- **Fallback:** routines in `FSDA_ROUTINES` with no IR record keep the existing
  `args...; kwargs...` facade and are not generated a second time.
- **Marshalling:** unchanged; generated wrappers call the existing engine.

## Tasks

- [x] #p1 Add the Julia wrapper generator driven by the supplied IR JSON and
  `FSDA_ROUTINES`.
- [x] #p1 Generate explicit wrappers for the currently intersecting routines.
- [x] #p1 Preserve the variadic fallback for routines without IR records.
- [x] #p2 Add generated docstrings containing the IR descriptions and inputs.
- [x] #p2 Validate generated Julia syntax and package loading.

### Done

- 2026-10-22 — Generated input signatures for the six routines currently
  covered by both the IR and `FSDA_ROUTINES`; output conversion remains
  unchanged.
- 2026-10-22 — Generated source parsed successfully and the Julia package test
  suite passed on Julia 1.13.1.
