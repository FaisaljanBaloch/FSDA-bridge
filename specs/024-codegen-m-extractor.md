# Spec 024 - codegen `.m` prose extractor

> Read `DESIGN-codegen-parser.md` first (§2.2, §3.3).
> Read the publishFS format spec: https://rosa.unipr.it/FSDA/publishFS.html ("More About" section).
> This component reads a single `.m` file and extracts prose from its preamble.
> It does not extract types; the JSON is the sole type authority.

## Contract

- **Deliverable:** a Python function in `tools/codegen/parse_fsda.py` that takes a path to one FSDA `.m` file and returns a dict of extracted prose: long description, per-parameter descriptions, output argument documentation (including struct fields where applicable), `See also` references, and bibliographic references.
- **Done when:** the extractor produces correct output for at least three representative functions (one with struct outputs, one with multiple non-struct outputs, one with no outputs), verified by manual inspection against the source `.m` files.
- **Out of scope:** type extraction (JSON handles that), example capture (`%{ %}` blocks are skipped), walking the toolbox tree (Spec 022), JSON parsing (Spec 023), the merge step, codegen.

## Design

- **Files:** `tools/codegen/parse_fsda.py` (function `extract_m_prose`)
- **Input:** a `pathlib.Path` to a single `.m` file.
- **Output:**

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

- **The preamble format is defined by publishFS.** Files that pass publishFS are guaranteed to follow these conventions. The extractor can rely on the mandatory section headers as delimiters: `Required input arguments:`, `Optional input arguments:`, `Output:`, `See also:`, `References:`.
- **Output arguments** are extracted from the `function [out, C] = name(...)` line. Each output may or may not have struct sub-fields. Only outputs whose description contains "structure" and "field" have a populated `fields` list. Struct fields are identified by the `out.fieldname =` pattern (with `=`, not `:`).
- **`%{ %}` example blocks are skipped.** The extractor does not capture them.
- **If the file is missing or unparseable, warn and return an empty dict.**

## Tasks

- [ ] #p1 Read all lines after the `function` line up to `%% Beginning of code`
- [ ] #p1 Handle `%{ %}` blocks (skip them, do not let them interfere with section parsing)
- [ ] #p1 Extract the long description (text between the `docsearchFS` link and `Required input arguments:`)
- [ ] #p1 Extract per-parameter prose from Required and Optional input sections (detect `name :` pattern for new parameters, accumulate continuation lines)
- [ ] #p1 Extract output argument names from the `function` line
- [ ] #p1 Extract output descriptions from the `Output:` section, including struct fields via the `out.fieldname =` pattern
- [ ] #p2 Extract `See also` entries (comma-separated function names)
- [ ] #p2 Extract `References` entries
- [ ] #p2 Extract optional outputs from `Optional Output:` section (append to `outputs` list)

### Done

(move checked items here with a date)
