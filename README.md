<!-- <img src="PressKits/logo.png" alt="AnyFontUse" hight="256" /> -->
<p align="left">
  <img src="PressKits/logos.png" alt="AnyFontUse" hight="256" />
</p>

**English** · [简体中文](README.zh-CN.md)

A lightweight SwiftUI font manager. Drop any font file into your project and render it with one modifier.

```swift
Text("hello").anyFontUse(size: 24, weight: 100)     // CSS-style numeric weight
Text("hello").anyFontUse(size: 24, weight: .thin)   // semantic name
```

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![SPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)](https://swift.org/package-manager)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2015%20%7C%20macOS%2012%20%7C%20tvOS%2015%20%7C%20watchOS%208%20%7C%20visionOS%201-blue.svg)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## Example

<img src="PressKits/AnyFontUse.gif" alt="AnyFontUse" width="480" />

## Features

- **Zero config.** Drop fonts into your target and AnyFontUse auto-scans the bundle and registers them. No `register(...)` calls, no `Info.plist` `UIAppFonts`, not even `App.init()`. SwiftUI Previews work out of the box.
- One-line modifier, same shape as SwiftUI's native `.font()`.
- Weight accepts both **numeric literals** (`100`, `400`, `700`…) and **semantic names** (`.thin`, `.regular`, `.bold`…), aligned with CSS and `Font.Weight`.
- Multi-family: `.anyFontFamily("Inter")` switches the default family for a subtree, `anyFontUse(..., family: "JetBrains Mono")` overrides at the call site.
- Auto-detects family + weight: reads OS/2 `usWeightClass` first (CSS-aligned 100~900), falls back to PostScript name keywords, then CT trait.
- Manual `register(...)` still available for fine control — explicit entries override auto-detected ones.
- Nearest-neighbor weight matching: register only 3 weights and `weight: 500` snaps to the closest registered value.
- Graceful fallback to the system font when nothing is registered.
- Pure Swift, zero dependencies, Swift 6 strict concurrency friendly.

## Installation

### Swift Package Manager

In Xcode: `File > Add Packages…`, then paste the repo URL.

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jackcring/AnyFontUse.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["AnyFontUse"]
    )
]
```

Minimum deployment targets:

| Platform | Min  |
| -------- | ---- |
| iOS      | 15.0 |
| macOS    | 12.0 |
| tvOS     | 15.0 |
| watchOS  | 8.0  |
| visionOS | 1.0  |

## Quick Start (zero config)

### 1. Add font files to your project

Drag `.ttf` / `.otf` files into your app target and confirm **Target Membership** is checked.

> No need to touch `Info.plist`'s `UIAppFonts`, no registration code required.

### 2. Use it

```swift
import AnyFontUse
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("hello").anyFontUse(size: 24, weight: 100)
            Text("hello").anyFontUse(size: 24, weight: .thin)
            Text("hello").anyFontUse(size: 24, weight: .regular)
            Text("hello").anyFontUse(size: 24, weight: .bold)
        }
    }
}
```

The first call to `.anyFontUse(...)` triggers a one-time scan of `Bundle.main`. AnyFontUse extracts each font's family and weight (OS/2 `usWeightClass` → PostScript name → CT trait) and builds the registry. SwiftUI Previews are covered too — no `App.init()` required.

> If your project ships a single family it becomes the default automatically. Otherwise pin one with:
>
> ```swift
> AnyFontManager.shared.defaultFamily = "Inter"
> ```

## Multiple families

### Option A: pass `family:` per call

```swift
Text("Body").anyFontUse(size: 16, family: "Inter")
Text("Code").anyFontUse(size: 16, family: "JetBrains Mono")
```

### Option B: `.anyFontFamily(...)` for view-tree scoping (recommended)

Same idea as `.foregroundStyle(_:)` or `.font(_:)` — propagates down the subtree:

```swift
ContentView()
    .anyFontFamily("Inter")        // App-wide default: Inter
```

```swift
VStack {
    Text("Hello world")            // uses Inter
        .anyFontUse(size: 18)

    Text("let x = 42")             // local override
        .anyFontUse(size: 16, family: "JetBrains Mono")

    HStack {
        Text("a"); Text("b"); Text("c")
    }
    .anyFontFamily("Playfair Display")   // only this HStack uses Playfair
    .anyFontUse(size: 20)
}
.anyFontFamily("Inter")
```

### Resolution order

The family used at render time is resolved in this order (highest priority first):

1. The `family:` argument passed to `anyFontUse(...)`;
2. The nearest `.anyFontFamily("...")` up the view tree;
3. `AnyFontManager.shared.defaultFamily` (auto-picked in zero-config mode — the family with the most weight variants wins).

### Don't know the family name?

```swift
print(AnyFontManager.shared.registeredFamilies)
// ["Inter", "JetBrains Mono", "Playfair Display"]
```

Drop that into `.onAppear { ... }` once. Family names come from font metadata — they should match what macOS Font Book shows.

## Auto-scan details

- **When it runs.** First call to `.anyFontUse(...)`, `registeredFamilies`, or `registeredWeights(in:)`. Once per process.
- **What it scans.** `[Bundle.main]` by default. If your fonts live in an SPM resource bundle, configure early in launch:
  ```swift
  AnyFontManager.shared.autoBootstrapBundles = [.main, .module]
  ```
- **Supported formats.** `.ttf`, `.otf`, `.ttc`, `.otc`.
- **Weight detection priority:**
  1. OS/2 `usWeightClass` (used when the file contains a single face — most authoritative, CSS-aligned 100~900);
  2. PostScript name keywords (`Thin` / `ExtraLight` / `Bold` / `ExtraBold`…);
  3. CoreText `kCTFontWeightTrait`, snapped to the nearest CSS anchor.
- **Italics.** Detected italics are NOT inserted into the family/weight index (so `weight: .regular` won't accidentally pick an italic). They're still registered with `CTFontManager`, so you can use them via `Font.custom("…-Italic", size:)` directly.
- **Disable auto mode:**
  ```swift
  AnyFontManager.shared.autoBootstrapEnabled = false
  ```

## Debugging

```swift
print(AnyFontManager.shared.registeredFamilies)
print(AnyFontManager.shared.registeredWeights(in: "JetBrains Mono"))
```

Anything that fails to register prints a line prefixed with `[AnyFontUse] ...` to the console.

## Manual registration (optional)

Reach for this when you want to:

- pick a custom family name (different from what's in the font file);
- correct an auto-detected weight that's wrong;
- load fonts from a non-`Bundle.main` resource bundle.

Manual entries **override** auto-detected entries with the same family + weight:

```swift
AnyFontManager.shared.register(
    family: "Mixed",
    weights: [
        .regular: AnyFontResource(fileName: "Mixed-Regular", fileExtension: "ttf"),
        .bold:    AnyFontResource(
            fileName: "Mixed-Bold",
            fileExtension: "otf",
            postScriptName: "MixedDisplay-Bold" // skip auto-sniffing
        ),
    ]
)
```

### Register multiple families

Call `register(family:…)` as many times as you need; the first registered family becomes the default unless you set one explicitly.

```swift
AnyFontManager.shared.register(family: "Inter", weights: […])
AnyFontManager.shared.register(family: "PlayfairDisplay", weights: […])
AnyFontManager.shared.defaultFamily = "Inter"
```

### Register a single font file

For one-off fonts where you don't care about weight mapping:

```swift
let psName = AnyFontManager.shared.registerSingleFont(fileName: "MyIcon", fileExtension: "ttf")
// Use the returned PostScript name directly: .font(.custom(psName!, size: 24))
```

### From an SPM resource bundle

```swift
AnyFontManager.shared.register(
    family: "Brand",
    weights: [.regular: "Brand-Regular", .bold: "Brand-Bold"],
    bundle: .module
)
```

### Nearest-neighbor weight matching

Registered only `.regular` (400) and `.bold` (700)? Any weight in between still works:

```swift
Text("auto").anyFontUse(size: 16, weight: 500) // → uses .regular(400)
Text("auto").anyFontUse(size: 16, weight: 600) // → uses .bold(700)
```

## Weight reference

`AnyFontWeight` mirrors CSS `font-weight` and SwiftUI `Font.Weight`:

| Numeric | Semantic      | SwiftUI fallback |
| ------: | ------------- | ---------------- |
|     100 | `.ultraLight` | `.ultraLight`    |
|     200 | `.thin`       | `.thin`          |
|     300 | `.light`      | `.light`         |
|     400 | `.regular`    | `.regular`       |
|     500 | `.medium`     | `.medium`        |
|     600 | `.semibold`   | `.semibold`      |
|     700 | `.bold`       | `.bold`          |
|     800 | `.heavy`      | `.heavy`         |
|     900 | `.black`      | `.black`         |

> Any value between 1 and 1000 is accepted; non-anchor values snap to the nearest semantic for the system fallback path.

## FAQ

**Q: My text doesn't change. What's wrong?**
A: Two things to verify: 1) the `.ttf` file is in the app target's membership; 2) `Bundle.main.urls(forResourcesWithExtension:)` actually finds it. If there's no `[AnyFontUse] ...` log, call `AnyFontManager.shared.registeredFamilies` to see what was detected.

**Q: Does it work in SwiftUI Previews?**
A: Yes. Auto-scan triggers on the first `anyFontUse(...)` call, which runs in previews regardless of whether `App.init()` is called.

**Q: I want to opt out of auto-registration.**
A: `AnyFontManager.shared.autoBootstrapEnabled = false`, then call `register(...)` explicitly.

**Q: I don't know my font's PostScript name. Now what?**
A: You don't need to. AnyFontUse sniffs it from the file.

**Q: How is this different from plain `Font.custom(_:size:)`?**
A: No PostScript names to remember, no `Info.plist` plumbing, weights as numbers or semantics, and a system font fallback when nothing is registered.

**Q: Performance?**
A: Auto-scan runs once on first query. After that, a lookup is a dictionary read behind an `NSLock`.

## Contributing

PRs and issues welcome. Before submitting, please run:

```bash
swift build
```

## License

MIT — see [LICENSE](LICENSE).

## Author

**Jc** © [jackcirng.com](https://jackcirng.com)
