TO-DO

* Data#8: drive Level 2 from Level 1 data, which deletes the fourteen-club list in `LevelLoader.loadAllLevel2Clubs`
* Data#1: make the suite safe to run in parallel, so CI can drop `swift test --no-parallel`
* Consider a SwiftLint step in CI as well, so violations gate pull requests rather than only local builds
* Untested: to-many relationship conflicts under the merge policy (see Data#12)

---------------------------------------------------------------------------

### 2.11.4 (GitHub commit ???????) ??-08-2026

API

* __Loader sequencing__. New `LevelLoader.loadAllLevels(usedContainer:isBeingTested:useOnlyInBundleFile:)`. Runs one complete load pass — Level 0 awaited to completion, then Level 1, then all fourteen Level 2 club loaders concurrently — and returns only once the last loader has finished. The sequencing and the club list move here from the two apps, which each implemented them separately (Data#12).
* __`Level1JsonReader` no longer global.__ `Level1JsonReader.load(...)` and `Level1JsonReader.init(...)` take a `history:` parameter. It is defaulted, so existing calls compile unchanged.
* Removed `Level1JsonReader.level1History`. Neither app referenced it.
* Include-file cycles for iOS 17. `Level1History` is no longer restricted to iOS 18 / macOS 15.

BEHAVIOUR

* Background contexts created for loading always use `mergeByPropertyStoreTrump`. Consuming apps no longer choose: they previously disagreed, and the `Expertise.isSupported` invariant depends on the load sequencing rather than on the merge policy.
* The visited-file guard against Include loops is now one instance per load pass instead of a process-global singleton. A second pass in the same process no longer reports every Level 1 file as a duplicate, and `Model.deleteCoreDataObjects` no longer has to clear it.
* iOS 17 gains real Include cycle detection. It previously only capped nesting depth at 10, because the guard needed `Mutex` (iOS 18+); it now uses `OSAllocatedUnfairLock` (iOS 16+).

STRUCTURAL

* SwiftLint runs on every build, via `Plugins/RunSwiftLint` — the package equivalent of the apps' "Run SwiftLint" build phase, since a package has no `.xcodeproj`.
* New `LevelLoaderTest`: Level 0 saves before any Level 2 loader starts, a full pass downgrades none of Level 0's expertises, and two passes in one process do not trip the visited-file guard.
* 97 tests, up from 86.

DOCUMENTATION

* README: the three-level section now describes `LevelLoader` rather than stating that sequencing is the consuming app's responsibility. New "Linting" section.
* Release notes for the Data package created.

---------------------------------------------------------------------------

Releases before 2.11.4 predate this file. See the git tags and their GitHub release descriptions.
