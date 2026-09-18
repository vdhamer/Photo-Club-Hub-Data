# CLAUDE.md

Guidance for AI coding assistants (e.g. Claude Code) working in this repository.

## Planning & process live in GitHub, not local files

GitHub is the technical and process source of truth across the Photo Club Hub repos
(Photo-Club-Hub, Photo-Club-Hub-Data, Photo-Club-Hub-HTML). Implementation plans, design
rationale, and follow-up work belong in **GitHub issues**, not in local `.md` files — the
maintainer and other contributors do not read local planning files.

- When you produce a plan or capture follow-up work, write it into the relevant GitHub issue
  (create one if needed) and make that issue self-sufficient: code sketches, file paths,
  decisions, and verification steps.
- Do not leave parallel local plan files; they go stale and nobody reads them.
- A short pointer in your own notes/memory is fine, but the content must live in GitHub.

## Use the `swift-concurrency-pro` skill for concurrency work

This package owns the loading of all JSON levels, so it is where the concurrency lives: background
contexts per level, a task group across Level 2 clubs, and the ordering rules that protect the
`Expertise` uniqueness constraint. Load the `swift-concurrency-pro` skill (Paul Hudson / twostraws)
before writing or reviewing any of it.

- It reviews for concurrency correctness, modern API usage, and the usual async/await traps —
  actor isolation, reentrancy, assumptions about when a `Task` starts.
- If the skill is not installed in your environment, say so rather than proceeding silently, and
  state plainly which concurrency questions you could not settle without compiling and testing.

## Tests read fixtures, never production JSON

A test that needs a JSON file reads a frozen fixture from `Tests/Photo Club Hub DataTests/JSON/`, not one of the
production files in `Sources/Photo Club Hub Data/JSON/`. Production data is edited routinely (a new member, an
extra expertise), and a test that asserts on it goes red on correct work.

- Every fixture file name ends in `Test` (`fgDeGenderTest.level2.json`, `languagesTest.level0.json`), without exception.
  The requirement is a name no production file uses; the suffix is how that is guaranteed at a glance. A fixture
  sharing a production file's name is silently shadowed: the bundle lookup finds the package's own copy first, so
  the test reads production data while appearing to use its fixture.
- Do not load a Level 2 fixture through a `*MembersProvider`, which requests the club's real nickname. Call
  `Level2JsonReader.load` with the fixture's nickname, and make the `nickName` inside the fixture match it.
- The one exception, `LevelLoaderTest`, has the production file set itself as its subject. What it may assert is
  in README.md under "Tests run against frozen data".
- The weekly sweep fails when production uses a JSON key path that no fixture contains
  (`scripts/check-fixture-coverage.py`). Add the field to a fixture, re-check the counts the tests assert, and
  consider a test for it. Do not weaken the check to get it green.

## The Level 1 entry point is `root_.level1.json`, not `root.level1.json`

`LevelLoader.loadAllLevels()` starts the Level 1 tree at `builtInLevel1RootName` (`"root_"`, `LevelLoader.swift:22`)
unless a caller passes `level1RootURL` (vdhamer/Photo-Club-Hub#829), which neither app does. So both apps start at
`root_.level1.json`. That file is header-only: it includes `clubsNL.level1.json` (which in turn includes one
`clubsNLxx` file per Fotobond Afdeling, `xx` being the afdeling number, as an empty placeholder where no club is
listed yet) plus `museums.level1.json`. Every club and museum record arrives through those includes, except the two
template clubs, which only the hardcoded Level 2 loaders create (until Data#8).

```
root_.level1.json                header only
├── clubsNL.level1.json          header only
│   ├── clubsNL01.level1.json    Groningen
│   ├── clubsNL02.level1.json    Friesland
│   ├── clubsNL03.level1.json    Drenthe-Vechtdal
│   ├── clubsNL04.level1.json    Transijssel
│   ├── clubsNL05.level1.json    Twente
│   ├── clubsNL06.level1.json    Gelderland Zuid
│   ├── clubsNL07.level1.json    Utrecht-'t Gooi
│   ├── clubsNL08.level1.json    Noord-Holland Noord
│   ├── clubsNL09.level1.json    Kennemerland
│   ├── clubsNL10.level1.json    Amsterdam
│   ├── clubsNL11.level1.json    Zuid-Holland Noord
│   ├── clubsNL12.level1.json    Zuid-Holland Zuid
│   ├── clubsNL14.level1.json    Zeeland              (there is no Afdeling 13)
│   ├── clubsNL15.level1.json    Brabant West
│   ├── clubsNL16.level1.json    Brabant Oost
│   └── clubsNL17.level1.json    Limburg
└── museums.level1.json          lists museums itself, and includes one file per country
    ├── museumsAU.level1.json
    ├── museumsCN.level1.json
    ├── museumsDE.level1.json
    ├── museumsGB.level1.json
    ├── museumsJP.level1.json
    ├── museumsNL.level1.json
    └── museumsUS.level1.json
```

Outside the tree: `root.level1.json` (the legacy flat file, see below) and the template clubs' Level 1 files.

`root.level1.json` (no underscore) is the legacy flat file from before the Include feature
(vdhamer/Photo-Club-Hub#638). It still sits in both repos' JSON folders with stale copies of records, but no
current app code path loads it — the only remaining caller of `Level1JsonReader`'s default `fileName: "root"`
is a SwiftUI preview (`OrganizationViewMap.swift:103` in the iOS app).

It is not inert, though: `FetchAndProcessFile.dataSourcePath` points at
`raw.githubusercontent.com/vdhamer/Photo-Club-Hub/main/JSON/`, so **app versions before 2.9.0 still fetch
`root.level1.json` from GitHub main at runtime** — they predate Include support and would ignore the include
list. Data fixes that those versions should see must be applied there too, not only in the include files.
Retiring the two-file split (delete `root`, rename `root_` → `root`) is Data#45.

When working out what the apps actually display, follow the `root_` include chain. Reading `root.level1.json`
gives plausible but wrong answers.
