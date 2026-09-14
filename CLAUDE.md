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

- Give every fixture a name no production file uses; the convention is a `Test` suffix
  (`fgDeGenderTest.level2.json`). A fixture that shares a production file's name is silently shadowed: the bundle
  lookup finds the package's own copy first, so the test reads production data while appearing to use its fixture.
- Do not load a Level 2 fixture through a `*MembersProvider`, which requests the club's real nickname. Call
  `Level2JsonReader.load` with the fixture's nickname, and make the `nickName` inside the fixture match it.
- The one exception, `LevelLoaderTest`, has the production file set itself as its subject. What it may assert is
  in README.md under "Tests run against frozen data".
- The weekly sweep fails when production uses a JSON key path that no fixture contains
  (`scripts/check-fixture-coverage.py`). Add the field to a fixture, re-check the counts the tests assert, and
  consider a test for it. Do not weaken the check to get it green.

## The Level 1 entry point is `root_.level1.json`, not `root.level1.json`

`LevelLoader.loadAllLevels()` hardcodes `let fileName = "root_"` (`LevelLoader.swift:52`), so both apps start
the Level 1 tree at `root_.level1.json`. That file is header-only: it includes `clubsNL.level1.json` (which in
turn includes `clubsNL03` and `clubsNL16`) plus `museums.level1.json`. Every club and museum record arrives
through those includes.

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
