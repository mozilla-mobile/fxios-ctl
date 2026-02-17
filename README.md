# 🦊 `fxios`

A CLI tool for managing tasks in the [firefox-ios](https://github.com/mozilla-mobile/firefox-ios) repository.

**NOTE:** This tool is still in **BETA**

## Goals

The goals of this tool are simple:

**1. Provide a thoroughly documented, understandable experience that will reduce tribal knowledge**

**2. Provide easily reproducible commands for all developers & CI**

**3. Provide a central place for important utilities used to manage the firefox-ios repo**

```
⚠️ A possible fourth goal - we're still deciding if this is truly a goal:
Provide a simple, indirect way for new developers to discover tooling used in Swift development (eg. swiftlint)
```

Bonus (slash most important) goal: **be dope by being ridiculously helpful**

If a command doesn't materially achieve one of these goals & the bonus goal, it likely shouldn't be part of `fxios`

## Installation

`fxios` is available through brew.

```bash
brew tap mozilla-mobile/fxios
brew install fxios
```

**NOTE:** installing `fxios` will also install several dependencies through `brew`, that are used for firefox-ios:

- [swiftlint](https://github.com/realm/SwiftLint)
- [node](https://nodejs.org/en)

## Configuration

`fxios` uses a `.fxios.yaml` file in the firefox-ios repository root for configuration and validation that it's in the correct repository.

For the complete configuration reference, see [CONFIGURATION.md](CONFIGURATION.md).

### Quick Start

A minimal `.fxios.yaml` only needs the required `project` field:

```yaml
project: firefox-ios
```

## Development

### Requirements

- macOS 14+
- Swift 6.2+

To use this with the firefox-ios, repo, you will also need the dependencies from that repo.

### Contributing

Contributing to `fxios` is easy: please fork the repo, make your changes, and submit a PR.

For a discussion of the design thoughts behind `fxios`, and what to add, please first read the [DESIGN_GUIDELINES.md](DESIGN_GUIDELINES.md) document.

For details on how commands are structured and how to add new ones, see [COMMAND_ARCHITECTURE.md](COMMAND_ARCHITECTURE.md).

### Project structure

```
Sources/fxios/
├── fxios.swift                 # Entry point (@main)
├── Core/                       # Where tools and utilities should be placed
│   ├── CommandHelpers.swift    # Shared utilities for command implementations
│   ├── Configuration.swift     # App constants (name, version, etc.)
│   ├── DeviceShorthand.swift   # Simulator shorthand pattern matching (e.g., 17pro, air13)
│   ├── Herald.swift            # Formatted output handling
│   ├── Logger.swift            # Debug logging utility (enabled via --debug)
│   ├── Products.swift          # Build product definitions (Firefox, Focus, Klar)
│   ├── RepoDetector.swift      # Validates firefox-ios repository, loads .fxios.yaml
│   ├── ShellRunner.swift       # Shell command execution
│   ├── SimulatorManager.swift  # iOS Simulator detection and management
│   ├── StringUtils.swift       # String transformation utilities
│   └── ToolChecker.swift       # Tool availability checks (git, node, npm, xcodebuild)
└── Commands/
```

### Development Tips

```bash
# Build
swift build

# Run in the fxios-ctl folder
swift run fxios
```

To test your local changes in a `firefox-ios` repo, it's recommened to create an alias, and using that after running `swift build` in the `fixios-ctl` repo to build your latest changes.

For example: `alias fxtest=path/to/fxios-ctl/.build/arm64-apple-macosx/debug/fxios`

If you're on an Intel machine, you might have to have a slightly different path.

### Unit Testing Notes

Tests use the modern Swift Testing framework (`@Test`, `@Suite`, `#expect`).

⚠️ **IMPORTANT:** Tests must be run with the `--no-parallel` flag to avoid concurrency issues. Many tests change the current working directory, which is global process state. Running tests in parallel _will_ cause cross-contamination between test suites.

```bash
# Run all tests (must use --no-parallel)
swift test --no-parallel
```

Any new feature or command must include corresponding tests. Tests should cover:

- Command configuration (abstract, discussion text)
- Flag/option validation
- Expected behavior with valid inputs
- Error handling for invalid inputs
- Edge cases

See existing test files in `Tests/fxiosTests/` for examples.

### Outputting Status from `fxios`

All `fxios` output is handled by the `Herald`. To maintain clarity between `fxios`'s output and the output of tools/commands it wraps, we have a standard way of presenting output.

```swift
static func declare(
    _ message: String,
    asError: Bool = false,
    isNewCommand: Bool = false,
    asConclusion: Bool = false
)
```

**Parameters:**

- `message` - The text to display
- `asError` - Adds 💥 to indicate an error or warning
- `isNewCommand` - Resets state and uses 🦊 prefix (use at the start of each command)
- `asConclusion` - Uses 🦊 prefix for the final message of a command

**Prefix Logic:**

| Context              | `asError` | Output Prefix |
| -------------------- | --------- | ------------- |
| `isNewCommand: true` | false     | 🦊            |
| `isNewCommand: true` | true      | 🦊 💥         |
| Continuation         | false     | ▒             |
| Continuation         | true      | ▒ 💥          |
| `asConclusion: true` | false     | 🦊            |
| `asConclusion: true` | true      | 🦊 💥         |
| After conclusion     | (ignored) | ▒             |

**Multi-line handling:**

- First line of message: uses computed prefix from table above
- Subsequent lines within the same message: always `▒ ▒` (sub-continuation)

**State behavior:**

- `isNewCommand: true` resets all state - use this at the start of each command's `run()` method
- After a conclusion (`asConclusion: true`), subsequent calls use normal `▒` prefix and ignore `asError`/`asConclusion` flags
- Sub-continuation (`▒ ▒`) only applies to lines 2+ within a single multi-line message, not across separate calls

**Example output:**

```
🦊 Starting build...
▒ Compiling module A
▒ Compiling module B
▒ 💥 Warning: deprecated API usage
▒ ▒ in file Foo.swift:42
▒ Compiling module C
🦊 Build complete!
```

This is produced by:

```swift
Herald.declare("Starting build...", isNewCommand: true)
Herald.declare("Compiling module A")
Herald.declare("Compiling module B")
Herald.declare("Warning: deprecated API usage\nin file Foo.swift:42", asError: true)
Herald.declare("Compiling module C")
Herald.declare("Build complete!", asConclusion: true)
```

#### Raw output

The `Herald` also has a `raw()` function if you need to print out any text. This should almost exclusively be used for the `--expose` command.

### Error Handling

`fxios` follows consistent error handling patterns to ensure errors are never silently swallowed and always provide useful context. For detailed guidelines, see [ERROR_HANDLING.md](ERROR_HANDLING.md).

Key principles:

- All custom errors include `underlyingError` when wrapping other errors
- No silent `catch` blocks - errors are always reported via Herald or re-thrown
- Debug logging available via `--debug` flag for troubleshooting

### Debug Logging

Pass the `--debug` flag to any command to enable detailed logging output:

```bash
fxios --debug doctor
```

Debug output goes to stderr and includes timestamps, file locations, and underlying error details. This is useful for troubleshooting issues or understanding `fxios`'s behavior.

## Currently Supported Commands

| Command           | Description                                                  |
| ----------------- | ------------------------------------------------------------ |
| `fxios bootstrap` | Bootstrap the repository for Firefox or Focus development    |
| `fxios build`     | Build Firefox, Focus, or Klar for development                |
| `fxios clean`     | Clean up cached or generated files                           |
| `fxios doctor`    | Check development environment for required tools             |
| `fxios l10n`      | Localization tools for managing XLIFF files and translations |
| `fxios lint`      | Run SwiftLint on the codebase                                |
| `fxios nimbus`    | Manage Nimbus feature configuration files                    |
| `fxios run`       | Build and launch in the iOS Simulator                        |
| `fxios setup`     | Clone and bootstrap the firefox-ios repository               |
| `fxios telemetry` | Update telemetry configuration files                         |
| `fxios test`      | Run tests for Firefox, Focus, or Klar                        |
| `fxios version`   | Display or update version numbers across the repository      |

#### `bootstrap`

Bootstraps the repository for development. By default, bootstraps the product specified in `.fxios.yaml` (`default_bootstrap`), or Firefox if not configured.

#### `build`

Builds Firefox, Focus, or Klar for development using xcodebuild. By default, builds the product specified in `.fxios.yaml` (`default_build_product`), or Firefox if not configured.

The simulator is auto-detected to use the latest iOS version with a standard iPhone model (non-Pro, non-Max).

Please read [Simulator Shorthand](#simulator-shorthand) for an explanation of the `--sim` flag.

#### `clean`

Cleans up various cached or generated files.

#### `doctor`

Checks your development environment for required tools and configuration. This is useful for onboarding new developers or troubleshooting build issues.

Checks performed:

- **Required tools**: git, node, npm, swift, xcodebuild, xcode-select, simctl
- **Optional tools**: swiftlint (reports status but won't flag as issue if missing)
- **Repository context** (when run from firefox-ios): validates `.fxios.yaml`, checks git hooks installation, shows configured defaults

#### `l10n`

Localization tools for managing XLIFF files and translations between Xcode projects and Mozilla's translation platform (Pontoon). Subcommands:

- `export` - Extract localizable strings from Xcode to XLIFF files in the l10n repository
- `import` - Import translated XLIFF files back into the Xcode project
- `templates` - Create blank template XLIFF files for translators

For `export` and `import`, you must specify either `--product` or `--project-path`:

```bash
# Export Firefox strings (using product preset)
fxios l10n export --product firefox --l10n-project-path /path/to/l10n-repo

# Import Focus translations (using product preset)
fxios l10n import --product focus --l10n-project-path /path/to/l10n-repo

# Export with explicit project path
fxios l10n export --project-path ./Client.xcodeproj --l10n-project-path /path/to/l10n-repo
```

These commands handle locale code mapping between Xcode and Pontoon formats, filtering of non-translatable keys, required translation validation, and comment overrides from `l10n_comments.txt`.

#### `lint`

Runs SwiftLint on the codebase. By default, lints only files changed compared to the main branch.

#### `nimbus`

Manages Nimbus feature flags across the firefox-ios codebase. Subcommands:

- `refresh` - Updates the include block in `nimbus.fml.yaml` with feature files from the `nimbus-features/` directory
- `add` - Creates a new feature with all required boilerplate (YAML file and Swift code)
- `remove` - Removes a feature from all locations

#### `run`

Builds and launches Firefox, Focus, or Klar in the iOS Simulator. This is equivalent to running `fxios build` followed by installing and launching the app.

Please read [Simulator Shorthand](#simulator-shorthand) for an explanation of the `--sim` flag.

#### `telemetry`

Updates Glean telemetry configuration files.

#### `test`

Runs tests for Firefox, Focus, or Klar using xcodebuild. By default, runs unit tests for the product specified in `.fxios.yaml` (`default_build_product`), or Firefox if not configured.

Test plans available:

- `unit` - Unit tests (default)
- `smoke` - Smoke/UI tests
- `accessibility` (or `a11y`) - Accessibility tests (Firefox only)
- `performance` (or `perf`) - Performance tests (Firefox only)
- `full` - Full functional tests (Focus/Klar only)

Please read [Simulator Shorthand](#simulator-shorthand) for an explanation of the `--sim` flag.

#### `version`

Displays or updates version numbers across the repository. Without options, shows the current version and git SHA.

### Simulator Shorthands

The `--sim` option in `build`, `run`, and `test` subcommands accepts either a shorthand code or the full simulator name (e.g., `--sim 17pro` or `--sim "iPhone 17 Pro"`). Use the `list-sims` subcommand to see available simulators on your current machine and their respective shorthands.

#### Design Principles for Shorthand Patterns

1. Shorthands must be derivable - A user should be able to guess the shorthand from the device name
2. No shorthand is OK - Devices that don't fit the pattern get "-" and require the full name
3. Bidirectional consistency - parseShorthand() and shorthand(for:) use the same rules

In general, these design principles result in the following shorthands on my machine:

iPhone:
| Pattern | Examples | Matches |
| --------- | ------------------ | ----- |
| `<N>` | 17 | iPhone 17 (base model only) |
| `<N>pro` | 17pro | iPhone 17 Pro |
| `<N>max` | 17max | iPhone 17 Pro Max |
| `<N>plus` | 16plus | iPhone 16 Plus |
| `<N>e` | 16e | iPhone 16e |
| `se` | se | iPhone SE (any generation) |
| `air` | air | iPhone Air |

iPad:
| Pattern | Examples | Matches |
| --------- | ------------------ | ---- |
| `air<size>` | air11, air13 | iPad Air 11/13-inch (13 also matches 12.9) |
| `pro<size>` | pro11, pro13, pro129 | iPad Pro (13 matches 12.9 too; 129 is precise) |
| `mini` | mini | iPad mini (any - but latest) |
| `mini<N>g` | mini6g, mini7g | iPad mini (Nth generation) |
| `miniA<chip>` | miniA17 | iPad mini (A17 Pro) |
| `pad<N>g` | pad10g | iPad (Nth generation) |
| `padA<chip>` | padA16 | iPad (A16) |

Matching behavior precision notes:

- pro13 matches both "13-inch" and "12.9-inch", but prefers exact match if both simulators exist
- pro129 matches only "12.9-inch" (precise)

**NOTE:** Devices that don't fit patterns get "-" and the user must pass in the full name. Matching every device uniquely is not a goal of the shorthand system which is why `--sim` also accepts full names for simulators

## License

[Mozilla Public License 2.0](https://github.com/adudenamedruby/fxios?tab=MPL-2.0-1-ov-file)
