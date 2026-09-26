"""Parse FSDA toolbox metadata into an intermediate representation.

See docs/DESIGN-codegen-parser.md for the full specification.
Specs 022, 023, 024 define the individual components.
"""

import argparse
import re
import warnings
from pathlib import Path

_BEGIN_CODE = "%% Beginning of code"
_SIG_RE = re.compile(r"^function\s*(?:\[(?P<multi>[^\]]*)\]\s*=|(?P<single>\w+)\s*=)?\s*\w+\s*\(")


def _isolate_preamble(m_path: Path) -> tuple:
    """Return (signature_line, preamble_lines), or None on failure.

    The preamble is everything between the `function` signature line and
    the `%% Beginning of code` marker, with the leading `%` stripped from
    each line. Returns None (and warns) if the file can't be read, doesn't
    start with `function`, or has no marker.
    """
    try:
        text = m_path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        warnings.warn(f"extract_m_prose: cannot read {m_path}: {exc}")
        return None

    lines = text.splitlines()
    if not lines or not lines[0].lstrip().startswith("function"):
        warnings.warn(f"extract_m_prose: {m_path} does not start with a 'function' line")
        return None

    end_idx = next((i for i, line in enumerate(lines) if line.strip() == _BEGIN_CODE), None)
    if end_idx is None:
        warnings.warn(f"extract_m_prose: no '{_BEGIN_CODE}' marker in {m_path}")
        return None

    preamble = [line[1:].lstrip(" ") if line.startswith("%") else line for line in lines[1:end_idx]]
    return lines[0], preamble


def _extract_output_names(sig_line: str) -> tuple:
    """Return (output_names, has_varargout) from a `function ... = name(...)` line.

    `varargout` never gets a literal entry in the `Output:` section - its
    entries live in `Optional Output:` instead - so it's excluded from the
    returned names but flagged separately.
    """
    match = _SIG_RE.match(sig_line.strip())
    if not match:
        return [], False
    if match.group("multi") is not None:
        names = [n.strip() for n in match.group("multi").split(",") if n.strip()]
    elif match.group("single"):
        names = [match.group("single")]
    else:
        names = []
    return [n for n in names if n != "varargout"], "varargout" in names


def _strip_example_blocks(lines: list) -> list:
    """Drop `%{ ... %}` example blocks.

    After the `%`-strip in `_isolate_preamble`, the delimiters are bare
    lines that are exactly `{` / `}`. The pipeline never captures examples
    (Spec 024).
    """
    result = []
    in_block = False
    for line in lines:
        stripped = line.strip()
        if not in_block and stripped == "{":
            in_block = True
        elif in_block and stripped == "}":
            in_block = False
        elif not in_block:
            result.append(line)
    return result


_SECTION_ORDER = [
    ("docsearch", re.compile(r"docsearchFS\(")),
    ("required_input", re.compile(r"^\s*Required input arguments\s*:", re.IGNORECASE)),
    ("optional_input", re.compile(r"^\s*Optional input arguments\s*:", re.IGNORECASE)),
    ("output", re.compile(r"^\s*Output\s*:", re.IGNORECASE)),
    ("optional_output", re.compile(r"^\s*Optional\s+Output\s*:", re.IGNORECASE)),
    ("more_about", re.compile(r"^\s*More\s+About\s*:", re.IGNORECASE)),
    ("see_also", re.compile(r"^\s*See\s+also\s*:?", re.IGNORECASE)),
    ("references", re.compile(r"^\s*References\s*:?", re.IGNORECASE)),
]


def _find_section_bounds(lines: list) -> dict:
    """Return {section_name: line_index} for each header found, in the
    fixed publishFS order. A header absent from the file (e.g. no
    `Optional Output:`) is simply absent from the result. `docsearch`
    marks the start of the long description, not a real section.
    """
    bounds = {}
    start = 0
    for name, pattern in _SECTION_ORDER:
        idx = next((i for i in range(start, len(lines)) if pattern.search(lines[i])), None)
        if idx is not None:
            bounds[name] = idx
            start = idx + 1
    return bounds


def _section_lines(lines: list, bounds: dict, name: str) -> list:
    """Body of section `name`: between its header (exclusive) and the next
    found header (exclusive), or end of `lines`. `[]` if `name` wasn't found.
    """
    if name not in bounds:
        return []
    order = [n for n, _ in _SECTION_ORDER]
    start = bounds[name] + 1
    later = [bounds[n] for n in order[order.index(name) + 1:] if n in bounds]
    end = min(later) if later else len(lines)
    return lines[start:end]


def _extract_long_desc(lines: list, bounds: dict) -> str:
    """Prose between the docsearchFS link and `Required input arguments:`,
    collapsed to one whitespace-normalized string.
    """
    body = _section_lines(lines, bounds, "docsearch")
    text = " ".join(line.strip() for line in body if line.strip())
    return re.sub(r"\s+", " ", text).strip()


_NAME_BLOCK_RE = re.compile(r"^\s*(\w+)\s*:\s*(.*)$")

# publishFS convention words that use the same `Word:` shape as a real
# parameter/output name but are inline sub-notes, not names of their own
# (verified against occurrences across the whole FSDA toolbox, not just
# these 3 files - both appear repeatedly mid-description, e.g. "Remark:
# this output is present only if ..."). Without this, they'd wrongly cut
# off whatever param/output was being accumulated and start a bogus entry.
_NON_NAME_WORDS = {"remark", "example"}


def _parse_named_blocks(lines: list, pattern=_NAME_BLOCK_RE, exclude=_NON_NAME_WORDS) -> dict:
    """Split a section's body into blocks keyed by a leading `name :` line.

    Shared by `params`/top-level `outputs` (default `pattern`, a bare
    `name :`) and struct `fields` (called with an `out\\.(\\w+)\\s*=`
    pattern): a struct field line like `out.muopt= ...` has a dot before
    its `=`, not a bare `:`, so it never starts a new block under the
    default pattern - it folds into whatever block is currently open as a
    continuation line instead, which is exactly the split the field-level
    call needs its own turn at.
    """
    blocks = {}
    current = None
    for raw in lines:
        match = pattern.match(raw)
        if match and match.group(1).lower() not in exclude:
            current = match.group(1)
            first = match.group(2).strip()
            blocks[current] = [first] if first else []
        elif current is not None:
            stripped = raw.strip()
            if stripped:
                blocks[current].append(stripped)
    return blocks


def _join_block(fragments: list) -> str:
    return re.sub(r"\s+", " ", " ".join(fragments)).strip()


def _extract_params(lines: list, bounds: dict) -> dict:
    """Merge Required + Optional input sections into one flat params dict."""
    params = {}
    for section in ("required_input", "optional_input"):
        blocks = _parse_named_blocks(_section_lines(lines, bounds, section))
        for name, fragments in blocks.items():
            params[name] = _join_block(fragments)
    return params


def enumerate_toolbox(fsda_root: Path) -> list:
    """Walk the FSDA toolbox tree and return the function inventory.

    Discovers Contents.m files per subfolder, records functionSignatures.json
    paths where they exist, and excludes private/ directories.
    Does not open JSON files. See Spec 022.
    """
    raise NotImplementedError


def parse_json_signatures(json_path: Path) -> dict:
    """Parse a single functionSignatures.json, preserving duplicate keys.

    Returns all signatures grouped by function name. Keys starting
    with _ are excluded. See Spec 023.
    """
    raise NotImplementedError


def extract_m_prose(m_path: Path) -> dict:
    """Extract prose from a single .m file's preamble.

    Returns long description, per-parameter descriptions, outputs,
    see-also references, and citations. See Spec 024.
    """
    isolated = _isolate_preamble(m_path)
    if isolated is None:
        return {}
    sig_line, preamble = isolated
    _, has_varargout = _extract_output_names(sig_line)
    preamble = _strip_example_blocks(preamble)
    bounds = _find_section_bounds(preamble)
    long_desc = _extract_long_desc(preamble, bounds)
    params = _extract_params(preamble, bounds)
    outputs = []

    output_blocks = _parse_named_blocks(
        _section_lines(preamble, bounds, "output")
    )

    for name, fragments in output_blocks.items():
        first_line = fragments[0] if fragments else ""
        dot = first_line.find(".")
        short_desc = (first_line[: dot + 1] if dot != -1 else first_line).strip()
        fields = []

        if (
            "structure" in short_desc.lower()
            and "field" in short_desc.lower()
        ):
            field_re = re.compile(rf"^\s*{re.escape(name)}\.(\w+)\s*=\s*(.*)$")
            field_blocks = _parse_named_blocks(fragments, pattern=field_re, exclude=frozenset())
            for field_name, field_fragments in field_blocks.items():
                fields.append({
                    "name": field_name,
                    "desc": _join_block(field_fragments),
                })
            output_long_desc = short_desc
        else:
            output_long_desc = _join_block(fragments)

        outputs.append({
            "name": name,
            "short_desc": short_desc,
            "long_desc": output_long_desc,
            "fields": fields,
        })

    if has_varargout:
        optional_blocks = _parse_named_blocks(
            _section_lines(preamble, bounds, "optional_output")
        )

        for name, fragments in optional_blocks.items():
            description = _join_block(fragments)
            outputs.append({
                "name": name,
                "short_desc": description,
                "long_desc": description,
                "fields": [],
            })

    see_also = []
    if "see_also" in bounds:
        header_line = preamble[bounds["see_also"]]
        match = re.search(
            r"See\s+also\s*:?\s*(.*)",
            header_line,
            re.IGNORECASE,
        )
        if match:
            see_also = [
                item.strip()
                for item in match.group(1).split(",")
                if item.strip()
            ]

    references = []
    if "references" in bounds:
        reference_lines = _section_lines(
            preamble, bounds, "references"
        )
        # Everything from "Copyright <year>" onward is trailing boilerplate
        # (Written by FSDA team, the repeated docsearchFS link, the
        # $LastChangedDate$ stamp) with no header of its own - cut there.
        copyright_idx = next(
            (i for i, line in enumerate(reference_lines)
             if line.strip().lower().startswith("copyright")),
            len(reference_lines),
        )
        reference_lines = reference_lines[:copyright_idx]

        # Citations are separated by blank lines in the source and often
        # wrap across several lines - join each citation's lines into one
        # entry instead of emitting one list item per physical line.
        current = []
        for line in reference_lines:
            stripped = line.strip()
            if stripped:
                current.append(stripped)
            elif current:
                references.append(_join_block(current))
                current = []
        if current:
            references.append(_join_block(current))

    return {
        "long_desc": long_desc,
        "params": params,
        "outputs": outputs,
        "see_also": see_also,
        "references": references,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Parse FSDA metadata into an intermediate representation.",
    )
    parser.add_argument(
        "--fsda-root",
        type=Path,
        required=True,
        help="Path to the FSDA toolbox root directory",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("IntRep.json"),
        help="Where should the output be written (default: ./IntRep.json)",
    )
    args = parser.parse_args()
