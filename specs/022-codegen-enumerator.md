# Spec 022 - codegen parser enumerator

> Read `DESIGN-codegen-parser.md` first (§3.1 and the orchestration section).
> This component walks the FSDA toolbox tree and produces the function inventory.
> It does not open JSON files or perform cross-checking; the orchestrator handles that.

## Contract

- **Deliverable:** a Python function in `tools/codegen/parse_fsda.py` that takes a path to the FSDA toolbox root and returns a list of per-folder entries, each containing the folder's `Contents.m` functions and the path to its `functionSignatures.json` (if present).
- **Done when:** the output correctly discovers all folders with a `Contents.m`, parses function names and categories from it, records the `functionSignatures.json` path where one exists, and excludes `private/` subdirectories.
- **Out of scope:** opening or parsing JSON files (Spec 023), parsing `.m` preambles (Spec 024), cross-checking Contents.m against JSON (orchestrator), the merge step, codegen.

## Design

- **Files:** `tools/codegen/parse_fsda.py` (function `enumerate_toolbox`)
- **Input:** a `pathlib.Path` to the FSDA toolbox root (e.g. `/path/to/FSDA/toolbox`).
- **Output:**

```python
[
    {
        "json_path": "clustering/functionSignatures.json",
        "functions": {
            "tkmeans": {"m_path": "clustering/tkmeans.m", "category": "CLUS-RobClaMULT"},
            "tclust":  {"m_path": "clustering/tclust.m",  "category": "CLUS-RobClaMULT"},
            ...
        }
    },
    {
        "json_path": "multivariate/functionSignatures.json",
        "functions": {
            "FSM":     {"m_path": "multivariate/FSM.m",    "category": "MULT-Multivariate"},
            ...
        }
    },
    ...
]
```

Each entry is one folder. `json_path` is null if the folder has a `Contents.m` but no `functionSignatures.json`. `functions` comes from parsing that folder's `Contents.m`. All paths in the output are strings relative to `fsda_root`.

- **How `Contents.m` is parsed:** each line matching the pattern `%   FunctionName   - Description  - Category  - Date` contributes a function name and its category. The `m_path` is constructed from the folder path plus the function name.
- **JSON file discovery:** the enumerator checks whether a `functionSignatures.json` exists in each folder and records its path. It does not open or parse the file.
- **`private/` exclusion:** subdirectories named `private` are skipped entirely.

## Tasks

- [ ] #p1 Walk the toolbox tree, discover all `Contents.m` files and check for `functionSignatures.json`, skip `private/` dirs
- [ ] #p1 Parse `Contents.m` lines for function names
- [ ] #p1 Return per-folder entries with `json_path` and `functions`
- [ ] #p2 Extract category from `Contents.m` line

### Done

(move checked items here with a date)
