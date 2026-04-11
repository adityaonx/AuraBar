# AuraBar 🎨

AuraBar lets you set custom menu bar colors for each of your apps, rather than using one single color for the whole system. When you switch to an app you've configured, the menu bar changes to that color; when you go back to your desktop or minimize your windows, it instantly returns to its original transparent look.

![Gif11](https://github.com/user-attachments/assets/a7654863-2f48-410b-8178-bcb0c8adf7b8)

## 🚀 Installation & Setup

Because this utility is distributed independently, follow these steps to bypass macOS Gatekeeper:

1. **Download & Move**: 
   - Download the latest `AuraBar.dmg` from the [Latest Releases](https://github.com/adityaonx/AuraBar/releases/latest) section.
   - Drag **AuraBar** to your `/Applications` folder.

2. **First Launch (Bypass Gatekeeper)**:
   - **Do not double-click** the app initially. 
   - **Right-click** (or Control-click) **AuraBar** in your Applications folder and select **Open**.
   - Click **Open** on the macOS security dialog.

3. **Terminal Fix (Optional)**:
   - If the app shows a "damaged" error due to missing signatures, run:
     ```bash
     xattr -rd com.apple.quarantine /Applications/AuraBar.app
     ```

## ✨ Features
- **Smart Updates:** Built-in versioning system that fetches the latest manifest from GitHub.
- **Config Management:** Support for adding or removing individual application color mappings (v1.0.2+).
- **Environment Isolation:** Hardened with App Sandbox to restrict network and file-system access.
- **Native Performance:** Compiled specifically for Apple Silicon (M1/M2/M3/M4).

## 🛡 Security & Architecture
AuraBar is designed with a "Privacy-First" approach:
- **Sandbox Hardening:** Utilizes `com.apple.security.network.client` for update checks only; no other outbound traffic is permitted.
- **Least Privilege:** The app operates without root access, utilizing native AppKit APIs for menu bar manipulation.
- **Data Privacy:** Accessibility access is used exclusively to read `bundleIdentifier` metadata. No window content or keystrokes are logged.
- **Transparency:** Open-source logic allows for full audit of how mappings are stored in `UserDefaults`.

## 👨‍💻 Developer
**Aditya Sahu** *Data Engineer | macOS * [GitHub Profile](https://github.com/adityaonx)
