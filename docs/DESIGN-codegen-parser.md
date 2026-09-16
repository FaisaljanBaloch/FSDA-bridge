# Design: FSDA documentation parser and intermediate representation

---

## 1. What this is

FSDA ships machine-readable metadata about its functions: a `functionSignatures.json` with typed signatures, `.m` files with prose documentation, and `Contents.m` catalogs. None of this is currently used by the bridge packages.

The goal of this task is to create a Python pipeline that reads that metadata and produces a structured, language-agnostic (so without translating yet) intermediate representation (IR): one record per function, combining typed parameter specs from the JSON with prose descriptions from the `.m` preambles.

The IR is the deliverable. It is the foundation for future codegen (documentation pages, docstrings, test scaffolds), but those are not a concern for now. Phase 1 is: parse the sources, produce correct IR, validate it.

## 2. Sources

The pipeline reads three source types. Each is authoritative for specific information, with no overlap.

### 2.1 `functionSignatures.json`

A JSON file shipped with FSDA for MATLAB's editor autocompletion. It contains parameter names, order, kinds (`required`, `namevalue`, `ordered`), structured type specs (e.g. `["double", "scalar"]`), defaults, short `purpose` strings, and struct typedefs in a `_typedefs` section.

**JSON is a hard dependency.** No JSON entry means no IR record. A function in `Contents.m` with a `.m` file but no JSON entry produces a warning and is skipped. Generating documentation without correct type information is worse than generating nothing.

Known issues:

- **Duplicate keys.** The JSON format uses repeated keys for the same function name to declare mutually exclusive signatures. Standard JSON parsers silently keep the last one, so the pipeline's parser must handle this correctly and preserve all entries. See §3.2.
- **Incomplete coverage.** Not all functions have entries. The gap should be quantified early.

### 2.2 `.m` preambles

The structured comment block at the top of each `.m` file. Contains long prose descriptions, per-parameter descriptions (richer than the JSON `purpose` field), output struct field documentation, `See also` references, and citations.

The pipeline extracts these as **prose strings only**. It never parses types from the preamble; the type information is embedded in natural language sentences and extracting it reliably would mean replicating a significant portion of what `publishFS` does in 6k+ lines of MATLAB. The JSON already provides the same information in structured form.

### 2.3 `Contents.m` files

Each FSDA toolbox folder has a `Contents.m` listing functions with one-line descriptions, categories, and dates. **`Contents.m` is a hard dependency alongside JSON.** A function must appear in both a `Contents.m` and a `functionSignatures.json` to enter the IR. `Contents.m` is the sole source of category and the mechanism by which the pipeline discovers which functions exist.

### 2.4 Authority table

Both JSON and `Contents.m` are hard dependencies: a function must appear in both to get an IR record. Every user-facing `.m` file has a long description, output fields, and `See also` (publishFS enforces this), so the `.m`-sourced fields should always be present in practice. The pipeline should warn if they are missing, as that likely indicates a parse error rather than genuinely absent content.

| Information | Source |
|---|---|
| Parameter existence, order, kind | JSON |
| Parameter types | JSON |
| Parameter defaults | JSON |
| Function short description | JSON `description` |
| Parameter description (prose) | `.m` preamble |
| Function long description | `.m` preamble |
| Output struct fields | `.m` preamble |
| See also | `.m` preamble |
| Category | `Contents.m` |

## 3. Pipeline

```
 Contents.m ──→ Enumerate ──→ function list
                                  │
 JSON ────────→ Parse JSON ───────┤
                                  │
 .m files ───→ Extract prose ─────┤
                                  │
                              Merge ──→ IR (one dict per function)
```

Each box is a function or module in a single Python script. The pipeline is run manually, not in CI (yet).

**Orchestration.** The parsers are dumb: the JSON parser takes one file path and returns all signatures in that file. The `.m` extractor takes one file path and returns one prose dict. The enumerator discovers paths and parses `Contents.m` but never opens JSON files. The orchestrator is the only thing that loops, cross-checks, and coordinates:

1. Enumerator walks the tree once, produces per-folder entries (discovered file paths + `Contents.m` functions).
2. For each folder with a `functionSignatures.json`: call the JSON parser, then cross-check its function names against the `Contents.m` functions for that folder. Warn on mismatches and skip functions not in both. For each function present in both: call the `.m` extractor on its `.m` path, merge both, produce one IR record.
3. Collect all IR records, write to disk.

This means the `.m` extractor only runs for functions that have a JSON entry. If JSON covers 150 of 500 functions, only 150 `.m` files get parsed.

### 3.1 Enumerator

Walks the FSDA toolbox tree. Each subdirectory (e.g. `clustering/`, `multivariate/`) may contain a `Contents.m` and a `functionSignatures.json`. The enumerator discovers all of them and records what it finds. Subdirectories named `private` are excluded; they contain internal helper functions with their own `Contents.m` that should not enter the IR.

The enumerator does not open JSON files. It only confirms they exist and records their paths. The cross-check between `Contents.m` functions and JSON function names happens in the orchestrator, after the JSON parser has run.

**Input:** path to the FSDA toolbox root.

**Output:**

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

Each entry is one folder. `json_path` is null if the folder has a `Contents.m` but no `functionSignatures.json` (the orchestrator skips these entirely). `functions` comes from parsing that folder's `Contents.m`. All paths in the output are strings relative to `fsda_root`. The orchestrator joins them with `fsda_root` when calling the parsers.

- **How `Contents.m` is parsed:** each line matching the pattern `%   FunctionName   - Description  - Category  - Date` contributes a function name and its category. The `m_path` is constructed from the folder path plus the function name.
- **`private/` exclusion:** subdirectories named `private` are skipped entirely.

### 3.2 JSON parser

Each subdirectory's `functionSignatures.json` may use repeated keys for the same function name to express mutually exclusive calling conventions (e.g. `MixSim` has two entries with different parameter sets). Standard `json.loads()` silently drops all but the last entry for a given key.

**Input:** a single `functionSignatures.json` path.

**Output:** a dict mapping each function name to a list of raw signature dicts.

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

The parser must preserve all entries for a given function name inside a specific JSON file. Some functions have multiple signatures, most commonly to handle both table/timetable and numeric matrix inputs.

### 3.3 `.m` prose extractor

Extracts prose from the structured comment block at the top of each `.m` file. The format of this block is defined by `publishFS` (see https://rosa.unipr.it/FSDA/publishFS.html, "More About" section). Files that pass `publishFS` are guaranteed to follow these conventions, so the extractor can rely on them.

**Input:** a `.m` file path.

**Example Output:**

```python
{
    "long_desc": "tclust partitions the points in the n-by-v data matrix Y into k clusters...",
    "params": {
        "Y": "Input data. Matrix. n x v matrix where ...",
        "k": "Number of groups. Scalar. ...",
        "alpha": "Global trimming level. Scalar. ...",
        "nsamp": "Number of subsamples to extract. Scalar. ...",
    },
    "outputs": [
        {
            "name": "out",
            "short_desc": "A structure containing the following fields",
            "long_desc": "...",
            "fields": [
                {"name": "idx", "desc": "n-by-1 vector containing assignment of each unit..."},
                {"name": "muopt", "desc": "k-by-v matrix containing cluster centroids..."},
            ]
        },
        {
            "name": "C",
            "short_desc": "Indexes of extracted subsamples",
            "long_desc": "...",
            "fields": []
        }
    ],
    "see_also": ["tclusteda"],
    "references": ["Atkinson, A.C., Riani, M., ..."]
}
```

Note that `outputs` is a list of the function's output arguments (extracted from the `function [out, C] = ...` line), not a single struct. Each output may or may not have sub-fields; only outputs whose description contains "structure" and "field" will have a populated `fields` list. The `out.fieldname =` pattern (with `=`, not `:`) identifies struct fields per the publishFS convention.

**Sections to extract.** The publishFS spec mandates these section headers (the extractor can treat them as reliable delimiters):

- `Required input arguments:` (always present)
- `Optional input arguments:` (always present, even if empty)
- `Output:` (always present)
- `See also:` (always present)
- `References:` (always present)
- `Optional Output:` (present if varargout; optional outputs are appended to the `outputs` list)

Optional sections not captured: `More About:`, `Acknowledgements:`.

Examples (`%{` ... `%}` blocks) are skipped. The extractor does not capture them.

**If a `.m` file is missing or unparseable, the extractor warns and returns an empty result.** The merge step proceeds with JSON data only.

### 3.4 Merge step
Executed once per eligible function.

**Input:**
- The function's JSON signature entries (a list; one entry for most functions, multiple for those with duplicate keys).
- The function's `.m` prose dict (from the extractor, or empty dict if the `.m` was missing/unparseable).

**Output:** one IR dict (schema in §4).

1. If multiple JSON entries exist for this function, flatten them into one combined parameter list:
   - Parameters with the same name but different types across entries: types are unioned. E.g. a parameter typed as `[["single", "2d"], ["double", "2d"]]` in one entry and `"table"` in another becomes `[["single", "2d"], ["double", "2d"], ["table"]]`.
   - Parameters only in one entry: included as-is. The bridge does not validate parameter combinations.
   - For non-type fields (`kind`, `default`, `purpose`), the first entry's value is used. `description_short` and outputs are also taken from the first entry. Parameter order follows the first entry, with params unique to later entries appended at the end.
2. Normalize all `matlab_type` values to list-of-lists (OR of AND). E.g. `"struct"` → `[["struct"]]`, `["numeric", "scalar"]` → `[["numeric", "scalar"]]`, `[["single", "scalar"], ["double", "scalar"]]` → unchanged. Also:
   - `struct:Name` type references (e.g. `"struct:TkmeansOpt"`): the atom becomes `"struct"`. The typedef name is discarded. Normalization handles the nesting.
   - `choices=tbl.Properties.VariableNames` entries: kept as-is. These are MATLAB editor hints meaning "accepts column names from the input table." The codegen decides what to do with them; the underlying `cellstr`/`char` entries in the same union already cover the type.
3. For each input, set `purpose_short` from the JSON `purpose` string. Set `purpose_long` from the `.m` prose if available, null otherwise.
4. Set `description_short` from JSON `description`, `description_long` from `.m` (null if absent).
5. For each output, normalize `matlab_type` the same way, then attach `.m` parsed output prose (`short_desc`, `long_desc`, `fields`) where available.
6. Set `see_also`, `references` from `.m` prose. All null/empty if no `.m`.
7. Set `category` from the enumerator's per-function entry.
8. Construct `fsda_url` as `https://rosa.unipr.it/FSDA/{name}.html`.

**Mismatches between sources:**

- **Parameter in `.m` but not in flattened JSON:** warning. Likely a parameter handled via `varargin` that was never added to the JSON. The parameter does not get an IR entry (no type information).
- **Parameter in JSON but not in `.m`:** warning. Shouldn't happen if the function passed publishFS. The JSON `purpose` string is used.
- **Output names in `.m` function line disagree with JSON `outputs`:** warning. The JSON drives the output list; `.m` prose attaches by matching names.

The merge never invents information. If both sources are silent on a field, it stays null.

## 4. IR schema

One dict per function, with a single flat parameter list. This is ephemeral, generated every run, never hand-edited.

When a function has multiple JSON entries (mutually exclusive calling conventions), the merge step flattens them: all parameters are combined into one list, and parameters whose types differ across entries have their types unioned.

```json
{
  "name": "tkmeans",
  "category": "CLUS-RobClaMULT",
  "description_short": "Computes trimmed k-means",
  "description_long": "Trimmed k-means partitions n observations into k groups ...",
  "inputs": [
    {
      "name": "Y",
      "kind": "required",
      "matlab_type": [["numeric"]],
      "purpose_short": "Input data",
      "purpose_long": "Input data. n x v matrix where ...",
      "default": null
    },
    {
      "name": "k",
      "kind": "required",
      "matlab_type": [["numeric", "scalar"]],
      "purpose_short": "Number of groups",
      "purpose_long": "Number of groups. Scalar. ...",
      "default": null
    },
    {
      "name": "nsamp",
      "kind": "namevalue",
      "matlab_type": [["double"]],
      "purpose_short": "Number of subsamples to extract",
      "purpose_long": "Number of subsamples to extract. Scalar. ...",
      "default": null
    },
    {
      "name": "plots",
      "kind": "namevalue",
      "matlab_type": [["single", "scalar"], ["double", "scalar"],
                       ["char", "choices={'contourf','contour','ellipse','boxplotb'}"],
                       ["struct"]],
      "purpose_short": "Plot on the screen",
      "purpose_long": "Plot type. Scalar 0/1 or a string naming the plot style.",
      "default": null
    }
  ],
  "outputs": [
    {
      "name": "out",
      "matlab_type": [["struct"]],
      "short_desc": "A structure containing the following fields",
      "long_desc": "...",
      "fields": [
        {"name": "idx",    "desc": "n-by-1 vector containing assignment of each unit..."},
        {"name": "muopt",  "desc": "k-by-v matrix containing cluster centroids..."}
      ]
    },
    {
      "name": "C",
      "matlab_type": [["cell"]],
      "short_desc": "Subsamples extracted",
      "long_desc": "...",
      "fields": []
    }
  ],
  "see_also": ["tclust", "tclusteda"],
  "references": ["..."],
  "fsda_url": "https://rosa.unipr.it/FSDA/tkmeans.html"
}
```

Types stay in MATLAB terms (`matlab_type`) and are always normalized to list-of-lists (OR of AND). Mapping to target language types is a codegen concern, not an IR concern.

When an input has `"type": "struct:TkmeansOpt"` in the JSON, the IR stores it as `"struct"`. The typedef reference is stripped; the pipeline does not resolve it.

## 5. Validation

For the initial prototype, validation is manual: run the pipeline on a handful of functions, inspect the IR output, and verify it looks correct against the `.m` and JSON sources. Automated testing (golden-output diffs, coverage regression checks) can be added once the IR schema stabilizes.

### 5.1 Spot-checks

After a run, verify that:

- A function with both JSON and `.m` produces a complete IR record.
- A function with JSON but unparseable `.m` produces a sparse but valid IR record.
- A function with `.m` but no JSON produces no IR record (and a warning).
- A function in JSON but absent from that folder's `Contents.m` produces a warning and no IR record.
- Parameters originally typed as `struct:Name` in the JSON appear as `[["struct"]]` in the IR.
- Duplicate JSON keys (e.g. `MixSim`) produce a single IR record with merged parameters, not separate records.

## 6. Operational details

### 6.1 Inputs

The pipeline lives in `tools/codegen/` in the bridge repo. It reads from the FSDA toolbox tree. Each subdirectory (e.g. `clustering/`, `multivariate/`, `regression/`) has its own `Contents.m` and `functionSignatures.json`. The pipeline walks the tree and discovers them all.

```
python tools/codegen/parse_fsda.py --fsda-root /path/to/FSDA/toolbox
```

### 6.2 Outputs

The IR can be written to disk as JSON for inspection and for consumption by future codegen phases. It is gitignored; it is not a committed artifact.

## 7. Decisions and rationale

**Why JSON is mandatory, not best-effort.** Generating docs without type information looks complete but isn't. A missing page is obviously missing; a wrong type table is silently misleading.

**Why not parse types from `.m` preambles.** The `.m` format is well-documented and consistent, but the type information is embedded in prose: sentence boundaries, `Data Types -` lines, inline `choices` constraints, struct field descriptions. Extracting all of this reliably means replicating a substantial portion of `publishFS` (6,000+ lines of MATLAB). The JSON gives the same information as structured data: `["double", "scalar"]`, `["char", "choices={'eigen','deter'}"]`, explicit `_typedefs` for struct fields. Solving the JSON's known issues (duplicate keys, coverage gaps) is a smaller, more bounded problem than building a second type parser.

**Why not parse `publishFS` HTML output.** It's a derivative of the `.m` preambles, adds nothing, and its structure depends on rendering choices that can change.

**Why not enrich JSON `purpose` fields to full prose.** The `purpose` field is what MATLAB displays in its editor autocompletion tooltips. Making it longer would break MATLAB's own UX.

**Why not build codegen now.** Infrastructure first. The IR schema needs to be correct and stable before anything consumes it. Codegen is Phase 2.

**Why flatten mutually exclusive JSON signatures.** MATLAB uses duplicate keys to drive context-sensitive autocompletion in its editor. The bridge languages cannot replicate this: the facades pass arguments through opaquely. Flattening into one parameter list with unioned types preserves all type information without schema complexity that nothing downstream can use. MATLAB-specific type hints like `choices=tbl.Properties.VariableNames` are kept in the IR for the codegen to interpret or skip.
