# Eglantine for Renga

[Eglantine](https://github.com/Djihads80/Eglantine) is a Nintendo Switch 2
emulator derived from Eden, yuzu and Sudachi. This port builds 0.1.0-rc3
(upstream commit `78743f30c2`) for Renga x86_64.

**Status: draft, not yet built or run.** The patches were written and
syntax-checked against the Renga headers outside Renga. Build the package
with HaikuPorter on Renga and go through the test checklist in
[docs/PORTING-TO-RENGA.md](../../docs/PORTING-TO-RENGA.md) before
publishing it.

## What the patches change

The patchset holds five commits on top of upstream, each with a full
explanation in its message.

| Patch | Change | Works on stock Haiku |
| --- | --- | --- |
| common: use memfd_create for host memory | Guest memory is backed by `memfd_create()` (Renga's libgnu) instead of a named POSIX shared memory object. CMake looks for it in Haiku's `gnu` header directory and links `-lgnu` only when it is there. Also fixes a descriptor leak in the private-mapping fallback. | Yes, with the old `shm_open` path |
| dynarmic: enable fastmem on Haiku | The CPU recompiler's fault handler was left out on Haiku because `<ucontext.h>` is missing, so every guest memory access took the slow path. Haiku's `<signal.h>` already provides `ucontext_t`, and the kernel restores `rip` and `rsp` from it. | Yes |
| video_core: present Vulkan through VideoStreamsWsi | Upstream mapped Haiku to an XCB surface, which no Haiku driver provides. The port creates a `VK_EXT_headless_surface` and gives the VideoStreamsWsi layer a bitmap hook that draws each frame into the render window. It checks that the layer is loaded first. | Yes, with the layer installed |
| common: build fixes and Haiku user directories | Links `network` by name instead of a fixed path; uses `find_directory()` for data, cache and settings when the XDG variables are unset. | Yes |
| common: detect hole punching and memory hints by feature | `FALLOC_FL_PUNCH_HOLE`, `MADV_HUGEPAGE` and `MADV_PAGEOUT` are tested by their flags instead of `__linux__`. | Yes (they stay off there) |

The application uses the Haiku `__HAIKU__` test only for Haiku APIs (Be API
drawing, `find_directory`); Renga features are detected, never assumed.

### Renga APIs used

- `memfd_create()` with `MFD_CLOEXEC` (`<sys/mman.h>`, libgnu).

### Upstream workarounds removed

- The `shm_open_anon()` name-and-unlink dance for guest memory, where
  `memfd_create()` exists.
- The generic (no fastmem) exception handler on Haiku.
- The XCB surface on Haiku.
- The hard-coded `/boot/system/lib/libnetwork.so`.

## Waiting on Renga

These are planned in the Renga roadmap. The port keeps its fallbacks and
switches on by itself, or needs only a small change, when they land.

| Roadmap | What | Port today | When it lands |
| --- | --- | --- | --- |
| F-47 | Zero-copy presentation and a Haiku Vulkan surface extension | Each frame is waited for, copied to system memory by the layer and drawn as a `BBitmap`. This is the largest cost on Renga. | Replace the headless surface and bitmap hook in `vulkan_surface_haiku.cpp` with the new extension. |
| F-47 | VideoStreamsWsi fixes: `GetFormats` copies `sizeof(VkFormat)` instead of `sizeof(VkSurfaceFormatKHR)`; the layer submits on `GetDeviceQueue(0, 0)` from the present thread without a lock, while Eglantine may submit on the same queue | The port does not carry a copy of the layer. The format bug is harmless here because Eglantine zero-fills the array, so the colour space reads as sRGB. The queue race can cause rare device-lost errors. | Nothing to change in the port. |
| F-35 | NVK coverage of the extensions Eglantine needs (`FOR_EACH_VK_*` in `src/video_core/vulkan_common/vulkan_device.h`) | Upstream's feature detection and fallbacks | Record `vulkaninfo` from Renga with the NVIDIA driver here. |
| F-48 (a) | `fallocate(FALLOC_FL_PUNCH_HOLE)` on memfds | Zeroing with `memset`, which keeps the pages resident | Switches on automatically once `<fcntl.h>` defines the flags. |
| F-48 (b) | `MADV_HUGEPAGE` | Not called | Switches on automatically. |
| F-48 (c) | Faster `MAP_FIXED` remapping of memfd pieces | Current layout | Nothing to change. |
| F-49 | `futex()` in libgnu | libstdc++ and Mesa use their lock-based fallbacks | Needs rebuilt libstdc++ and Mesa, not this port. |
| F-50 | Game mode, compatible with Feral's gamemode client | Eglantine already calls `gamemode_request_start()`/`_end()` on Haiku (the client header is built in). It loads `libgamemode.so.0` with `dlopen()`, finds nothing and logs a message. The "Enable Gamemode" setting is already in the GUI. | Works as soon as Renga ships `libgamemode.so.0`. Nothing to change. |
| F-42 | Raw HID for SDL3's HIDAPI back end; libusb | Controllers through SDL3's Haiku joystick back end (no gyro, no rumble). libusb is off: upstream's `ENABLE_LIBUSB` lists only Windows, Linux, FreeBSD and macOS and gives no reason for leaving Haiku out, so the GameCube adapter is unavailable. | Try `ENABLE_LIBUSB=ON` with HaikuPorts' libusb. |
| F-31 | Low-latency Media Kit path; a cubeb back end | SDL3 audio on `BSoundPlayer`; cubeb off (upstream's docs/Caveats.md says it does not work on Haiku) | Switch to cubeb when the back end is in RengaPorts. |
| F-31 phase 5 | Hardware video decode | Software decode with FFmpeg | |

## Still to do in this port

- **Vector icon.** Import `dist/dev.eden_emu.eden.svg` into Icon-O-Matic
  and add the HVIF to `additional-files/eglantine.rdef`.
- **File types.** The rdef declares `application/x-nx-nsp`, `-xci`, `-nro`
  and `-nso`, but Haiku's MIME database has no such types with sniffer
  rules or extensions, so Tracker does not offer Eglantine for those files
  yet.
- **Render window.** The bitmap hook draws into the first view of the
  `BWindow` returned by the render widget's `winId()`. Check on hardware
  that Qt's Haiku plugin gives the native child widget its own window and
  not a separate top-level one.
- **Translations** are off (`ENABLE_QT_TRANSLATION`). They need
  `lrelease` from qt6_tools.
- **Checksum** of the time zone archive: HaikuPorter prints it on the
  first fetch. Add it as `CHECKSUM_SHA256_13`.
