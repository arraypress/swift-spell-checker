# Swift SpellChecker

The system's own dictionaries — 44 languages on a Mac, already on the machine — and
the same ones on iOS. One API over `NSSpellChecker` and `UITextChecker`.

```swift
import SpellChecker

let found = try SpellChecker.check("The cat sat on the tabel.")
found.first?.word          // "tabel"
found.first?.suggestions   // ["table", "Abel", "label"]
found.first?.line          // 1

let (fixed, applied) = try SpellChecker.corrected("Please recieve teh parcel.")
// "Please receive the parcel."

let (polished, _) = Typography.polish("She said \"hello\" -- quietly.")
// "She said “hello” — quietly."                      (macOS only)

SpellChecker.complete("keybo", language: "en_GB")   // ["keyboard", "keyboards", "keyboardist", …]
SpellChecker.suggestions(for: "recieve")            // ["receive", "relieve"]
```

No download, no network, no model. On the Mac `AppKit` is needed but a running
`NSApplication` is not, so this works from a plain command-line tool. On iOS,
tvOS, visionOS and Catalyst the same calls go through `UITextChecker` — see
**On iOS** below for the two ways that platform differs.

## Completions and suggestions

`complete(_:language:limit:)` is a keyboard's suggestion strip: the words a
prefix could become, commonest first. Measured on macOS 27, `en_GB`:

| prefix | result | ms |
|---|---|---|
| `th` | this, that, the, thanks, they | 4 |
| `keybo` | keyboard, keyboards, keyboardist, keyboarding | 3 |
| `colou` | colourful, colours, colour, colouring | 2 |
| `colo` (en_US) | color, colors, colorful | 3 |
| `colo` (en_GB) | colonel, colonial, cologne | 3 |
| `xqz` | nothing — no guessing | 3 |

`suggestions(for:language:limit:)` is the other direction: alternatives for
a word that may be wrong — `recieve` → receive, relieve. Both are what
``check`` already uses per misspelling, exposed on their own so a caller can
ask about one word without checking a document.

## On iOS

Same dictionaries, smaller API. The differences, measured on an iPhone 17
Pro simulator and stated rather than hidden:

- **No automatic language identification.** `UITextChecker` requires a
  language, so `language: nil` means the current locale's dictionary — not
  "work it out". Text in another language needs its code passed.
- **Dialect codes only.** iOS lists `en_GB`, `en_US`, … and no bare `en`, so
  a code resolves exact → base (`fr_CA` → `fr`) → any dialect (`en` → `en_GB`).
  Only the dictionaries the device has are listed; the simulator ships
  English alone, so `fr_CA` throws `SpellError.unknownLanguage` there.
- **No single confident correction.** `Misspelling.correction` is always
  nil on iOS, so `corrected(_:)` returns the text unchanged there. Show
  `suggestions` instead — that is what a keyboard does anyway.
- **One result per unknown word.** A run like `teh teh teh` is three
  misspellings on iOS; the Mac merges it into one.
- **Latency.** Completions measured 55–66 ms a call on the simulator against
  4 ms on the Mac — with one shared `UITextChecker`. A fresh instance per
  call measured 250 ms, which is why the engine keeps one. Real devices are
  faster than the simulator; debounce per keystroke regardless.

`Typography` (smart quotes and dashes) is macOS only: the substitutions come
from `NSSpellChecker`'s text-checking types, and UIKit exposes no public
equivalent.

Everything is `@MainActor`, which is what `UITextChecker` demands and what a
text field is on anyway.

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

28 tests on macOS and 18 on the iOS simulator (`xcodebuild test -scheme
SpellChecker -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`). The
Mac-only behaviours — automatic language identification, confident
corrections, merged runs, `Typography` — are guarded with `#if os(macOS)`;
the iOS run has its own tests for each place the platform differs. Every
number in this README comes from one of those runs.

## Licence

MIT.
