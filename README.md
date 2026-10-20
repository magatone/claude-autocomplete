![english-autocomplete](assets/banner.png)

# english-autocomplete

**English** | [한국어](README.ko.md)

A Claude Code plugin that suggests English words above the prompt box while you type,
like a phone keyboard. Type two or more letters of an English word and up to five
suggestions appear, most common first. The case you started with is kept
(`Recom` -> `Recommend`).

Requires Claude Code 2.1.292 or later (uses the `prompt.autocomplete` plugin event).

## Install

### Claude Code

In a Claude Code terminal session:

```
/plugin install english-autocomplete --marketplace magatone/claude-autocomplete
```

Answer `y` to add the marketplace, then pick a scope (user scope is the default).

### Codex CLI (`codex-auto`, fixed version)

**Use `codex-auto` to run Codex CLI with native English word completion. This release is fixed at Codex 0.161.0 and does not support automatic updates.** Updating official `codex` does not update `codex-auto`; `codex-auto update` is not supported.

It shares the existing local Codex account, settings and sessions. Type two English letters, select with Up/Down, and press Tab to insert. Enter sends your prompt. Typo correction and saved shortcuts below are Claude plugin features.

This is a **source release**: build tools are required and no prebuilt executable is included. Windows was tested locally; macOS build instructions are unverified. Follow [the Windows/macOS installation steps](codex/README.md), then run:

```sh
codex-auto --version
codex-auto
```

Expected version: `codex-cli 0.161.0`. Version synchronization and automatic-update experiments are paused and preserved on [`feat/codex-version-sync`](https://github.com/magatone/claude-autocomplete/tree/feat/codex-version-sync) and [draft PR #2](https://github.com/magatone/claude-autocomplete/pull/2).

## Usage

1. Type at least two letters of an English word in the prompt box (for example, `recom`).
2. Up to five suggestions appear above the prompt box, most common first.
3. Use the up and down arrow keys to pick a word.
4. Press `Tab` to replace what you typed with the selected word.

## Typo help

Misspelt a word? When nothing matches what you typed, the plugin suggests the words you
probably meant, each marked `typo?`. Pick one and press `Tab` to fix it.

```
   deploy        typo?
   deployment    typo?
❯ depoly
```

It forgives one slip: two letters swapped (`depoly`), a missing letter (`funtion`),
an extra letter (`commmit`) or a wrong letter (`deplay`). It starts at four letters,
assumes the first letter is right, and stays quiet while you type correctly.
In our test it caught 58 of 60 common typos and never showed up while typing correctly.

## Shortcuts

Save a short key for a phrase you type often, then type the key and press `Tab`.
For example, register `ptg` for `push to github`: typing `ptg` shows `push to github`
at the top of the suggestions.

Register shortcuts either way. Both use the same list, which stays after you restart Claude Code.

**With a command**

```
/shortcut add ptg push to github
/shortcut list
/shortcut remove ptg
```

**By asking Claude**

> Add a shortcut: ptg means push to github

You can also ask Claude to show or remove your shortcuts.

A key is two or more letters or digits starting with a letter (`ptg`, `pr2`), not case sensitive.
Shortcuts appear before word suggestions.

## Work vocabulary

Besides everyday English, the plugin knows about 900 words people use at work in Claude Code,
grouped in `data/terms/`: `common`, `planning`, `frontend`, `backend`, `infra`, `devtools`,
`design`, `ai` (LLMs and agents), `ax` (bringing AI into a team), and `tools` (proper names and
acronyms such as `TypeScript` or `LLM`, kept in their own case).
Up to three of these come first, so `comm` suggests `command` and `commit` before `community`.
When you type three letters or fewer, only one leads, so everyday words still show up.
To add words, put one per line in any `.txt` file in `data/terms/`.

## What's new

- **0.6.1** Document the usable fixed-version `codex-auto` CLI and pause automatic-update experiments. Source-build distribution; no prebuilt binaries.

- **0.6.0** Separate CLI implementation for Codex: launch the modified native-composer experiment with `codex-auto`.

- **0.5.0** Typo help: suggests the word you meant when nothing matches, marked `typo?`.
- **0.4.0** About 300 more work terms: AI, AX (bringing AI into a team), dev tooling, acronyms and AI tools.
- **0.3.0** Shortcuts: `/shortcut add ptg push to github`, or ask Claude.
- **0.2.0** Work vocabulary by role, so `comm` suggests `commit` first.
- **0.1.0** First release: English word suggestions in the prompt box.

## Develop

```
claude --plugin-dir ./claude-autocomplete
claude plugin test ./claude-autocomplete
```

## Roadmap

A native-composer Codex prototype was built as a separate modified CLI. Codex plugin/skill integration has not been implemented. See [setup and limitations](codex/README.md).

## Other languages

This README is available in English and Korean. Support for other languages
will be added once there is demand for them.

## License

- Code and the role lists in `data/terms/`: MIT, see `LICENSE`.
- Word list (`data/wordfreq-en-25000-log.json`): from
  [aparrish/wordfreq-en-25000](https://github.com/aparrish/wordfreq-en-25000),
  exported from [wordfreq](https://github.com/rspeer/wordfreq) by Robyn Speer.
  wordfreq data is licensed [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/);
  the word list is redistributed under the same license.
  It is not filtered for offensive words.
