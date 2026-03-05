# Boot splash image

Put your custom boot splash image here:

- **File name:** `splash.png`
- **Format:** PNG (recommended 1920×1080 or your display resolution)
- **Usage:** Run `./scripts/change-splash.sh` from the repo root (uses `.env` or pass HOST USER PASSWORD).

The script copies this image to the Pi and sets it as the Plymouth boot splash, then rebuilds the initramfs. Reboot the Pi to see it.
