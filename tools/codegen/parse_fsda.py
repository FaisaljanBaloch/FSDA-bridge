"""Parse FSDA toolbox metadata into an intermediate representation.

See docs/DESIGN-codegen-parser.md for the full specification.
Specs 022, 023, 024 define the individual components.
"""

import argparse
import logging
import re
from pathlib import Path

log = logging.getLogger("parse_fsda")

# One function per line in Contents.m:
#   %   tclust   - Computes trimmed clustering ...   - CLUS-RobClaMULT- 2025 Dec 19
# The category can touch the next hyphen with no space ("CLUS-RobClaMULT-"),
# and categories contain hyphens themselves, so splitting on " - " is not
# enough. Anchor on the date at the end instead and take the non-space token
# before it as the category.
_CONTENTS_LINE = re.compile(
    r"^%\s+(?P<name>[A-Za-z]\w*)\s+-\s+(?P<desc>.*?)\s+-\s*"
    r"(?P<category>\S+?)\s*-\s*(?P<date>\d{4}\s+[A-Za-z]{3}\s+\d{1,2})\s*$"
)


def _read_text(path: Path) -> str:
    """Read an FSDA source file. FSDA files use CRLF and are mostly UTF-8."""
    return path.read_text(encoding="utf-8-sig", errors="replace").replace("\r\n", "\n")


def _parse_contents(contents_path: Path, label: str = "") -> dict:
    """Return {function name: category} from one Contents.m file."""
    found = {}
    for line in _read_text(contents_path).splitlines():
        m = _CONTENTS_LINE.match(line)
        if not m or m.group("name") == "Name":  # skip the column header row
            continue
        name = m.group("name")
        if name in found:
            log.warning("%s: %s listed twice, keeping the first", label or contents_path, name)
            continue
        found[name] = m.group("category")
    return found


def enumerate_toolbox(fsda_root: Path) -> list:
    """Walk the FSDA toolbox tree and return the function inventory.

    Discovers Contents.m files per subfolder, records functionSignatures.json
    paths where they exist, and excludes private/ directories.
    Does not open JSON files. See Spec 022.
    """
    fsda_root = Path(fsda_root)
    if not fsda_root.is_dir():
        raise NotADirectoryError(f"FSDA root not found: {fsda_root}")

    entries = []
    for contents in sorted(fsda_root.rglob("Contents.m")):
        folder = contents.parent
        rel = folder.relative_to(fsda_root)
        if "private" in rel.parts:
            continue

        functions = {}
        for name, category in _parse_contents(
                contents, contents.relative_to(fsda_root).as_posix()).items():
            m_rel = rel / f"{name}.m"
            if not (fsda_root / m_rel).is_file():
                log.warning("%s lists %s but %s does not exist",
                            contents.relative_to(fsda_root).as_posix(), name,
                            m_rel.as_posix())
            functions[name] = {"m_path": m_rel.as_posix(), "category": category}

        json_file = folder / "functionSignatures.json"
        entries.append({
            "json_path": (rel / json_file.name).as_posix() if json_file.is_file() else None,
            "functions": functions,
        })
    return entries


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
    raise NotImplementedError


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
