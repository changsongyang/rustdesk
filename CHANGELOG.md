# Changelog

All notable changes to this project will be documented in this file.

## [1.4.7] - 2026-06-03

### Features
- **Wayland Keyboard Input Support**: Added support for Wayland keyboard input with user consent dialog and remember option
- **Android Deployment Prompt**: Added automatic deployment prompt for Android devices when server requires deployment
- **Linux Clipboard Enhancement**: Improved Linux clipboard handling with owner marker support for PRIMARY and CLIPBOARD selections

### UI/UX
- Updated toolbar widgets for remote control sessions
- Enhanced desktop and mobile remote pages
- Added new localization keys for deployment and Wayland keyboard features

### Localization
- Updated 50+ language translation files
- Added new translation keys for:
  - API Token
  - Deploy
  - Custom ID
  - Wayland keyboard prompts and settings
  - Server deployment tips

### Build
- Version bump to 1.4.7 (from 1.4.6)
- Updated Flutter dependencies
- Updated Rust dependencies
- Updated AppImage and RPM package versions

### CI/CD
- Updated GitHub Actions workflows
- Added Windows clipboard reader CI workflow

### Submodule
- Updated hbb_common to latest upstream with security fixes

### Documentation
- Updated AGENTS.md with localization guidelines
