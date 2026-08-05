# lumenEh

Native GTK 3 markdown viewer for local **and** remote (SSH) files — with real theme control.

**lumenEh** is a fork of [ViewMD](https://github.com/rabfulton/ViewMD) by rabfulton (MIT). Combined work is **GPL-3.0-or-later**; see [License & provenance](#license--provenance) and [`NOTICE`](NOTICE).

Uses [md4c](https://github.com/mity/md4c) for markdown parsing.

![lumenEh](assets/screenshot.png)

## Features

- **Native GTK viewer** - No webviews
- **Read-only rendering** - Focused on viewing markdown files
- **Minimal UI** - Clean toolbar with open and settings buttons
- **Tabbed interface** - Open multiple documents at once with an intuitive empty state
- **Lightweight** - Pure C, no web technologies, fast startup
- **Hyperlink support** - Left click opens links and internal anchors
- **Document search** - `Ctrl+F` with next/previous match navigation
- **Local image support** - Local images are resized to fit the the document window

## Supported Markdown

| Syntax | Description |
|--------|-------------|
| `# Header 1` | Large bold header |
| `## Header 2` | Medium bold header |
| `### Header 3` | Small bold header |
| `**bold**` | Bold text |
| `*italic*` | Italic text |
| `` `code` `` | Inline code |
| <code>```...```</code> | Code block |
| `- item` | List item |
| `> quote` | Block quote |
| `[text](url)` | Link |
| `~~strike~~` | Strikethrough |
| `\| table \| row \|` | Markdown tables |
| `---` | Horizontal rule |

Code blocks currently support a beta version of keyword highlighting for fenced languages `c`, `java`, and `python`.

## Installation

Current release version: **0.2.0** (see [`VERSION`](VERSION)). Choose one of the methods below.

Pre-built packages for each release are in [`releases/`](releases/) and on [GitHub Releases](https://github.com/coldcanuk/lumenEh/releases).

### Install with `apt install lumeneh` (APT repository)

`apt install lumeneh` (without a local path) needs a published APT repository,
not only a `.deb` file. This project includes tooling to **build and sign** that
repo; you still need to **host** it over HTTPS once.

**Maintainer — build the repo tree:**

```bash
make packages          # releases/lumeneh_*.deb
make apt-repo          # apt-repo/ pool + Packages + Release
scripts/sign-apt-repo.sh   # if signing needs your GPG passphrase
```

Public signing key (for `Signed-By`): [`packaging/apt/lumeneh-archive-keyring.gpg`](packaging/apt/lumeneh-archive-keyring.gpg).

**End user — after the repo is published at `<BASE>`** (example):

```bash
curl -fsSL <BASE>/keyring/lumeneh-archive-keyring.gpg \
  | sudo tee /usr/share/keyrings/lumeneh-archive-keyring.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/lumeneh-archive-keyring.gpg] <BASE> stable main" \
  | sudo tee /etc/apt/sources.list.d/lumeneh.list

sudo apt update
sudo apt install lumeneh
```

Until `<BASE>` is online, use a local `.deb` install below.

### Install from a `.deb` package (Debian / Ubuntu / Pop!_OS)

**Option A — from a git clone** (packages already under `releases/`):

```bash
sudo apt install ./releases/lumeneh_0.2.0_amd64.deb
```

**Option B — download from GitHub Releases:**

```bash
# Download the .deb from:
#   https://github.com/coldcanuk/lumenEh/releases/latest
sudo apt install ./lumeneh_0.2.0_amd64.deb
```

You can also use `dpkg` directly:

```bash
sudo dpkg -i ./releases/lumeneh_0.2.0_amd64.deb
sudo apt-get install -f   # only if dpkg reports missing dependencies
```

### Install from an `.rpm` package (Fedora / RHEL / openSUSE)

**Option A — from a git clone:**

```bash
sudo dnf install ./releases/lumeneh-0.2.0-1.*.rpm
```

**Option B — download from GitHub Releases:**

```bash
# Download the .rpm from:
#   https://github.com/coldcanuk/lumenEh/releases/latest
sudo dnf install ./lumeneh-0.2.0-1.*.rpm
```

On systems without `dnf`, use:

```bash
sudo rpm -Uvh ./releases/lumeneh-0.2.0-1.*.rpm
```

### Arch Linux (AUR)

https://aur.archlinux.org/packages/lumeneh

### Compile and install from source

Build dependencies:

| Distro | Install build dependencies |
|--------|----------------------------|
| Arch Linux | `sudo pacman -S gtk3` |
| Ubuntu / Debian | `sudo apt install build-essential pkg-config libgtk-3-dev` |
| Fedora / RHEL | `sudo dnf install gcc make pkgconf-pkg-config gtk3-devel` |

Clone, compile, and install:

```bash
git clone https://github.com/coldcanuk/lumenEh.git
cd lumenEh
./configure
make
sudo make install
```

By default this installs to `/usr/local`:

| Path | What |
|------|------|
| `/usr/local/bin/lumeneh` | Application binary |
| `/usr/local/share/applications/lumeneh.desktop` | Application launcher entry |
| `/usr/local/share/icons/hicolor/256x256/apps/lumeneh.png` | App icon |

Custom prefix (example: system-wide under `/usr`):

```bash
./configure --prefix=/usr
make
sudo make install
```

On an interactive terminal, `make install` asks whether to also place a shortcut on your personal Desktop. Packaging and staged installs (`DESTDIR=...`) never create a personal Desktop shortcut.

When install runs under `sudo`, an opted-in Desktop shortcut goes to the **invoking user's** Desktop (`SUDO_USER`), not root's.

```bash
# Opt in without a prompt
sudo make install DESKTOP_SHORTCUT=1

# Opt out without a prompt
sudo make install DESKTOP_SHORTCUT=0
```

Uninstall a source install:

```bash
sudo make uninstall
```

Uninstall removes the binary, desktop entry, icon, and (without `DESTDIR`) any personal Desktop shortcut for the installing user.

### Build your own `.deb` / `.rpm` packages

If you want to produce packages yourself (instead of using the ones in `releases/`):

```bash
./configure --prefix=/usr
make
make packages
```

This writes versioned files under `releases/` (for example `lumeneh_0.2.0_amd64.deb` and `lumeneh-0.2.0-1.x86_64.rpm`). Requires `dpkg-deb` and `rpmbuild`.

## Usage

Run `lumeneh` to start the application.

- **Open button**: Open a markdown document
- **Reload button**: Reload the currently open document from disk
- **Settings button**: Adjust theme, fonts, and markdown accent colors

### Remote SSH File Manager

lumenEh can natively browse and open Markdown files hosted on remote servers over SSH.

- Click the **Open Remote (SSH)** button in the header bar.
- Enter an SSH URI (e.g., `ssh://user@hostname/path/to/docs` or `user@hostname:/path/to/docs`).
- Use the **Browse** button to navigate the remote filesystem and select documents.
- Use the **Save Host** and **Delete Host** buttons to manage frequently accessed remote servers without saving credentials.
- Bookmark specific files or directories directly from the file browser using the **Bookmark Path** button, which nested them under your saved hosts.
- Select a host to dynamically load its saved paths.

> **Important**: This feature executes the system `ssh` command. For the best user experience and seamless background loading, it is highly recommended to configure **SSH keys** and `ssh-agent`. Password prompts will cause the fetch to fail because the subprocess runs in batch mode (`-o BatchMode=yes`).

### Find in Document

- Press `Ctrl+F` to open search.
- Type to highlight matches as you search.
- Press `Enter` for next match and `Shift+Enter` for previous match.
- Press `Esc` to close search.

### Set as Default `.md` Viewer

After installing, associate markdown MIME types with `lumeneh.desktop`:

```bash
xdg-mime default lumeneh.desktop text/markdown
xdg-mime default lumeneh.desktop text/x-markdown
```

Verify the current default:

```bash
xdg-mime query default text/markdown
```

Test by opening a markdown file through your desktop association:

```bash
xdg-open README.md
```


Application icon art lives at `assets/icons/lumeneh.png`. To generate or replace it, see [`assets/icons/GROK_IMAGINE_ICON.md`](assets/icons/GROK_IMAGINE_ICON.md).

## Packaging Templates

- Arch: `packaging/arch/PKGBUILD`
- Debian: `packaging/deb/control.in`
- RPM: `packaging/rpm/lumeneh.spec.in`
- Built packages: `releases/` (see [`releases/README.md`](releases/README.md))
- Package build script: `scripts/build-packages.sh` (`make packages`)

Release tags use the form `vX.Y.Z` matching [`VERSION`](VERSION) (for example `v0.2.0`). Publishing a GitHub Release runs [`.github/workflows/package.yml`](.github/workflows/package.yml) to attach `.deb` / `.rpm` assets.

## Other Useful Projects
- TrayMD is an app for taking notes in markdown with live editing [TrayMD](https://github.com/rabfulton/TrayMD)
- Preditor is an image viewer with a similar philosophy to lumeneh [preditor](https://github.com/rabfulton/preditor)
- Try my AI panel plugin for XFCE [XFCE Ask](https://github.com/rabfulton/xfce-ask)
- For a feature complete AI application try out [ChatGTK](https://github.com/rabfulton/ChatGTK)
- A lightweight speech to text implementation [Auriscribe](https://github.com/rabfulton/Auriscribe)
- A lightweight local movie database and browser [ReelVault](https://github.com/rabfulton/ReelVault)

## License & provenance

**lumenEh** is a fork of [ViewMD](https://github.com/rabfulton/ViewMD) by rabfulton and contributors.

- Combined work: **GPL-3.0-or-later** (see [`LICENSE`](LICENSE))
- Upstream ViewMD and vendored **md4c** retain their MIT terms as documented in [`NOTICE`](NOTICE)
- Packaging license fields: **GPL-3.0-or-later**
- Binary / packages: `lumeneh`; product name: **lumenEh**
