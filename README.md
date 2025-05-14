# 🎟️ **Create Bootable Windows USB on macOS**

![macOS Supported](https://img.shields.io/badge/platform-macOS-blue.svg)
![Shell Script](https://img.shields.io/badge/language-Zsh-green.svg)
![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)
![Status: Maintained](https://img.shields.io/badge/status-active-brightgreen.svg)
![Arch Support](https://img.shields.io/badge/architectures-amd64%20%7C%20arm64-purple.svg)

A fully interactive, all-in-one **Windows USB installer creator for macOS**.

👌 Supports **Windows 10 & 11** ISOs  
💻 Detects both **Home / Pro** editions  
📦 Builds USBs for **Intel (amd64)** and **ARM (arm64)** ISOs  
🩰 Supports both **Legacy BIOS (MBR)** and **UEFI (GPT)** boot modes  
🧠 Automatically injects a compatible **Windows BIOS MBR bootloader** for legacy systems  

---

## ✨ Features

- ✅ Auto-detects Windows **10 or 11** ISO
- 🤖 Auto-detects **amd64** or **arm64** architecture
- 🧠 Detects and selects **Home or Pro** editions
- 💻 Supports **Legacy BIOS (MBR)** and **UEFI (GPT)** boot modes
- 𞫋 Splits `install.wim` automatically for FAT32 USBs
- 📝 Smart config injection:
  - `ei.cfg` to preselect edition
  - `PID.txt` with correct GVLK
  - `Autounattend.xml` with full localization, OOBE control, admin account, TPM/SB/RAM bypass
- 🔓 **Bypasses TPM, Secure Boot, RAM, and Disk checks** for Windows 11
- 💽 Native Zsh script — requires **only Homebrew** (auto-installs `jq`, `rsync`, `wimlib-imagex`)

---

## 🧹 Modes & Customization

Choose how you want to build your installer:
- 🔓 **Local Account Mode** – Skips Microsoft OOBE and auto-creates a local admin
- 🔐 **Standard Mode** – Microsoft-style interactive setup with online account option
- 🪪 **Inspect Only** – No USB, just generate `Autounattend.xml` and parse ISO

---

## 🧬 Partition Schemes (Visualized)

When **Full Partition Wipe** is enabled, the script generates partition tables as follows:

### 🔁 UEFI (GPT Mode)
```
Disk 0
├─ 100MB  [NTFS]      System (Active)
├─ 300MB  [FAT32]     EFI System Partition
└─ Remaining [NTFS]   Windows Install
```
- FAT32 ensures UEFI compatibility (UEFI firmware requires FAT32 to load bootx64.efi)

### 💿 Legacy BIOS (MBR Mode)
```
Disk 0
├─ 100MB  [NTFS]      System (Active)
└─ Remaining [NTFS]   Windows Install
```
- Uses **real Windows BIOS MBR bootloader** injected from `bootloaders/windows_bios_mbr.bin`
- Ensures bootmgr loads properly on older systems where macOS fails to set a valid boot sector

---

## ⚙️ Requirements

- macOS (Monterey or later recommended)
- Homebrew installed:

```zsh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

> Script will auto-install:
> - `wimlib-imagex`
> - `rsync`
> - `jq`

- Official **Windows 10 or 11 ISO**
- 8 GB+ USB flash drive (USB 2.0 preferred for legacy machines)

---

## 🚀 How to Use

### 1. 📀 Download the Script
```zsh
curl -O https://your-github-url.com/create-bootable-windows-usb-on-macos.sh
chmod +x create-bootable-windows-usb-on-macos.sh
```

### 2. 🪪 Run It as Root
```zsh
sudo ./create-bootable-windows-usb-on-macos.sh /path/to/windows.iso
```

### 3. 🔧 Follow the Prompts
- Choose USB disk (e.g., `disk2`)
- Select **Legacy** or **UEFI** boot
- Choose Windows edition & language
- Customize name, keyboard layout, etc.
- 💥 Optionally wipe all partitions
- Watch it go 🎉

---

## 🔐 Generic Setup Keys

These generic keys are automatically used:

| Edition  | Key                                  | Purpose                |
|----------|--------------------------------------|------------------------|
| **Pro**  | VK7JG-NPHTM-C97JM-9MPGT-3V66T        | Win 10 & 11 Pro Setup  |
| **Home** | TX9XD-98N7V-6WMQ6-BX7FG-H8Q99        | Win 10 & 11 Home Setup |

> These allow installation, **not activation**.

🛠️ Use your own key? Replace the `PID.txt` file:
```ini
[PID]
Value=XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
```

---

## ⚠️ Warnings

- 🫸 **The script will ERASE your USB drive** — double-check disk name!
- 🫠 Terminal comfort helps — but it's beginner friendly
- ✅ Not just for dual-booters — supports **real installs, VMs, and hardware reimages**

---

## 📄 License

Licensed under the [MIT License](LICENSE).

---

## 🧠 Legacy BIOS Support on macOS

This script uniquely automates the injection of the Windows MBR bootloader on macOS, enabling Legacy BIOS booting—a feature not commonly found in other macOS-based Windows USB creation tools.

## 🙌 Credits & Acknowledgements

Created by **MrCee**

Inspired by:
- Years of manual Windows installs
- The elegance of Rufus (but for macOS!)
- The pain of FAT32, bootmgr, `install.wim`, and dual-boot woes

> “This script wraps everything into one seamless, beautiful, reliable tool.” 💡

---

## ⭐️ Quick Example

```zsh
sudo ./create-bootable-windows-usb-on-macos.sh ~/Downloads/Win11.iso
```

---

## 💬 Feedback & Support

- Found it useful? **Star the repo** ⭐️
- Suggestions? Open an issue or PR 💡
- Share with techies, reimagers, dual-booters 🤜

---

## ☕️💜 Support the Project

> ✨ If this saved you time or helped you escape Boot Camp madness, dual-boot chaos, or tedious installs, consider showing some love:

<p align="center">
  <a href="https://www.buymeacoffee.com/MrCee" target="_blank">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-violet.png" width="200" alt="Buy Me A Coffee">
  </a>
</p>

🧠 Built for simplicity • 💻 Powered by Zsh • 🎟️ For everyone who needs clean Windows installs


