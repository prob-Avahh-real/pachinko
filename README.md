# Pachinko

A Pachinko game built with SwiftUI + SpriteKit for iOS/macOS, with a web version in HTML/JS.

## Features

- Physics-based ball drop simulation
- 9-pocket scoring system with FEVER mode
- Configurable pin layout (9x16 grid)
- Audio engine for game sound effects
- Score tracking with multiplier pockets

## Tech Stack

### Native App
- **Language:** Swift 5.9
- **Framework:** SwiftUI
- **Platform:** iOS 17+ / macOS 14+

### Web Version
- `index.html` — standalone HTML/JS/CSS pachinko game

## Project Structure

```
Sources/Pachinko/
  Engine/      — Physics engine, audio engine
  Models/      — Game models (Ball, Pin, GameState)
  Views/       — GameView (SwiftUI)
Tests/PachinkoTests/
```

## Development

```bash
# Build
swift build

# Test
swift test

# Lint
swiftlint

# Generate Xcode project
xcodegen

# Web version (open in browser)
open index.html
```
