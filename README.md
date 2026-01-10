# Type Bot

[![macOS](https://img.shields.io/badge/macOS-15.6+-000000?style=for-the-badge&logo=apple)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.0-F05138?style=for-the-badge&logo=swift)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-Project-147EFB?style=for-the-badge&logo=xcode)](https://developer.apple.com/xcode)

A macOS app that lets you paste rich text, pick a target window, and have Type Bot type it for you with optional humanized pacing.

## Quick Start

### Prerequisites
- **macOS**: 15.6 or higher
- **Xcode**: compatible with Swift 5
- **Accessibility**: permission required to send keystrokes to other apps

### Running Locally

1. **Open the Project**
   ```bash
   open "Type Bot.xcodeproj"
   ```

2. **Build & Run**
   - Select the `Type Bot` scheme
   - Press **Run** in Xcode

3. **Grant Accessibility**
   - System Settings → Privacy & Security → Accessibility
   - Enable Type Bot

## Usage

1. Paste or edit rich text in the editor.
2. Pick the destination app/window.
3. Press **Start** (or use the configured hotkey).
4. Toggle **Realistic** for humanized typing and fine-tune in settings.

Formatting shortcuts (bold/italic/underline/strikethrough) are sent using standard macOS key commands and can be toggled in settings.

## Compatibility

- Targets macOS 15.6 and newer (see `Type Bot.xcodeproj/project.pbxproj`).
- Works best in apps that honor standard formatting shortcuts.
- Requires Accessibility permissions to send keystrokes.

## Development

### Building from Source

1. **Clone the Repository**
   ```bash
   git clone <your-repo-url>
   cd type-bot
   ```

2. **Open in Xcode**
   ```bash
   open "Type Bot.xcodeproj"
   ```

3. **Build**
   - `Cmd+B` to build
   - `Cmd+R` to run

### Configuration Notes
- Typing speed, activation delay, and keybindings live in the in-app settings panel.
- Humanize settings control pacing, pauses, bursts, and intentional mistakes.

## Version Information

| Component | Version |
|-----------|---------|
| **App Version** | 1.0 |
| **Build** | 1 |
| **Swift** | 5.0 |
| **macOS Target** | 15.6 |

## License

No license file is included in this repository.
