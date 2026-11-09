# Porting an application to Renga: briefing

Read this first when porting a program to Renga, whether you are a person or
an AI assistant. It covers the decisions, the workflow, packaging and
quality. The list of APIs Renga provides beyond stock Haiku, with details
and differences from Linux, is in **PORTING.md**, the source of truth for
APIs, and it changes often. Read it in full before writing code:

- https://github.com/Techniix/haiku/blob/ce/main/3rdparty/ce/PORTING.md
- raw: https://raw.githubusercontent.com/Techniix/haiku/ce/main/3rdparty/ce/PORTING.md

Project status, plans and decisions are in the
[Renga master roadmap](https://github.com/Techniix/haiku/blob/ce/main/RENGA_MASTER_ROADMAP.md).

## 1. What Renga is

Renga is a Haiku-based operating system: branch `ce/main` of
[Techniix/haiku](https://github.com/Techniix/haiku/tree/ce/main), based on
upstream Haiku `hrev60381`, x86_64 only.

- **It runs Haiku programs.** Renga only adds to Haiku's ABI. Every x86_64
  Haiku program and HaikuPorts package runs unchanged.
- **It adds APIs Haiku lacks**, mostly Linux and BSD interfaces such as
  `epoll`, `inotify`, `signalfd`, `eventfd`, `timerfd`, `memfd_create` with
  sealing, `getdents64`, `backtrace()`, `getrandom()`, CPU affinity, TCP
  keepalive and `TCP_INFO`, and the UDP options QUIC needs. Each is listed in
  PORTING.md.
- **The reverse is not true.** A program that uses Renga-only APIs does not
  load on stock Haiku, because the symbols are missing there.
- **The platform still identifies as Haiku:** `__HAIKU__`, `uname -s`,
  paths, MIME signatures and package names are unchanged. There is no
  `__RENGA__` macro. Detect features, not the platform.
- **Ctrl is the shortcut key.** Ctrl+C copies, as on Windows and Linux;
  Haiku uses Alt. The API is unchanged; see section 4.

## 2. First decision: a Haiku port or a Renga port

| If the program... | Port it as | Published in |
| --- | --- | --- |
| works fine with what stock Haiku offers | a **Haiku port** (it runs on Renga too) | its own project repository and [Techniix/haiku-packages](https://github.com/Techniix/haiku-packages) (or HaikuPorts) |
| needs workarounds on Haiku that a Renga API removes (an `epoll`/`inotify` event loop instead of a poll fallback, `memfd` instead of temporary files, and so on), or only works fully with a Renga feature | a **Renga port** | [Techniix/RengaPorts](https://github.com/Techniix/RengaPorts) (this repository) |

A program can have both. Then keep the Haiku fallback in the source and
choose at build time, through feature detection (section 3), not
`#ifdef __HAIKU__`.

## 3. Writing the port

### Use the native APIs and remove workarounds

- Prefer the APIs in PORTING.md over Haiku-specific fallbacks in the
  upstream project. Remove `__HAIKU__` special cases that exist only
  because an API was missing; do not add Renga-specific ones.
- Let the build system detect features: CMake `check_symbol_exists`,
  Autoconf `AC_CHECK_FUNCS`, Meson `cc.has_function` find these functions
  on Renga as they do on Linux. Where a project tests `#ifdef __linux__`
  for something Renga now has, change the test to the feature (for
  example `#ifdef EPOLLRDHUP`, `#ifdef IP_RECVTOS`).
- Libraries: the Linux-style APIs are in `libgnu` (`-lgnu`, headers in
  `develop/headers/gnu`); BSD ones such as `getpeereid()` in `libbsd`
  (`-lbsd`); POSIX ones such as message queues, System V shared memory,
  `ucontext`, affinity and `thread_local` destructors are in libroot.
  PORTING.md lists the header and library for each.
- Read each API's "Differences from Linux" in PORTING.md. Option numbers
  and signal numbers are Haiku's: always use the names.
- If something you need is listed under "Planned" in PORTING.md, leave a
  short note in the port instead of a workaround. If it is not listed at
  all, report it (section 8); do not invent a Renga-specific workaround.

### Make it a good Haiku/Renga citizen

A port is only finished when it feels native:

- **User interface.** Native Interface Kit code is best. Toolkit programs
  use the toolkit's Haiku back end (Qt, SDL2/SDL3, GTK and wxWidgets have
  them in HaikuPorts). Follow the system font size and colours rather
  than hard-coded pixels and colours (HiDPI, dark themes).
- **Shortcuts.** Use `B_COMMAND_KEY` (`AddShortcut()`, `BMenuItem`). Do not
  map a toolkit's "Ctrl" to `B_CONTROL_KEY`. A terminal emulator sends
  control characters for Ctrl+letter and runs its own shortcuts on
  Ctrl+Shift+letter (PORTING.md, "Ctrl is the shortcut key").
- **Every feature reachable from the GUI.** Renga's rule: settings that only
  exist as files or command-line switches are not finished.
- **Locations.** Use `find_directory()`/`BPathFinder`
  (`B_USER_SETTINGS_DIRECTORY` → `~/config/settings/<App>`,
  `B_USER_CACHE_DIRECTORY`, `B_USER_DATA_DIRECTORY`) instead of hard-coded
  `~/.config` or `/usr/share` paths. Never write under `/boot/system`:
  packaged files there are read-only.
- **Identity and file types.** Give the app a signature
  (`application/x-vnd.<Vendor>-<App>`), a vector icon (HVIF, made with
  Icon-O-Matic), version info and the file types it opens, in its resource
  file (`.rdef`). That lets Tracker open documents with it and show the
  right icons. Decide whether it is single-launch.
- **Desktop integration.** Use `BNotification` for notifications,
  `be_clipboard` for the clipboard, `BMessage`-based drag and drop, a
  Deskbar replicant for a tray icon, and `be_roster->Launch()`/`open` to
  open URLs and files with the preferred application.
- **Translations.** Native programs use the Locale Kit (catalogs, `B_TRANSLATE`).
- **Audio and video.** Use the Media Kit (`BSoundPlayer`, `BMediaFile`) or a
  toolkit back end on top of it (SDL, Qt Multimedia). The Media Kit is
  being extended (per-application volume, routing, capture); see the
  roadmap's F-31 before building workarounds.
- **Graphics.** OpenGL is Mesa in software today. There is no GPU
  acceleration for ports and no Vulkan yet. Do not assume a GPU, and keep
  a software path.
- **Wayland programs.** These run through the Wayland compatibility server
  from HaikuPorts. Renga plans to make it a system component (roadmap
  F-43 phase C); until then, follow the HaikuPorts approach.

## 4. Building and testing

- **You need Renga to build a Renga port**, because the Renga-only symbols
  and headers exist only there. Building on stock Haiku links only Haiku
  APIs, which is right for a Haiku port.
- **Getting Renga.** There are no published Renga images yet. Build one
  from `ce/main` (`jam -q @renga-anyboot`, see
  [3rdparty/ce/README.md](https://github.com/Techniix/haiku/blob/ce/main/3rdparty/ce/README.md)),
  then use it in a VM (QEMU, VirtualBox, VMware) or on hardware. Install
  `haiku_devel`, HaikuPorter and the port's build dependencies there, as on
  Haiku.
- **Build with HaikuPorter** from a recipe (section 5), not by hand, so
  that the package is reproducible.
- **Test checklist**, on Renga:
  - It starts from Deskbar and from Tracker, by double-clicking a
    document it handles; its icon and file types show in Tracker.
  - Shortcuts work with Ctrl in Renga's default and with Alt after
    switching Keymap to "Alt" (Haiku mode).
  - Window resizing, font size changes and dark colours look right.
  - Settings persist in `~/config/settings` and survive a restart.
  - It quits cleanly from its menu, from Deskbar and on shutdown, and
    leaves no stray processes.
  - Sound, network, clipboard, drag and drop and notifications work where
    the program uses them.
  - No new errors in `/var/log/syslog` while it runs.
  - A Haiku port also starts on stock Haiku.

## 5. Packaging

RengaPorts uses the HaikuPorts layout and recipe format
([HaikuPorter guidelines](https://github.com/haikuports/haikuports/wiki)):

```
<category>/<port>/<port>-<version>.recipe
<category>/<port>/patches/<port>-<version>.patchset
```

A recipe needs, at minimum:

```bash
SUMMARY="One line, no trailing period"
DESCRIPTION="A paragraph or two."
HOMEPAGE="https://..."
COPYRIGHT="2026 The Authors"
LICENSE="MIT"            # licence names as in HaikuPorts' licence list
REVISION="1"
SOURCE_URI="https://.../program-$portVersion.tar.gz"
CHECKSUM_SHA256="..."
PATCHES="program-$portVersion.patchset"

ARCHITECTURES="x86_64"

PROVIDES="
	program = $portVersion
	app:Program = $portVersion
	"
REQUIRES="
	haiku
	lib:libgnu      # if it uses the Linux-style APIs
	"
BUILD_REQUIRES="
	haiku_devel
	"
BUILD_PREREQUIRES="
	cmd:cmake
	cmd:gcc
	cmd:make
	"

BUILD()
{
	cmake -B build -S . -DCMAKE_BUILD_TYPE=Release $cmakeDirArgs
	make -C build $jobArgs
}

INSTALL()
{
	make -C build install
	addAppDeskbarSymlink $appsDir/Program
}
```

Renga specifics:

- **Marking Renga-only packages.** Every package that needs Renga will
  declare `renga >= 1` in `REQUIRES`, so stock Haiku refuses it instead of
  failing at run time. Renga's system package does not provide `renga`
  yet (roadmap F-45). Until it does, leave that line out, or the package
  cannot be installed anywhere; PORTING.md and this file will say when to
  add it.
- **Patches** go into the patchset, made with HaikuPorter's patch
  workflow. Keep them small and explained in their commit messages.
- **Same name as a HaikuPorts package.** On Renga the Renga repository is
  preferred (priority 1 against 2), so its package replaces the HaikuPorts
  one, even when HaikuPorts has a newer version. Bump the Renga package
  when HaikuPorts updates, or remove it once HaikuPorts has what it needed.
- **Publishing.** Build the `.hpkg` with HaikuPorter, then run
  `tools/update-repo.sh <package>.hpkg` (see the README). Commit the recipe
  and patches to `main` in the same change.

## 6. Documentation and commits

- Commit messages are very detailed: what changed, why, what was tested,
  and any differences from the upstream program's behaviour. Add code
  comments where they help.
- READMEs and documentation are professional and about the software only.
- Each port records, in its recipe comments or project README, which Renga
  APIs it uses and which upstream workarounds it removed.

## 7. Upstream projects

- Haiku's own repository does not accept AI-generated or AI-assisted
  contributions (its `AGENTS.md`). Renga's AI-assisted work stays in the
  fork.
- Before offering a patch or bug report to any upstream project (the
  ported program itself, HaikuPorts, Haiku), check that project's
  contribution policy. Reports are short, in the maintainer's own words,
  with only verified facts.

## 8. When Renga is missing something

If the port needs an API or behaviour that Renga lacks and PORTING.md does
not list under "Planned", stop and report it to the Renga maintainer with:

- the call or feature, and where the program uses it;
- what Linux or the BSDs do;
- what the port would have to do without it.

Renga adds such interfaces properly, with tests, rather than having ports
carry workarounds. That is how the Chromium port's needs became roadmap
entry F-43.
