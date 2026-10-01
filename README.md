# Ghostty Persian (گوستی پرشین)

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue?logo=apple)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-6.0%20%7C%205.0-orange?logo=swift)](https://swift.org)
[![Tests](https://img.shields.io/badge/Unit%20%26%20Integration%20Tests-205%20Passing-brightgreen?logo=xcode)](https://developer.apple.com/xcode/)
[![Compiler](https://img.shields.io/badge/Warnings%20%26%20Errors-0-success)](https://swift.org)
[![Ghostty](https://img.shields.io/badge/Ghostty-v1.0%2B-purple)](https://ghostty.org)
[![License](https://img.shields.io/badge/License-MIT-lightgrey)](LICENSE)

**Ghostty Persian** is a native, polished macOS GUI configuration companion for the [Ghostty](https://ghostty.org) terminal emulator, crafted specifically for Persian and Arabic developers, students, and power users. It provides first-class typography controls, curated Persian font presets (including **Vazirmatn**), themes, window styling, non-destructive configuration preservation, and automated safety backups.

---

## 🇮🇷 معرفی به زبان فارسی (Persian Overview)

**گوستی پرشین (Ghostty Persian)** یک ابزار گرافیکی بومی، زیبا و فوق‌العاده امن برای مدیریت تنظیمات ترمینال مدرن **Ghostty** در سیستم‌عامل macOS است که با تمرکز ویژه بر **تایپوگرافی زبان فارسی و خطوط راست‌به‌چپ** طراحی شده است.

### ویژگی‌های کلیدی
- **پشتیبانی کامل از فونت‌های فارسی**: انتخاب فونت‌های محبوب فارسی از جمله **وزیرمتن (Vazirmatn)**، **ساحل (Sahel)**، **شبنم (Shabnam)**، **صمیم (Samim)**، **ایران‌سنس (IRANSans)** و سایر فونت‌های سیستمی به عنوان فونت اصلی یا جایگزین (Fallback).
- **پیش‌تنظیم‌های آماده (Persian Presets)**: تنظیم سریع ارتفاع سلول‌ها (`adjust-cell-height`)، ضخامت فونت (`font-thicken`)، و لیست جایگزین‌ها فقط با یک کلیک.
- **ویرایش کاملاً امن و بدون تخریب (Non-Destructive)**: کامنت‌ها، ساختار فایل و تمام تنظیماتی که توسط این برنامه مدیریت نمی‌شوند دست‌نخورده و بدون کوچک‌ترین تغییری باقی می‌مانند.
- **اعتبارسنجی زنده با Ghostty CLI**: قبل از ذخیره، صحت تنظیمات توسط دستور رسمی `ghostty +validate-config` اعتبارسنجی می‌شود.
- **پشتیبان‌گیری خودکار و جایگزینی اتمیک (Atomic Save & Safety Backups)**: قبل از هر بار ذخیره، یک نسخه پشتیبان با برچسب زمان ایجاد شده و فایل جدید به شکل اتمیک جایگزین می‌شود تا خطر از دست رفتن اطلاعات به صفر برسد.
- **بررسی تغییرات (Diff Inspector)**: امکان مشاهده دقیق تغییرات جدید در مقایسه با فایل ذخیره‌شده روی دیسک پیش از اعمال نهایی.
- **کلید میانبر Option + R برای تصحیح درلحظه فارسی**: بازآرایی و مرتب‌سازی خودکار و برخط خط فرمان با fribidi قبل از اجرای دستور.

---

## ✨ Key Features

### 1. Typography & Persian Presets
- **Persian Font Presets**: Ready-to-use profiles including Standard Vazirmatn, Modern Clean, and Legacy Persian Fallbacks.
- **Fallback Font Management**: Order secondary and tertiary fonts (e.g. `JetBrains Mono` for code + `Vazirmatn` for Persian + `Symbols Nerd Font` for terminal icons).
- **Cell Height & Line Metrics**: Fine-tune `adjust-cell-height` (e.g., `15%` or `18%`) to avoid Arabic/Persian diacritics clipping.
- **Font Thickening**: Toggle `font-thicken` for crystal-clear readability on Retina and external displays.

### 2. Full Ghostty Terminal Customization
- **Themes**: Live theme browser powered by `ghostty +list-themes --plain`, supporting dark and light palettes.
- **Window & Titlebar**: Full control over window opacity, blur styles, padding, and native macOS transparent or tabs titlebar styles.
- **Shell & Execution**: Configure default shell binaries, custom commands, working directory, and fine-grained shell integration features.

### 3. Non-Destructive Architecture & Safety Guarantees
- **Round-Trip Formatting Preservation**: Built around an AST-like line parser that preserves comments (`#`), custom indentations, blank lines, and unrecognized future Ghostty options verbatim.
- **Atomic File Writing**: All modifications are written to temporary staging files and atomically swapped into place via `NSFileManager.replaceItemAt`.
- **Pre-Write Safety Backups**: Every write creates an automatic timestamped snapshot in `~/Library/Application Support/GhosttyPersian/Backups`.
- **Pre-Flight CLI Validation**: Ghostty Persian runs `ghostty +validate-config` in a sandbox before committing changes to disk.
- **One-Click Rollback**: Easily revert in-memory edits or restore prior snapshots from the built-in backup manager.

### 4. Interactive Diagnostics & Error Handling
- Structured diagnostic reports with human-readable root causes, recovery suggestions, and actionable resolution buttons.
- Collapsible technical logs with one-click clipboard copying for troubleshooting.

### 5. Persian Command-Line Typing & On-the-Fly BiDi Shortcut (`Option + R`)
- **On-the-Fly Prompt BiDi Reversal (`Option + R` / `\er`)**: Ghostty terminals render text left-to-right; when typing Persian commands or mixed scripts, text can appear reversed before execution. Pressing `Option + R` instantly invokes an in-place line reordering widget powered by `fribidi` to correct the line buffer before running.
- **Interactive Shell Helpers**:
  - `pcat <file>`: Reads files with Persian RTL BiDi shaping.
  - `pecho <text>`: Echoes Persian text with proper word ordering.
  - `command | bidi`: Stream filter for piping any command output through BiDi reordering.
- **Non-Destructive Shell Hooks**: One-click install and safe removal for both **Zsh** (`~/.zshrc`) and **Fish** (`~/.config/fish/conf.d/ghostty_persian.fish`).

---

## 🏗️ Architecture & Directory Precedence

Ghostty Persian automatically discovers and obeys Ghostty's official precedence hierarchy:
1. `~/.config/ghostty/config.ghostty` (XDG scope)
2. `~/.config/ghostty/config` (XDG scope)
3. `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` (macOS scope)
4. `~/Library/Application Support/com.mitchellh.ghostty/config` (macOS scope, highest precedence)

---

## 🛠️ Building & Testing

### Requirements
- **macOS**: 14.0 (Sonoma) or later
- **Xcode**: 15.0 or later (Swift 5.0 / 6.0 compatible)
- **XcodeGen** (optional, for regenerating `.xcodeproj`): `brew install xcodegen`
- **Ghostty Terminal** (recommended): [https://ghostty.org](https://ghostty.org)

### Build from Command Line
```bash
# Clone the repository
git clone https://github.com/your-username/GhosttyPersian.git
cd GhosttyPersian

# (Optional) Regenerate Xcode project
xcodegen generate

# Build application
xcodebuild -scheme GhosttyPersian -destination 'platform=macOS' build

# Run comprehensive test suite (205 unit and integration tests)
xcodebuild -scheme GhosttyPersian -destination 'platform=macOS' test
```

### Build in Xcode
1. Open `GhosttyPersian.xcodeproj` in Xcode.
2. Select the `GhosttyPersian` scheme and target **My Mac**.
3. Press `Cmd + B` to build, or `Cmd + U` to execute all 205 unit & integration tests.

---

## 🧪 Test Coverage Highlights

The project contains **205 automated unit and integration tests** across 25 distinct test suites:
- **`ConfigurationEdgeCasesTests`**: Complex quoted strings with escaped characters, symbols (`#`, `=`), mixed CRLF/LF line endings, and high-volume parsing.
- **`PathResolutionResiliencyTests`**: Missing directories, broken symlinks, precedence cascading, and custom XDG environments.
- **`AtomicRepositoryStressTests`**: Staging directory write denials, atomic recovery, concurrent thread-safe document mutations, and backup pruning.
- **`CLIServiceResilienceTests`**: Process timeout enforcement, corrupted CLI outputs, and missing executable fallbacks.
- **`EndToEndPipelineIntegrationTests`**: Full lifecycle bootstrapping, multi-section mutations, change tracking diffing, pre-flight validation, and atomic persistence.
- **`ErrorHandlingAndDiagnosticsTests`**: Structured diagnostic generation for all repository, CLI, and filesystem error scenarios.

---

## 📜 License

Ghostty Persian is released under the **MIT License**. See [LICENSE](LICENSE) for details.

Developed with ❤️
