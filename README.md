# AuraBar 🎨

A lightweight, security-hardened macOS utility designed for adaptive menu bar aesthetics. Built with a focus on system isolation and the "Principle of Least Privilege."

## 🚀 Installation
1. Download the latest **AuraBar.dmg** from the [Latest Releases](https://github.com/adityaonx/AuraBar/releases/latest) section.
2. Drag **AuraBar** to your `/Applications` folder.
3. Launch and configure your app color mappings via the menu bar icon.

## ✨ Features
- **Adaptive Icons:** Fully integrated with macOS Tahoe's Luminosity logic (native Light/Dark mode support).
- **Smart Updates:** Built-in versioning system that fetches the latest manifest from GitHub.
- **Environment Isolation:** Hardened with App Sandbox to restrict network and file-system access.
- **Native Performance:** Compiled specifically for Apple Silicon (M1/M2/M3).

## 🛡 Security & Architecture
As part of **Project ReInvento**, AuraBar is designed with a "Privacy-First" approach:
- **Sandbox Hardening:** Utilizes `com.apple.security.network.client` for update checks only; no other outbound traffic is permitted.
- **Least Privilege:** The app operates without root access, utilizing native AppKit APIs for menu bar manipulation.
- **Transparency:** Open-source logic allows for full audit of how app-color mappings are stored in `UserDefaults`.

## 👨‍💻 Developer
**Aditya Sahu** *Data Engineer | macOS Tinkerer* [GitHub Profile](https://github.com/adityaonx)
