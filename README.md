# AuraBar 🎨

AuraBar lets you set custom menu bar colors for each of your apps 🎨 instead of using one single color for the whole system. When you switch to a configured app, the menu bar adapts to your chosen color, instantly returning to its native transparent look ✨ when you return to the desktop. 

### 🌟 Key Highlights
* **Visual Focus:** Automatically dims the menu bar against vivid wallpapers when windows are maximized, preventing "eye-glaze" and keeping focus on the app.
* **Pixel-Perfect UI:** Eliminates the annoying **1px gap** between the menu bar and active maximized windows for a seamless, professional aesthetic.
* **Granular Control:** No more global backgrounds—set specific colors for the apps you use most and let the rest remain native.

![Gif11](https://github.com/user-attachments/assets/a7654863-2f48-410b-8178-bcb0c8adf7b8)

## 🚀 Installation & Setup

Because this utility is distributed independently, follow these steps to bypass macOS Gatekeeper:

1. **Download & Move**: 
   - Download the latest `AuraBar.dmg` from the [Latest Releases](https://github.com/adityaonx/AuraBar/releases/latest) section.
   - Drag **AuraBar** to your `/Applications` folder.
     
> [!NOTE]
> **Why is this needed?** macOS requires developers to pay a recurring fee to "notarize" apps. To keep AuraBar 100% free and open-source, it is self-signed. You can verify the source code yourself to ensure it is safe and respects the Principle of Least Privilege.

2. **First Launch (Bypass Gatekeeper)**:
   - Double-click **AuraBar**. You will see a security warning with buttons: **Done** and **Move to Trash**.
   - **Click "Done"** (Do NOT click Move to Trash).
   - Go to **System Settings** > **Privacy & Security**.
   - Scroll down to the "Security" section. You will see a message stating "AuraBar was blocked..." 
   - Click **Open Anyway** and enter your password/Touch ID to confirm.
     
3. **System Configuration**:
   - To ensure AuraBar works correctly, you **must disable** the native menu bar background setting. 
   - Go to `System Settings` > `Menu Bar` > and toggle **OFF** "Show menu bar background".

4. **Terminal Fix (Optional)**:
   - If the app shows a "damaged" error due to missing signatures, run:
     ```bash
     xattr -rd com.apple.quarantine /Applications/AuraBar.app
     ```

## ✨ Features
- **OS Support:** Optimized specifically for **macOS Tahoe**. (Older versions are untested and not officially supported).
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
**Aditya Sahu** *Data Engineer | macOS Tinkerer* [GitHub Profile](https://github.com/adityaonx)
