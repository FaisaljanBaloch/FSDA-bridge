"""pyfsda example: interactive Forward-Search *persistent brushing* of residual trajectories.

Port of the FSDA MATLAB example
"MR: Forward EDA persistent brushing with other options":

    load('multiple_regression.txt')
    y = multiple_regression(:,4);  X = multiple_regression(:,1:3);
    out = LXS(y, X, 'nsamp', 10000);          % LMS from 10000 subsamples
    out = FSReda(y, X, out.bs);               % Forward Search, monitor residuals
    out1 = out;  out1.RES = out.RES.^2;       % scaled *squared* residuals
    ... build fground / databrush structs ...
    resfwdplot(out1, 'fground', fground, 'databrush', databrush);

Why this example is driven through the MATLAB *workspace* (``eng.eval``) instead of the
usual ``pyfsda.<name>(...)`` calls:

  * The Forward-Search result ``out`` (from ``FSReda``) is a rich MATLAB struct that
    ``resfwdplot`` reads field by field. Marshalling it out to a Python dict and back
    would be lossy and fragile.
  * ``fground`` and ``databrush`` are MATLAB *structs* with cell-array fields. The engine
    marshals Python -> MATLAB for numbers / arrays / strings, but not ``dict`` -> struct,
    so these option structs are built MATLAB-side.
  * ``resfwdplot`` is an interactive *graphics* routine. Per the bridge contract, plots
    run MATLAB-side (``nargout=0``) and their handles are never marshalled to Python.

So every struct stays in the MATLAB workspace and Python only orchestrates. The shared
engine (``pyfsda.start()``) plus its ``eval`` / ``render_figures`` / ``wait_for_figures``
helpers are all that is needed; brushing is done with the mouse on the live MATLAB figure.

Run (opens a MATLAB figure; needs the FSDA Add-On):

    python examples/resfwdplot_brush_example.py

Then rubber-band (Rect) select residual trajectories; with ``persist='on'`` you can brush
repeatedly and the selections/labels accumulate. Close the figure window(s) to finish.
"""
import sys

import pyfsda

# Start the shared engine quietly (skip the network / Add-On version checks for a clean demo).
eng = pyfsda.start(check_version=False)


def run(matlab_code: str) -> None:
    """Execute MATLAB statement(s) in the engine's workspace (nargout=0)."""
    eng.eval(matlab_code, nargout=0)


# --- 1. data: y = 4th column, X = first three columns of the FSDA dataset --------------
run("load('multiple_regression.txt');"
    "y = multiple_regression(:,4);"
    "X = multiple_regression(:,1:3);")

# --- 2. robust fit (LMS) + Forward Search ----------------------------------------------
run("rng(1000);")                          # reproducible demo (the MATLAB example sets no seed)
run("out = LXS(y, X, 'nsamp', 10000);")    # least median of squares from 10000 subsamples
run("out = FSReda(y, X, out.bs);")         # monitor residuals along the forward search
run("out1 = out; out1.RES = out.RES.^2;")  # scaled *squared* residuals

# --- 3. foreground trajectory styling (struct built MATLAB-side) -----------------------
run("fground = struct;"
    "fground.fthresh   = 3.1^2;"                       # highlight trajectories above 3.1^2
    "fground.LineStyle = {'--' '-.' ':'};"             # different line styles in foreground
    "fground.Color     = {'b';'g';'c';'m';'y';'k'};")  # different colors in foreground

# --- 4. persistent rectangular brushing (struct built MATLAB-side) ---------------------
run("databrush = struct;"
    "databrush.bivarfit      = '';"
    "databrush.selectionmode = 'Rect';"    # rubber-band rectangle selection
    "databrush.persist       = 'on';"      # keep brushing across repeated selections
    "databrush.Label         = 'on';"      # write trajectory labels while selecting
    "databrush.RemoveLabels  = 'off';")    # keep the labels after each selection

# --- 5. the interactive plot (graphics stay MATLAB-side; nargout=0) --------------------
# resfwdplot WITH databrush runs databrush's own interactive loop and BLOCKS the call
# until you press a keyboard key on the plot to stop brushing (it is figure/keyboard-
# driven, so it works even with the engine embedded). Gate on an interactive terminal so
# piped / CI runs never hang: when there is no TTY, draw the plot WITHOUT brushing.
interactive = sys.stdin.isatty()

print("Opening the resfwdplot figure ...")
if interactive:
    print("  * Rect-select residual trajectories to brush; persist='on' lets you brush repeatedly.")
    print("  * Press a keyboard key on the plot to STOP brushing (the call returns).")
    run("resfwdplot(out1, 'fground', fground, 'databrush', databrush);")   # blocks while brushing
    eng.render_figures()
    # --- 6. keep the engine + figure alive so you can inspect / close it ---------------
    print("Brushing finished. Close the figure window(s) to end the session.")
    eng.wait_for_figures()             # MATLAB-side uiwait; returns when all figures close
else:
    run("resfwdplot(out1, 'fground', fground);")   # no databrush -> does not block
    eng.render_figures()
    print("Non-interactive run: drew resfwdplot without brushing "
          "(run this in a terminal to brush it).")

pyfsda.stop()
