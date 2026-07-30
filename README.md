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

### Arch Linux (AUR)

https://aur.archlinux.org/packages/lumeneh

### Debian/Ubuntu (.deb)

Install a built `.deb` package with:

```bash
sudo apt install ./lumeneh_*.deb
```

### Fedora/RHEL (.rpm)

Install a built `.rpm` package with:

```bash
sudo dnf install ./lumeneh-*.rpm
```

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


## Building From Source

```bash
./configure
make
sudo make install
```

This installs:
- Binary to `/usr/local/bin/lumeneh`
- Desktop file to `/usr/local/share/applications/lumeneh.desktop`

### Uninstallation

```bash
sudo make uninstall
```
### Dependencies

### Arch Linux
```bash
sudo pacman -S gtk3
```

### Ubuntu/Debian
```bash
sudo apt install libgtk-3-dev
```

### Fedora
```bash
sudo dnf install gtk3-devel
```

## Packaging Templates

- Arch: `packaging/arch/PKGBUILD`
- Debian: `packaging/deb/control.in`
- RPM: `packaging/rpm/lumeneh.spec.in`

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
