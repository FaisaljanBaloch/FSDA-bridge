# Spec 023 - codegen JSON parser

> Read `DESIGN-codegen-parser.md` first (§2.1, §3.2, and §3.4 for how the merge step consumes this output).
> This component reads a single `functionSignatures.json` file and returns
> all signatures in it, preserving duplicate keys.

## Contract

- **Deliverable:** a Python function in `tools/codegen/parse_fsda.py` that takes a path to one `functionSignatures.json` file and returns all function signatures, with duplicate keys preserved as lists.
- **Done when:** for every JSON file in the FSDA toolbox, the parser returns all function entries (including duplicates like `MixSim`, `CorAna`) and does not crash or silently drop data.
- **Out of scope:** walking the toolbox tree (Spec 022), parsing `.m` preambles (Spec 024), flattening duplicate entries (that is the merge step's job), type mapping to target languages, resolving `_typedefs` references.

## Design

- **Files:** `tools/codegen/parse_fsda.py` (function `parse_json_signatures`)
- **Input:** a `pathlib.Path` to a single `functionSignatures.json` file.
- **Output:**

```python
{
    "tkmeans": [
        {"inputs": [...], "outputs": [...], "description": "..."}
    ],
    "MixSim": [
        {"inputs": [...], "outputs": [...], "description": "..."},
        {"inputs": [...], "outputs": [...], "description": "..."}
    ],
    ...
}
```

- **Duplicate key handling:** MATLAB's `functionSignatures.json` format uses repeated top-level keys for the same function name to declare mutually exclusive calling conventions. Standard `json.loads()` silently keeps only the last entry. The parser must preserve all of them. Every function name maps to a list of signature dicts, even when there is only one entry.
- **Keys starting with `_`** (`_schemaVersion`, `_typedefs`) are excluded from the output. `struct:Name` references in the signatures are left as-is; the merge step strips these to `struct`.
- **Signature contents are passed through as-is.** The parser does not interpret, validate, or transform the `inputs`/`outputs` arrays. It preserves the raw JSON structure.

## Tasks

- [ ] #p1 Read a JSON file and preserve duplicate top-level keys in a list-valued dict
- [ ] #p1 Exclude keys starting with `_` (`_typedefs`, `_schemaVersion`) from the output
- [ ] #p1 Return the output structure described above
- [ ] #p2 Test against all 8 `functionSignatures.json` files in the FSDA toolbox
- [ ] #p2 Verify that known duplicate-key functions (e.g. `MixSim`, `CorAna`, `corrNominal`) produce multiple entries in the list
- [ ] #p3 Warn on any structural anomalies (e.g. a function entry missing `inputs` or `description`)

### Done

(move checked items here with a date)
