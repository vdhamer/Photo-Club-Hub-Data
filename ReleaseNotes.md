TO-DO

* Data#8: drive Level 2 from Level 1 data, which deletes the fourteen-club list in `LevelLoader.loadAllLevel2Clubs`
* Data#1: make the suite safe to run in parallel, so CI can drop `swift test --no-parallel`
* Consider a SwiftLint step in CI as well, so violations gate pull requests rather than only local builds
* Untested: to-many relationship conflicts under the merge policy (see Data#12)

---------------------------------------------------------------------------

### 3.0.3 (GitHub commit ???????) ??-09-2026

API

* __`MemberPortfolio.latestImageSeen` is gone.__ An optional `Boolean` (default `NO`) that nothing in any of the three repositories ever read or wrote — only the generated accessor mentioned it. The name and type make the intent legible: a per-member read-marker for a "new images since you last looked" feature, presumably paired with subscribing to a photographer or to a club's members. That feature was never built and has not been on the radar for years, and it had been carried in 33 of the model's 34 versions. Removed from `Photo_Club_Hub_3_0_3` and from `MemberPortfolio+CoreDataProperties.swift`. Dropping an optional attribute is a lightweight-migration change needing no mapping model, and no data is lost because no non-default value was ever written. The generated accessor was `public`, so this is strictly a source-breaking API removal, but it provably had no users outside the package — the same reasoning as Data#19, Data#26 and Data#28 (Data#29).

* __`DeletionScope.expertisesOnly` is gone.__ `Model.DeletionScope` is public, so all three of its cases were, but `.expertisesOnly` had seven call sites and every one was in this package's own tests: it deletes `Expertise`, `LocalizedExpertise` and `PhotographerExpertise` and returns early, which is a fixture reset rather than anything a client wants. Swift has no per-case access control, so the case could not be narrowed the way Data#26 narrowed the load entry points; instead `DeletionScope` keeps `.standard` and `.all`, and an `internal` `Model.deleteExpertises(viewContext:)` serves the tests. The three deletions moved into a shared private helper, so `deleteCoreDataObjects` and the new entry point cannot drift apart. As with Data#19 and Data#26, removing public API is strictly a MAJOR change, but this case provably had no users outside the package: the apps pass `.all` (Photo-Club-Hub, twice) and `.standard` (Photo-Club-Hub-HTML, once), and neither needs a change (Data#28).

STRUCTURAL

* __The Core Data model lives in one place again.__ Two `Photo_Club_Hub.xcdatamodeld` bundles existed: this package's, and a copy inside the iOS app. Only this one was ever loaded — `PersistenceController` resolves the model from `Bundle.module`, and the app-side copy was in no build phase, so nothing was compiled from it. It had drifted to 37 versions against this package's 34, with `Photo_Club_Hub_3_0_3` current here against `Photo_Club_Hub_2_10_1`, which read as three releases of divergence at every glance. It was not: `3_0_1`, `3_0_2` and `3_0_3` are byte-identical to `2_10_1` and to each other — empty version bumps added during app release preparation, a habit predating the model's move into this package. The three are now created here instead, the current version is `Photo_Club_Hub_3_0_3`, and the app-side bundle and its project references are gone. Keeping the content-free versions is deliberate: a shipped version has to stay immutable, because stores in the field are matched by hash and editing one in place breaks automatic migration, so every schema change gets a fresh container and duplicate content is the cheap price. The model version now tracks *this package's* release rather than the app's, which retires the last echo of the release train (Photo-Club-Hub#808). There is no `3_0_0`; none was created at the time, and that is left as history (Data#31).

* __New `PhotographerContentionTest`.__ Level 2 files describe one club each, so the fourteen concurrent loaders normally touch disjoint rows. The exception is a photographer who belongs to two clubs: `Photographer` is constrained on `(familyName_, infixName_, givenName_)`, so both files describe the same row. Four tests pin where the field-by-field merge in `Photographer.update()` holds and where it stops. A birthday already in the store survives two clubs that do not mention one — the guarantee that matters, since a file omitting a birthday must never turn a known birthday back into "unknown". A club supplying a different birthday overwrites the stored one, there being no basis to prefer either. Colliding creates leave exactly one row under either save order. And when the row is created twice before either context saves, the merge policy decides the birthday rather than the field rules, so a nil can win: that costs an offered value rather than a stored one, and the next pass acquires it because by then the row exists. `MergePolicyTest` covers the same mechanism on `Expertise`, where awaiting Level 0 removes the collision; nothing pre-creates photographers (Data#22).

---------------------------------------------------------------------------

### 3.0.2 (GitHub commit 7f2e104) 26-08-2026

STRUCTURAL

* __Weekly cross-repo sweep.__ New `.github/workflows/weekly-sweep.yml` runs on a schedule and compares `scripts/gate-and-stamp.sh` in Photo-Club-Hub against the copy in Photo-Club-Hub-HTML, failing when the two differ. They are meant to be byte-identical and nothing enforced that This package hosts the check because it is the only thing both apps depend on, so a check about *the pair* belongs in neither half, and a copy in each app repo would be two more files to keep in sync. Nothing is added to the package or to its build: the job reads only the two app repos, over public raw URLs, and needs no token. Later modules are appended as sibling jobs rather than as extra steps, so one failing check cannot mask another (Data#23).
* __UK to US spelling.__ `colours` → `colors`, `optimisation` → `optimization`, `behaviour` → `behavior`, `normalised` → `normalized`, across 8 files including the tests. Comments only: no identifier was renamed, so nothing a consumer can observe changed. Consistency with the US-spelled frameworks the code sits on.

API

* __Narrowed the load entry points to `internal`.__ `LevelLoader.loadAllLevels()` is meant to be the way in, but seventeen more `public` load entry points sat beside it: `Level0JsonReader.load()`, `Level1JsonReader.load()`, `Level2JsonReader.load()` and fourteen `*MembersProvider.load()`. Thirty-nine declarations across `ViewModel/ListReaders` and `IndividualClubs` drop to `internal` — not `package`, because all twenty test files use `@testable import` and this is a single-target package, so the wider level would buy nothing. As with Data#19, removing public API is strictly a MAJOR change, but these provably had no users outside the package. It is more than tidiness: a caller could start Level 2 with Level 0 never having run, which is exactly the `Expertise` uniqueness corruption `loadAllLevels()` exists to prevent, so the ordering rule stops being a convention and becomes a guarantee. One consumer had to change — the iOS MapsView preview called `Level1JsonReader`'s fire-and-forget initializer, which also loaded the legacy `root.level1.json` (Photo-Club-Hub#825). `LevelLoader` and `loadAllLevels()` remain public (Data#26).

---------------------------------------------------------------------------

### 3.0.1 (GitHub commit 6bc3474) 25-08-2026

API

* Removed `Settings.showTemplateClubs`. It read a `showTemplateClubs` key that no `Root.plist` ever offered and that nothing ever wrote, so it was permanently `false`, and it had no call site in this package or in either app. The in-app Maps toggle of the same name is `SettingsViewModel.showTemplateClubs` in Photo-Club-Hub, which is a different switch with its own storage and is unaffected. Removing public API is strictly a MAJOR change, but this one provably had no users (Data#19).

DATA

* Fotoclub Kiekus is in "Wanroij", not "Wanroy" — corrected in `clubsNL16.level1.json` and in the legacy `root.level1.json`. "Wanroij" is the official spelling (Photo-Club-Hub#810).
* __One-time database reset.__ `town` is part of `OrganizationID`, so on an existing install the spelling fix is not a rename: it creates a second Fotoclub Kiekus row beside the stale one, because obsolete Level 1 records are not pruned yet (Photo-Club-Hub#349). The reset key therefore becomes `dataResetPending301b4666`, which wipes the database once at first launch of app 3.0.1 (4666) and reloads it clean; `dataResetPending292b4657` moves to `prevUserDefaultsKeys`. A consuming app must carry the same string in its `Settings.bundle/Root.plist`.

---------------------------------------------------------------------------

### 3.0.0 (GitHub commit 5813872) 09-08-2026

A renumbering release: no library code changed. The public API is identical to 2.11.4, so upgrading from 2.11.x needs no source changes in a consumer.

VERSIONING

* __The release train is retired.__ Up to 2.11.x the three Photo Club Hub repositories shared a `major.minor` prefix, which put the compatibility boundary in the second position and made the conventional `.upToNextMajor` pin unsafe for anyone unaware of the local rule. All three were aligned at 3.0.0 once; from then on their versions float independently. This package now uses plain semantic versioning — MAJOR breaks consumers, MINOR adds public API, PATCH fixes — and that number is a contract. The two apps' `MARKETING_VERSION`s are labels for their users and say nothing about this package (Photo-Club-Hub#808, Data#17).
* Consumers pin `.upToNextMajor(from: "3.0.0")`, the range 3.0.0 ..< 4.0.0 and what Xcode generates by default. The previous advice was `.upToNextMinor(from: "2.11.0")`.
* `PhotoClubHubDataVersion.semver` reads `"3.0.0"`, and its documentation now states the rule: the constant must equal the git tag and is updated in the commit that tags the release.
* __No build number.__ The package produces no artifact to number. A candidate handed to another developer is identified by its commit, which their `Package.resolved` records automatically — version *and* revision (Data#17).

STRUCTURAL

* CI checks the `swift-tools-version` floor before building. `CompileCoreDataModelPlugin` needs 6.1 for the URL-based `PackagePlugin` API; below that SwiftPM reports only "build planning stopped due to build-tool plugin failures", naming neither file nor reason. That cost two red runs in August 2026 (Data#15). The floor is a hard requirement, not a release-train number, and is not to be aligned with the app versions.

DATA

* `root.level1.json`: the town of Fotoclub Optika changed from "Duerne" to "Deurne", aligning the legacy flat file with the live `clubsNL16.level1.json`, where the same fix landed in February 2026 and was swept by the 2.9.2 database reset (`dataResetPending292b4657`) before it could strand a duplicate. The legacy file is still fetched at runtime by installs older than 2.9.0 — from the copy in the Photo-Club-Hub repo, changed in the same pass (29bbaa1) — and those installs never saw that reset. Since `town` is part of `OrganizationID`, they gain a second Fotoclub Optika row that nothing prunes (Photo-Club-Hub#349). That is the class of change deliberately held back for Wanroij in Photo-Club-Hub#810; this one went out unnoticed.

DOCUMENTATION

* README: the "shared release train" section is replaced by a "Versioning" section describing plain semver, the `.upToNextMajor` pin, and why there is no build number.
* CLAUDE.md: the Level 1 entry point is `root_.level1.json`, not `root.level1.json`. The latter is the pre-Include legacy file that no current code path loads, but app versions before 2.9.0 still fetch it from GitHub at runtime, so data fixes those versions should see must be applied there too (Photo-Club-Hub#676).

---------------------------------------------------------------------------

### 2.11.4 (GitHub commit 0d7d09e) 07-08-2026

API

* __Loader sequencing__. New `LevelLoader.loadAllLevels(usedContainer:isBeingTested:useOnlyInBundleFile:)`. Runs one complete load pass — Level 0 awaited to completion, then Level 1, then all fourteen Level 2 club loaders concurrently — and returns only once the last loader has finished. The sequencing and the club list move here from the two apps, which each implemented them separately (Data#12).
* __`Level1JsonReader` no longer global.__ `Level1JsonReader.load(...)` and `Level1JsonReader.init(...)` take a `history:` parameter. It is defaulted, so existing calls compile unchanged.
* Removed `Level1JsonReader.level1History`. Neither app referenced it.
* Include-file cycles for iOS 17. `Level1History` is no longer restricted to iOS 18 / macOS 15.

BEHAVIOR

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
