---
feature: create-note
starts_at: ["web:note-editor[new]", "cli:shell"]
requires: [demo-user]
---

# Create a note

A user can save a titled note from the browser or the CLI, discard an unfinished draft, and see the saved note from a second view.

## Scenario: save from browser

- **Given** at `web:note-editor[new]`, no note titled "Release checklist" exists.
- **When** the user enters a title and body. Run `control-notes browser fill --role textbox --name "Title" --value "Release checklist"` and `control-notes browser fill --role textbox --name "Body" --value "Tag and publish"`.
- **Then** "Save note" is enabled. Check `control-notes browser expect --role button --name "Save note" --enabled`.
- **When** the user chooses "Save note". Run `control-notes browser click --role button --name "Save note"`.
- **Then** status "Note saved" appears and the page is at `web:note-editor[existing]`. Check `control-notes browser expect --role status --name "Note saved"`.
- **When** the user returns to the list and reopens the note. Run `control-notes browser click --role link --name "All notes"` and `control-notes browser click --role link --name "Release checklist"`.
- **Then** the editor shows both saved values. Capture `control-notes browser snapshot --aria --path artifacts/create-note/reopened.aria.txt` and `control-notes browser screenshot --path artifacts/create-note/reopened.png`.

## Scenario: cancel draft

- **Given** at `web:note-editor[new]`.
- **When** the user types a title and chooses "Cancel". Run `control-notes browser fill --role textbox --name "Title" --value "Discard me"` and `control-notes browser click --role button --name "Cancel"`.
- **Then** the page is at `web:home` and the list has no "Discard me". Check `control-notes browser expect --role link --name "Discard me" --absent`, then capture `control-notes browser snapshot --aria --path artifacts/create-note/cancelled.aria.txt`.

## Scenario: save from CLI

- **Given** at `cli:shell`, no note titled "CLI note" exists.
- **When** the user creates a note. Run `control-notes cli -- notes create --title "CLI note" --body "Created from terminal" --format json`.
- **Then** exit code is 0 and stdout has the new note's id and title. Capture the command, stdout, stderr, and exit code to `artifacts/create-note/cli-create.txt`.
- **When** the user lists notes. Run `control-notes cli -- notes list --format json`.
- **Then** the list includes "CLI note". Capture it to `artifacts/create-note/cli-list.txt`.

## Gotchas

- Pressing `n` with focus in a textbox types the letter instead of opening a new editor.
- Titles are trimmed on save. Assert the rendered title, not the draft input.
- "Note saved" alone is not proof. Reopen the note from the list.
- Delete "Release checklist" and "CLI note" in cleanup (`control-notes cli -- notes reset --user demo@notes.test`), but keep their artifacts.
