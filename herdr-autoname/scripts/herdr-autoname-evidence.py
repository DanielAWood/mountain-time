#!/usr/bin/env python3
"""Flatten the tail of a Claude Code transcript into labelled evidence lines.

Usage: herdr-autoname-evidence.py <transcript.jsonl>

Prints the recent turns of a session - assistant and user text, and which
tools and subagents were used - oldest line first, clipped to a small budget.
Slash commands and spawned subagents are the clearest phase signals in a
transcript, so a tool call is rendered with its skill or subagent_type rather
than by name alone.

This is the evidence herdr-autoname.sh hands the labeller to judge what phase
a session is in, so recency matters far more than completeness: every limit on
how much of the transcript to keep is a tail. Only the per-line clips below
take the start of the text.
"""

import json
import os
import sys

TAIL_BYTES = 400_000            # plenty for the last few turns of any session
MAX_TRANSCRIPT_LINES = 400      # JSONL lines parsed out of that tail
MAX_EVIDENCE_LINES = 40
MAX_OUTPUT_CHARS = 2600
MAX_CHARS_PER_LINE = 300
MAX_CHARS_PER_TOOL_DETAIL = 140

# The most phase-revealing argument of a tool call, in preference order.
TOOL_DETAIL_KEYS = ("skill", "subagent_type", "description", "command", "file_path", "prompt")


def clip_to_one_line(text, limit=MAX_CHARS_PER_LINE):
    return " ".join(str(text).split())[:limit]


def tool_detail(tool_input):
    if not isinstance(tool_input, dict):
        return ""
    for key in TOOL_DETAIL_KEYS:
        if tool_input.get(key):
            return clip_to_one_line(tool_input[key], MAX_CHARS_PER_TOOL_DETAIL)
    return ""


def content_blocks(message):
    content = message.get("content")
    if isinstance(content, str):
        return [{"type": "text", "text": content}]
    return content if isinstance(content, list) else []


def format_evidence_line(role, block):
    kind = block.get("type")
    if kind == "text":
        text = clip_to_one_line(block.get("text") or "")
        return f"{role}: {text}" if text else None
    if kind == "tool_use":
        name = block.get("name") or "tool"
        detail = tool_detail(block.get("input") or {})
        return f"assistant used {name}: {detail}" if detail else f"assistant used {name}"
    return None


def read_tail(path):
    with open(path, "rb") as fh:
        fh.seek(0, os.SEEK_END)
        start = max(0, fh.tell() - TAIL_BYTES)
        fh.seek(start)
        lines = fh.read().decode("utf-8", "replace").splitlines()
    if start:
        del lines[0]          # a mid-file seek lands inside a line
    return lines


def main():
    if len(sys.argv) < 2:
        return 0
    try:
        lines = read_tail(sys.argv[1])
    except OSError:
        return 0

    evidence_lines = []
    for line in lines[-MAX_TRANSCRIPT_LINES:]:
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        # A transcript line can be valid JSON without being an object - a bare
        # `null` or `[]` is enough to make the lookups below raise.
        if not isinstance(entry, dict):
            continue
        if entry.get("isSidechain"):      # subagent chatter, not the session
            continue
        message = entry.get("message")
        if not isinstance(message, dict):
            message = {}
        role = message.get("role") or entry.get("type")
        if role not in ("user", "assistant"):
            continue
        for block in content_blocks(message):
            if isinstance(block, dict):
                formatted = format_evidence_line(role, block)
                if formatted:
                    evidence_lines.append(formatted)

    print("\n".join(evidence_lines[-MAX_EVIDENCE_LINES:])[-MAX_OUTPUT_CHARS:])
    return 0


if __name__ == "__main__":
    sys.exit(main())
