"""Snapshot what _extract_m_prose returns for every enumerated FSDA function.

Writes one JSON file per function into a new directory. The tool does not
compare anything: diff two snapshot directories with git.

    python tools/codegen/snapshot_prose.py ~/Documents/MATLAB/FSDA/toolbox /tmp/snap-before
    # ... apply the change ...
    python tools/codegen/snapshot_prose.py ~/Documents/MATLAB/FSDA/toolbox /tmp/snap-after
    git diff --no-index --stat /tmp/snap-before /tmp/snap-after         # which functions changed
    git diff --no-index --word-diff /tmp/snap-before /tmp/snap-after    # what changed in them

Keep snapshot directories outside the repository.
"""

import argparse
import json
import logging
import sys
import warnings
from pathlib import Path

from parse_fsda import _enumerate_toolbox, _extract_m_prose


class _Collect(logging.Handler):
    """Keep the text of every record logged while one function is extracted."""

    def __init__(self):
        super().__init__()
        self.messages = []

    def emit(self, record):
        self.messages.append(record.getMessage())


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("fsda_root", type=Path, help="the FSDA toolbox directory")
    parser.add_argument(
        "out_dir", type=Path, help="new or empty directory to write into"
    )
    args = parser.parse_args()

    root = args.fsda_root.expanduser().resolve()
    out = args.out_dir.expanduser()
    if out.exists() and (not out.is_dir() or any(out.iterdir())):
        sys.exit(
            f"{out} is not an empty directory; use a new one so no stale files remain"
        )

    # Enumerate before capturing, so the enumerator's own warnings reach the terminal.
    folders = _enumerate_toolbox(root)

    collector = _Collect()
    logger = logging.getLogger("parse_fsda")
    logger.addHandler(collector)
    logger.propagate = False  # messages go into the snapshot, not the terminal

    count = failed = 0
    for folder in folders:
        # Folders without functionSignatures.json are out of scope.
        if folder["json_path"] is None:
            continue
        for info in folder["functions"].values():
            m_path = root / info["m_path"]
            if not m_path.is_file():  # the enumerator already logged this
                continue

            collector.messages.clear()
            error = None
            with warnings.catch_warnings(record=True) as caught:
                warnings.simplefilter("always")
                try:
                    result = _extract_m_prose(m_path)
                except Exception as exc:  # noqa: BLE001 - one broken file must not stop the run
                    result, error = None, f"{type(exc).__name__}: {exc}"
            log = [str(w.message) for w in caught] + collector.messages

            entry = {
                # Machine-independent paths, so snapshots from two machines compare.
                "log": [msg.replace(str(root), "<fsda_root>") for msg in log],
                "error": error,
                "result": result,
            }
            target = out / Path(info["m_path"]).with_suffix(".json")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(
                json.dumps(entry, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
            )
            count += 1
            failed += result is None

    if count == 0:
        sys.exit(f"no functions found under {root}; is it the FSDA toolbox directory?")
    print(f"{count} functions written to {out} ({failed} without a result)")


if __name__ == "__main__":
    main()
