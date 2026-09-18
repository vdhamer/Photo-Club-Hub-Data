TO-DO

* Data#8: drive Level 2 from Level 1 data, which deletes the fourteen-club list in `LevelLoader.loadAllLevel2Clubs`
* Data#1: make the suite safe to run in parallel, so CI can drop `swift test --no-parallel`
* Consider a SwiftLint step in CI as well, so violations gate pull requests rather than only local builds
* Untested: to-many relationship conflicts under the merge policy (see Data#12)

---------------------------------------------------------------------------

### 3.5.0 (GitHub commit ???????) ??-??-2026

_Open for the next cycle. `PhotoClubHubDataVersion.semver` and the `Photo_Club_Hub_3_5_0` model version
were opened when 3.4.0 was tagged; the number is a plan until its own tag exists, and may be overtaken._

BEHAVIOR

* __`PersistenceController` seeds the organization types as soon as the store opens.__
Level 1 loads each include file in its own background context, and every club points at the same `club` row of `OrganizationType`. When that row did not exist yet, two contexts could both insert it, and Core Data threw on the relationship. Both apps were protected because they call `OrganizationType.initConstants` before loading, but `loadAllLevels` itself was not: `LevelLoaderTest`, which starts from an empty in-memory store, aborted once eleven club files loaded in parallel. `PersistenceController.init` now seeds the three rows on a private context before any view or loader runs, and on an existing store that only fetches. The apps' own calls become redundant once they resolve this version, and can be dropped then (Data#60).

DATA

* `clubsNL01`, `clubsNL02`, `clubsNL04` to `clubsNL12`, `clubsNL14`, `clubsNL15`, `clubsNL17` (new), `clubsNL03`, `clubsNL16`, `clubsNL.level1.json`
Fourteen nature photography clubs, none of them Fotobond members, placed in one Level 1 file per Fotobond afdeling, each included from `clubsNL.level1.json`. Five more files (`clubsNL01`, `clubsNL09`, `clubsNL14`, `clubsNL15`, `clubsNL17`) are empty placeholders, so every afdeling now has a file to add clubs to. The fourteen new files are bundled through `Package.swift`. Mirrored identically in the iOS repo's live copy (Data#59).

---------------------------------------------------------------------------

### 3.4.0 (GitHub commit 3daae31) 17-09-2026

STRUCTURAL

* __Tests read only their own frozen JSON fixtures.__
Four Level 2 fixtures (`TemplateMin`, `TemplateMax`, `fgDeGender`, `fgWaalre`) had never actually been read. `FetchAndProcessFile.urlForBundledResource` searches the package's own bundle before the test bundle, so a fixture sharing a production file's name was shadowed by it, and the tests asserted against live data while appearing to use their fixtures. It surfaced when adding three expertises to one fgDeGender member turned CI red on correct work. The fixtures now carry a `Test` suffix with a matching `nickName` inside, and the tests load them through `Level2JsonReader.load` rather than the `*MembersProvider` types, which request a club's real nickname; the expected counts follow the frozen data. `LanguageUpgradeInPlaceTest` and `LoadOrderIndependenceTest` moved from the production `root.level0.json` to `rootTest.level0.json`, which leaves `LevelLoaderTest`, whose subject is the production file set itself, as the one test reading production files. The policy and that exception are written down in README.md ("Tests run against frozen data") and in CLAUDE.md. Tests and documentation only: nothing a consumer can observe changed.

* __Weekly check that the fixtures keep up with production JSON.__
Frozen fixtures mean nothing in the suite notices when production gains a JSON field they lack. A new `weekly-sweep.yml` job runs `scripts/check-fixture-coverage.py`, which compares structure rather than content: every key path used by a production file (the iOS repo's live `JSON/` merged with this package's copy) must occur in some fixture of the same level. A new member adds no key path, so everyday data edits pass; a new or misplaced field fails the sweep, which is the cue to update a fixture, re-check the counts the tests assert, and consider a test for the new field. New values, such as a new expertise id, go unnoticed (Data#55).

* __Weekly check that JuiceBox galleries are well-formed XML.__
The apps find a member's featured image with a regular expression over the club's JuiceBox `config.xml`, and it needs only `imageURL` followed by `thumbURL`. Whether the document parses at all is invisible to it, so a member's row can show the right thumbnail and link while the gallery renders as a blank page, with nothing logged because the regex succeeded. A Lightroom Classic release between 2026-05-26 and 2026-09-12 made that reachable in the field: it writes an empty metadata value as `<div></div>`, and a raw `<` inside the `linkURL` attribute makes the whole document ill-formed. A new `weekly-sweep.yml` job runs `scripts/check-juicebox-galleries.py`, which fetches every distinct `level3URL` in the Level 2 files and parses those whose body carries a `<juiceboxgallery>` root element — asking the server rather than hardcoding which clubs use JuiceBox, and skipping hosts that answer any path with their own HTML. The first run checked 30 galleries and found none malformed; it takes two to three minutes, nearly all of it waiting on other people's servers. The regex itself is unchanged: this reports the damage rather than repairing it (Data#54).

* __One rule for "does this address still need geocoding", and counts built on it.__
The rule existed twice — inside `OrganizationGeocoder.buildWorkItems` for the site generator, and in the iOS Maps screen's own geocoder — with no shared retry or cooldown policy and two spellings of the placeholder written when Apple answers without a name. It now lives once, as `Organization.needsLocalizedAddress(for:)`: true when the organization has no `LocalizedAddress` row for that language, or when the row was derived from coordinates it no longer has. `LocalizedAddress.geocodingCounts(context:)` counts by that same rule and returns `GeocodingCounts` (`total`, `completed`, `waiting`, `onErrorPlaceholders`), counted per (organization × supported language) combination because one combination is one request to Apple — the unit a progress indicator needs. A stored `"Town?"` or `"Country?"` counts as `onErrorPlaceholders` rather than `waiting`: Apple has answered for those coordinates and is not asked again, so waiting does not help. Nothing observable changes in this release: the geocoder now asks the shared rule instead of its own copy, and the counts have no caller yet. Photo-Club-Hub-HTML#271 is the first, warning at *Generate* when placeholders were published and counting down in the footer while translation continues; Data#38 then moves the iOS Maps screen onto the same geocoder (Data#57).

* __Supported languages are declared in Level 0, not inferred from the data.__
Which languages the geocoder translates into, and the website generates pages for, was "every `Language` with at least one expertise translation". That inferred the set from data whose variation is legitimate: one expertise translated into an extra language would have made that language supported, so the geocoder would have started translating into it. Level 0's `languages` entries now carry `"isSupported": true` for English and Dutch, `Language` gains a matching `isSupported` attribute in the new `Photo_Club_Hub_3_4_0` model version (non-optional Boolean defaulting to false, so lightweight migration fills existing rows), and `Language.supportedLanguages(context:)` returns exactly the flagged rows, sorted by ISO code. German stays declared in Level 0 without the key, and so unsupported. The attribute is `public internal(set)`: consumers read it, only the package writes it, and only `Level0JsonReader` passes the value, so rows created for remarks, expertise translations or by `initConstants` never change it. An absent key leaves the stored flag alone, matching the role booleans in a Level 2 file, which `MemberRolesAndStatus` guards with `.exists()`: only an explicit `true` or `false` changes a stored value. So dropping a language's entry and dropping only its `isSupported` line behave identically, and withdrawing support needs `"isSupported": false` or a database reset until the wider obsolete-value handling of Data#39 arrives. The key must reach the live `JSON/root.level0.json` before this version is tagged, since every row starts unflagged and a Level 0 file that flags nothing therefore leaves no language supported at all; older apps ignore the unknown key, their readers requiring only `isoCode` and `languageNameEN` (Data#57).

DATA

* `fcDenDungen.level2.json`
Removed a stray `birthday` placed directly under a member. The same value is also inside that member's `optional`, which is the only place the reader looks, so nothing a user sees changes. Removed identically from the iOS repo's live copy. Found by the new fixture check on its first run (Data#55).

---------------------------------------------------------------------------

### 3.3.0 (GitHub commit 16cdeef) 09-09-2026

BEHAVIOR

* __The default thumbnail no longer points at a private HTTP server.__`
MemberPortfolio.featuredImageThumbnail` returned a hardcoded `http://www.vdhamer.com/...` URL for every photographer without a featured image. That host currently serves no HTTPS at all, so on the generated website, which is published over HTTPS, browsers dropped the image: 90 occurrences across 30 of its 103 pages, and on 18 of those it was the only broken image. Both apps hid this behind an ATS exception for that domain, so it was visible only in a browser (Data#52, Photo-Club-Hub-HTML#264). The image now ships in this repo as `images/placeholderThumbnail.jpg` and is fetched over https from `raw.githubusercontent.com`; it was re-cut square at 512 x 512 — the largest surface showing it is the iOS 160 pt cell at 3x — since the members table renders it in a 1:1 cell and the old 150 x 112 JuiceBox thumbnail was cropped and upscaled to fill it. The picture is deliberately loud — a red circle captioned "No images available here yet" — because its job is to make a photographer or club contact supply a real one, so a quieter replacement would look like an improvement while failing the only test that matters. Its sibling `MemberPortfolio.emptyPortfolioURL`, the portfolio link shown for those same members, still points at the same HTTP host: a navigation rather than a subresource, so no browser blocks it and it was left alone here.

API

* __`Organization.localizedTown` and `Organization.localizedCountry` are gone.__
Each was a single untagged string per organization: one slot, so "the Dutch name" and "the English name" could not both exist, and nothing recorded which was stored. `LocalizedAddress` has modelled this properly for some time — one row per (organization × language) — and both apps moved onto it in Photo-Club-Hub#827. What made removal worth doing rather than merely tidy is that they had become misleading: since nothing writes the underlying column any more, the getter returned its Core Data default, `"Town?"`, for every organization, permanently, while sitting beside the correct `localizedTown(for:)` and being shorter to type. That is the trap shape that cost Photo-Club-Hub#825. Removing public API is strictly MAJOR, but neither app referenced these, so it is treated as MINOR on the same reasoning as Data#19, Data#26 and Data#28 (Data#40).

STRUCTURAL

* __`PersonName` now normalizes the two parts that identify a photographer.__
A `Photographer` is looked up on `(givenName_, infixName_, familyName_)`, so a difference in spelling does not correct a person: it creates a second one, keeping the first alongside it with its memberships and portfolio, and nothing prunes it. `infixName` is therefore lowercased, and a compound family name is written one way whichever way it arrives, with a single hyphen carrying no spaces and the second name keeping the space before its own infix. So `Haaren - van de Kaa`, `Haaren-van-de-Kaa` and `Haaren-Van de Kaa` all arrive as `Haaren-van de Kaa`. Applied in the initializer, which is the only way a `PersonName` is built, so every path gets it including the Level 2 loader; `fullNameWithParenthesizedRole` is synthesized from the normalized parts, while a caller-supplied display name is left alone. **This changes stored values**: consumers correcting existing spellings need a data reset, which is what Photo-Club-Hub build 4667 does. Note the boundary, since it is easy to lose: this tidies parts that have already been separated, while deciding *where* the infix sits in a name read as one string is detection and belongs to whatever produced the parts (Data#50, Photo-Club-Hub#841).

* __New Core Data model version `Photo_Club_Hub_3_3_0`__
With `localizedTownDepr_` and `localizedCountryDepr_` removed from `Organization`. Dropping attributes is compatible with lightweight migration, so no mapping model is needed; a store in the field migrates on first launch after a consumer's version pin moves, and no data is lost because nothing has read those columns since 3.1.0. `Photo_Club_Hub_3_2_0` is untouched, being shipped. The matching entries in `Organization+CoreDataProperties.swift` were removed by hand, as the model's Manual/None codegen requires. `LocalizedAddress.localizedTown_` and `localizedCountry_` are unaffected — they differ from the removed names only by the `Depr_` suffix, and they are the working mechanism.

---------------------------------------------------------------------------

### 3.2.0 (GitHub commit 854c1ef) 01-09-2026

STRUCTURAL

* __New Core Data model version `Photo_Club_Hub_3_2_0`.__ 
Byte-identical to `3_1_0`: this release changes no schema, and a version is created per release regardless so that the model name never lags the version shipping it. A shipped version must stay immutable, because stores in the field are matched by hash, so 3_1_0 is left untouched and a fresh container is opened for the next schema change to edit.

API

* __`LocalizedAddressStrings` is now `LocalizedAddressFields`.__
The plural read as "one string per language", which is the one axis this type does not vary on: it carries the town and the country of *one* address in *one* language, and the per-language dimension is the `LocalizedAddress` rows themselves. "Fields" also survives a third field — a region or a postcode would leave `LocalizedTownCountry` needing another rename. The parameter label follows, `newLocalizedAddressStrings:` becoming `newLocalizedAddressFields:`, keeping its pairing with `newCoordinates:`. Renaming public API is strictly MAJOR, but this type was published two hours earlier in 3.1.0 with no consumer outside this package, so it is treated as MINOR on the same reasoning as Data#19, Data#26 and Data#28. Note that neither MINOR nor PATCH would have protected a consumer here — both are adopted automatically under the `.upToNextMajor(from: "3.0.0")` pin the README recommends — so the number is a statement about what changed rather than a shield (Photo-Club-Hub#827).

---------------------------------------------------------------------------

### 3.1.0 (GitHub commit 2f34b04) 01-09-2026

API

* __`loadAllLevels` accepts a `level1RootURL`.__
An optional URL that replaces the built-in `root_` Level 1 file with one the user named, so a tree about cats or trains can reuse the app without this project's involvement (Photo-Club-Hub#829). Passing it changes two further things. The hardcoded Level 2 club list is skipped, because those fifteen clubs are the production tree's own content and `findCreateUpdate` would inject them into a dataset that never listed them. And no bundled copy may stand in, so a mistyped URL fails visibly instead of quietly serving this project's clubs. Level 0 is loaded in full regardless: its expertises and languages come from this project's own file, cost nothing when a tree external to this project never references them, and the languages are needed either way — a tree wanting its own vocabulary is better served by a Level 0 override, once a use case exists, than by this package guessing whose data a URL holds. `nil` leaves every behavior unchanged.

* __`Organization.localizedTown(for:)` and `Organization.localizedCountry(for:)`.__
Two accessors that answer "what is this organization's town or country in this language", reading the `LocalizedAddress` row for that language and supplying the fallback when no row exists yet. The town falls back to the unlocalized `town` the JSON supplied, which is a real name that simply is untranslated; the country has no unlocalized counterpart on Organization (because it is not supplied in `*.level1.json` or `*.level2.json` files), so it falls back to `LocalizedAddress.unknownCountry` constant. Both consumers had been unwrapping `localizedTown_` / `localizedCountry_` at the call site with fallbacks of their own — `?? ""` and `?? club.town` in the site generator, the deprecated single-slot columns on iOS — which is how the two ended up disagreeing about what an un-geocoded club looks like. Written for Photo-Club-Hub#827, where the iOS Maps screen moves onto language-keyed rows, and it is what Data#38 converges the rest of that screen onto.

* __`LocalizedAddress.localizedTown` and `.localizedCountry` are now public.__
The non-optional wrappers already existed but were package-internal, so the one consumer that needed them reached past them to the underscored attributes instead. Widening them restores the rule that an optional `property_` is read through its non-optional `property`, and it is what makes the two `Organization` accessors above able to return a plain `String`.
Backwwards compatible because this just adds a public (Data#38).

* __`MemberPortfolio.latestImageSeen` is gone.__
An optional `Boolean` (default `NO`) that nothing in any of the three repositories ever read or wrote — only the generated accessor mentioned it. The name and type make the intent legible: a per-member read-marker for a "new images since you last looked" feature, presumably paired with subscribing to a photographer or to a club's members. That feature was never built and has not been on the radar for years, and it had been carried in 33 of the model's 34 versions. Removed from `Photo_Club_Hub_3_1_0` and from `MemberPortfolio+CoreDataProperties.swift`. Dropping an optional attribute is a lightweight-migration change needing no mapping model, and no data is lost because no non-default value was ever written. The generated accessor was `public`, so this is strictly a source-breaking API removal, but it provably had no users outside the package — the same reasoning as Data#19, Data#26 and Data#28 (Data#29).

* __`DeletionScope.expertisesOnly` is gone
.__`Model.DeletionScope` is public, so all three of its cases were, but `.expertisesOnly` had seven call sites and every one was in this package's own tests: it deletes `Expertise`, `LocalizedExpertise` and `PhotographerExpertise` and returns early, which is a fixture reset rather than anything a client wants. Swift has no per-case access control, so the case could not be narrowed the way Data#26 narrowed the load entry points; instead `DeletionScope` keeps `.standard` and `.all`, and an `internal` `Model.deleteExpertises(viewContext:)` serves the tests. The three deletions moved into a shared private helper, so `deleteCoreDataObjects` and the new entry point cannot drift apart. As with Data#19 and Data#26, removing public API is strictly a MAJOR change, but this case provably had no users outside the package: the apps pass `.all` (Photo-Club-Hub, twice) and `.standard` (Photo-Club-Hub-HTML, once), and neither needs a change (Data#28).

STRUCTURAL

* __Level 1 Includes are fetched at the URL they are written with
.__`extractIncludeNames` kept only the base filename of each `level1URLIncludes` entry and recomposed it against the hardcoded `dataSourcePath`, so an include hosted anywhere else was fetched from this repo and 404'd — a root override alone could never have worked. It now returns `Level1Source` values carrying both halves: the URL is fetched, while the name still resolves the embedded copy and keys the visited-file guard and the loop detection. `Level1Source` validates as it constructs — `init(urlString:) throws` a `Level1URLError` saying whether the string is not a URL, is not https, or does not name a `<name>.level1.json` file — so the three inline guards in `extractIncludes` become one `try`, and the app half gets the same rule to validate its Settings field against rather than writing a second one. This changes the bytes on the wire for this project's own includes too, since `root_.level1.json` writes them as `.../Photo-Club-Hub/refs/heads/main/JSON/...` while `dataSourcePath` uses `.../Photo-Club-Hub/main/JSON/`. Both are valid raw.githubusercontent spellings of identical content (Photo-Club-Hub#829).

* __One spelling of "no localized name".__
 Five different values stood for it. The Core Data defaults for `LocalizedAddress.localizedTown_` / `localizedCountry_` ("Town?" / "Country?"), the same defaults on the deprecated `Organization.localizedTownDepr_` / `localizedCountryDepr_`, `"ErrorTown"` / `"ErrorCountry"` in the `Organization` getters, `""` in the `LocalizedAddress` getters, and `"⏳"` in `OrganizationGeocoder`. Of those, the two code fallbacks in the package were unreachable: both sets of attributes were non-optional and carried a `defaultValueString`, so the `??` could never fire, and it was the *model* default that surfaced on an un-geocoded iOS card. The `LocalizedAddress` pair is now genuinely optional in `Photo_Club_Hub_3_1_0` with the `defaultValueString` removed, and the placeholder text lives once, in `LocalizedAddress.unknownTown` / `.unknownCountry`. The `"ErrorTown"` / `"ErrorCountry"` pair will be removed as part of Data#40. `OrganizationGeocoder` wrote `"⏳"` when Apple returned a placemark carrying no city or region name, and now writes the same two constants: with a row present meaning "geocoding ran", a placeholder inside one can only mean Apple had no name, so the distinction the hourglass carried is already implied by the row existing. Published pages show "Town?" / "Country?" for those clubs instead of an emoji. Making an attribute optional and dropping its default is a lightweight-migration change needing no mapping model, and no generated property changed, because Core Data already declared both as `String?` (Photo-Club-Hub#827).

* __The Core Data model lives in one place again.__
 Two `Photo_Club_Hub.xcdatamodeld` bundles existed: this package's, and a copy inside the iOS app. Only this one was ever loaded — `PersistenceController` resolves the model from `Bundle.module`, and the app-side copy was in no build phase, so nothing was compiled from it. It had drifted to 37 versions against this package's 34, with `Photo_Club_Hub_3_1_0` current here against `Photo_Club_Hub_2_10_1`, which read as three releases of divergence at every glance. It was not: `3_0_1`, `3_0_2` and `3_1_0` started out byte-identical to `2_10_1` and to each other — empty version bumps added during app release preparation, a habit predating the model's move into this package. The three are now created here instead, the current version is `Photo_Club_Hub_3_1_0`, and the app-side bundle and its project references are gone. Keeping the content-free versions is deliberate: a shipped version has to stay immutable, because stores in the field are matched by hash and editing one in place breaks automatic migration, so every schema change gets a fresh container and duplicate content is the cheap price. The model version now tracks *this package's* release rather than the app's, which retires the last echo of the release train (Photo-Club-Hub#808). There is no `3_0_0`; none was created at the time, and that is left as history (Data#31).

* __New `PhotographerContentionTest`.__
 Level 2 files describe one club each, so the fourteen concurrent loaders normally touch disjoint rows. The exception is a photographer who belongs to two clubs: `Photographer` is constrained on `(familyName_, infixName_, givenName_)`, so both files describe the same row. Four tests pin where the field-by-field merge in `Photographer.update()` holds and where it stops. A birthday already in the store survives two clubs that do not mention one — the guarantee that matters, since a file omitting a birthday must never turn a known birthday back into "unknown". A club supplying a different birthday overwrites the stored one, there being no basis to prefer either. Colliding creates leave exactly one row under either save order. And when the row is created twice before either context saves, the merge policy decides the birthday rather than the field rules, so a nil can win: that costs an offered value rather than a stored one, and the next pass acquires it because by then the row exists. `MergePolicyTest` covers the same mechanism on `Expertise`, where awaiting Level 0 removes the collision; nothing pre-creates photographers (Data#22).

---------------------------------------------------------------------------

### 3.0.2 (GitHub commit 7f2e104) 26-08-2026

STRUCTURAL

* __Weekly cross-repo sweep.__
 New `.github/workflows/weekly-sweep.yml` runs on a schedule and compares `scripts/gate-and-stamp.sh` in Photo-Club-Hub against the copy in Photo-Club-Hub-HTML, failing when the two differ. They are meant to be byte-identical and nothing enforced that This package hosts the check because it is the only thing both apps depend on, so a check about *the pair* belongs in neither half, and a copy in each app repo would be two more files to keep in sync. Nothing is added to the package or to its build: the job reads only the two app repos, over public raw URLs, and needs no token. Later modules are appended as sibling jobs rather than as extra steps, so one failing check cannot mask another (Data#23).
* __UK to US spelling.__
 `colours` → `colors`, `optimisation` → `optimization`, `behaviour` → `behavior`, `normalised` → `normalized`, across 8 files including the tests. Comments only: no identifier was renamed, so nothing a consumer can observe changed. Consistency with the US-spelled frameworks the code sits on.

API

* __Narrowed the load entry points to `internal`.__
 `LevelLoader.loadAllLevels()` is meant to be the way in, but seventeen more `public` load entry points sat beside it: `Level0JsonReader.load()`, `Level1JsonReader.load()`, `Level2JsonReader.load()` and fourteen `*MembersProvider.load()`. Thirty-nine declarations across `ViewModel/ListReaders` and `IndividualClubs` drop to `internal` — not `package`, because all twenty test files use `@testable import` and this is a single-target package, so the wider level would buy nothing. As with Data#19, removing public API is strictly a MAJOR change, but these provably had no users outside the package. It is more than tidiness: a caller could start Level 2 with Level 0 never having run, which is exactly the `Expertise` uniqueness corruption `loadAllLevels()` exists to prevent, so the ordering rule stops being a convention and becomes a guarantee. One consumer had to change — the iOS MapsView preview called `Level1JsonReader`'s fire-and-forget initializer, which also loaded the legacy `root.level1.json` (Photo-Club-Hub#825). `LevelLoader` and `loadAllLevels()` remain public (Data#26).

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
