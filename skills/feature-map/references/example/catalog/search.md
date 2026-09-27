---
feature: search
starts_at: ["web:search-dialog", "cli:shell"]
requires: [demo-user, seeded-notes]
---

# Search notes

A user can find notes by title or body text, open a match, and tell "no matches" apart from a search that failed.

## Scenario: title and body match

- **Given** at `web:search-dialog`.
- **When** the user searches a title word. Run `control-notes browser fill --role searchbox --name "Search notes" --value "quarterly"`.
- **Then** "Search results" contains "Quarterly plan" and not "Grocery list". Check `control-notes browser expect --role list --name "Search results" --contains "Quarterly plan" --not-contains "Grocery list"`.
- **When** the user searches a body word. Run `control-notes browser fill --role searchbox --name "Search notes" --value "budget"`.
- **Then** "Quarterly plan" stays listed with a body excerpt. Capture `control-notes browser snapshot --aria --path artifacts/search/body-match.aria.txt` and `control-notes browser screenshot --path artifacts/search/body-match.png`.

## Scenario: empty state and clear

- **Given** at `web:search-dialog`.
- **When** the user searches a word no note contains. Run `control-notes browser fill --role searchbox --name "Search notes" --value "volcano"`.
- **Then** status "No matching notes" appears. Check `control-notes browser expect --role status --name "No matching notes"`.
- **When** the user chooses "Clear search". Run `control-notes browser click --role button --name "Clear search"`.
- **Then** the searchbox is empty and region "Recent notes" is shown. Capture `control-notes browser snapshot --aria --path artifacts/search/cleared.aria.txt`.

## Scenario: search from CLI

- **Given** at `cli:shell`.
- **When** the user searches a title word. Run `control-notes cli -- notes search "quarterly" --format json`.
- **Then** exit code is 0 and stdout is one object titled "Quarterly plan". Capture to `artifacts/search/cli-match.txt`.
- **When** the user searches a word no note contains. Run `control-notes cli -- notes search "volcano" --format json`.
- **Then** exit code is 0 and stdout is `[]`. Capture to `artifacts/search/cli-miss.txt`.

## Gotchas

- Results update after a debounce. Wait on the results list or the empty status, never a fixed sleep.
- Archived notes are excluded unless "Include archived" is on.
- The CLI prints human-readable output by default. Use `--format json` for assertions.
