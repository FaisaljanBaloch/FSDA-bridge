"""Parse FSDA toolbox metadata into an intermediate representation.

See docs/DESIGN-codegen-parser.md for the full specification.
Specs 022, 023, 024 define the individual components.
"""

import argparse
from pathlib import Path


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
