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
Retiring the two-file split (delete `root`, rename `root_` → `root`) is vdhamer/Photo-Club-Hub#676.

When working out what the apps actually display, follow the `root_` include chain. Reading `root.level1.json`
gives plausible but wrong answers.
