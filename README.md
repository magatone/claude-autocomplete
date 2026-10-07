![english-autocomplete](assets/banner.png)

# english-autocomplete

**English** | [한국어](README.ko.md)

A Claude Code plugin that suggests English words above the prompt box while you type,
like a phone keyboard. Type two or more letters of an English word and up to five
suggestions appear, most common first. The case you started with is kept
(`Recom` -> `Recommend`).

Requires Claude Code 2.1.292 or later (uses the `prompt.autocomplete` plugin event).

## Install

In a Claude Code terminal session:

```
/plugin install english-autocomplete --marketplace magatone/claude-autocomplete
```

Answer `y` to add the marketplace, then pick a scope (user scope is the default).

## Usage

1. Type at least two letters of an English word in the prompt box (for example, `recom`).
2. Up to five suggestions appear above the prompt box, most common first.
3. Use the up and down arrow keys to pick a word.
4. Press `Tab` to replace what you typed with the selected word.

## Develop

```
claude --plugin-dir ./claude-autocomplete
claude plugin test ./claude-autocomplete
```

## Roadmap

A Codex version is planned and coming soon.

## Other languages

This README is available in English and Korean. Support for other languages
will be added once there is demand for them.

## License

- Code: MIT, see `LICENSE`.
- Word list (`data/wordfreq-en-25000-log.json`): from
  [aparrish/wordfreq-en-25000](https://github.com/aparrish/wordfreq-en-25000),
  exported from [wordfreq](https://github.com/rspeer/wordfreq) by Robyn Speer.
  wordfreq data is licensed [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/);
  the word list is redistributed under the same license.
  It is not filtered for offensive words.
