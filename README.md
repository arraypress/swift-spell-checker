# Swift SpellChecker

macOS's own dictionaries — 44 languages, already on the machine.

```swift
import SpellChecker

let found = try SpellChecker.check("The cat sat on the tabel.")
found.first?.word          // "tabel"
found.first?.suggestions   // ["table", "Abel", "label"]
found.first?.line          // 1

let (fixed, applied) = try SpellChecker.corrected("Please recieve teh parcel.")
// "Please receive the parcel."

let (polished, _) = Typography.polish("She said \"hello\" -- quietly.")
// "She said “hello” — quietly."
```

No download, no network, no model. `AppKit` is needed; a running
`NSApplication` is not, so this works from a plain command-line tool.

## Grammar is not here, on purpose

`NSSpellChecker` exposes grammar checking. On macOS 27 it **finds nothing** —
measured across six blatantly ungrammatical sentences ("Me and him goes to the
store", "She don't have no money", "I has a apple"), in four language
settings, through both `checkGrammar` and the `.grammar` checking type. Zero
results, every time. Apple ships no grammar plugin; the API is a hook for one.
Reporting "no grammar problems" from that would be a lie told confidently.

## The language is process state, not a parameter

`language` defaults to `nil`, which lets macOS identify the language itself.
That is both accurate and the safe choice, because **pinning the wrong
language does not fail — it floods**. Measured: pinning `fr` on a Spanish
sentence flags six ordinary Spanish words; pinning `es` on English flags
"also". Pass one only when the dialect matters — `en_US` flags *colour*,
`en_GB` does not.

The checker's language is global to the process, so `check` saves and restores
it. Without that, one call with `language: "de"` quietly changes the answer
every later call gives.

Two more measured details this handles for you:

- The gate on a language code is `setLanguage`, not membership of
  `availableLanguages`. `en_US` and `fr_CA` are both accepted and neither
  appears in that list.
- Suggestions are fetched with `language: nil`. With automatic identification
  on, passing an explicit code returns an empty list rather than an error, so
  the alternatives silently vanish.

## What `corrected` will and will not touch

Only words macOS offers a confident single correction for. A word with several
plausible alternatives and no clear winner — most names — is left exactly as
it was, because a rewrite the author did not ask for is worse than a squiggle
they can ignore. Replacements run back to front so earlier fixes do not shift
later offsets.

One edge, measured: a run of adjacent unknown tokens (`"teh teh teh"`) comes
back as a **single** result covering all of it, with no suggestions.

## Finding in one copy, applying to another

`SpellChecker.edits(for:)` and `Typography.edits(for:)` hand back the
replacements without making them, and `Replace.apply(_:to:)` makes them
back to front. That split is what lets a caller blank a README's code
blocks before checking — otherwise every identifier comes back misspelled —
and still write the original file back with its code intact. Masking
preserves every offset, so the edits transfer exactly.

## Typography

`Typography.polish` applies smart quotes and dashes through the same
`NSTextCheckingResult` machinery behind Smart Quotes in every Mac text field —
which is why it gets `it's` and `'90s` right where a search-and-replace gets
them backwards.

## Tested

24 tests, including the flooding, the dialect disagreement, the language
restore, back-to-front replacement, and columns counted in Characters rather
than UTF-16 units so an emoji earlier in the line moves the column by one,
and edits found in a masked copy landing correctly on the original.

## Licence

MIT.
