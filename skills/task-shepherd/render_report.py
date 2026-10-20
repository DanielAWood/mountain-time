#!/usr/bin/env python3
"""Render a task-shepherd session.json into a self-contained report.html.

Usage: render_report.py <session-dir>
"""
import json
import os
import sys
from pathlib import Path

PLACEHOLDER = "__SESSION_JSON__"


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    session_dir = Path(sys.argv[1]).expanduser()
    session = json.loads((session_dir / "session.json").read_text(encoding="utf-8"))
    template = (Path(__file__).resolve().parent / "report-template.html").read_text(encoding="utf-8")

    # Escaping "</" stops verbatim finding text from closing the <script> tag early.
    embedded = json.dumps(session, ensure_ascii=False).replace("</", "<\\/")
    html = template.replace(PLACEHOLDER, embedded)

    out = session_dir / "report.html"
    tmp = out.with_suffix(".html.tmp")
    tmp.write_text(html, encoding="utf-8")
    os.replace(tmp, out)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
