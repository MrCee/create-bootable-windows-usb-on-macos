# 🤝 Contributing to create-bootable-windows-usb-on-macos

Thanks for your interest in contributing! This script helps users create Windows USB installers on macOS, and your feedback, ideas, and improvements are welcome.

---

## 🛠 Ways You Can Help

- 📥 **Report issues** — found a bug or edge case? Open an [issue](https://github.com/yourusername/create-bootable-windows-usb-on-macos/issues)
- 💡 **Suggest improvements** — UX, features, compatibility
- 📚 **Improve documentation** — fix typos, expand steps, clarify usage
- 💻 **Submit pull requests** — with small, focused changes (see guidelines below)

---

## ✅ Pull Request Guidelines

Please ensure your pull request:

- Targets the `main` branch
- Describes what it changes and why
- Contains tested shell syntax (`bash -n yourfile.sh` is your friend)
- Uses comments where necessary to explain logic

For major features, open an issue or discussion first to align goals.

---

## 📦 Dependencies

This script requires only:

- `bash`
- `wimlib` (via Homebrew: `brew install wimlib`)

Optional improvements should avoid external dependencies unless justified.

---

## 🧪 Testing

Whenever possible:

- Test against multiple ISO versions (Win 10, Win 11)
- Check USB compatibility on real hardware (BIOS and UEFI)
- Confirm file structure and unattended config work as expected

---

## 📄 License

By contributing, you agree your work will be licensed under the [MIT License](LICENSE).

---

Thanks for making this project better! 🙌

