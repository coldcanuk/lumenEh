# Releases

Versioned install packages for **lumenEh** live here.

| File pattern | Platform |
|--------------|----------|
| `lumeneh_<version>_<arch>.deb` | Debian / Ubuntu / Pop!_OS |
| `lumeneh-<version>-<rel>.*.rpm` | Fedora / RHEL / openSUSE (and dnf/yum systems) |
| `MANIFEST-<version>.txt` | Build metadata for that version |

Current version is defined in the repository root [`VERSION`](../VERSION) file.

## Build packages locally

```bash
./configure --prefix=/usr
make
make packages
# or: scripts/build-packages.sh
```

Packages are written to this directory. Building a `.rpm` requires `rpmbuild` on `PATH`.

## Install

```bash
# Debian/Ubuntu
sudo apt install ./releases/lumeneh_0.2.0_amd64.deb

# Fedora/RHEL
sudo dnf install ./releases/lumeneh-0.2.0-1.*.rpm
```

GitHub Releases (https://github.com/coldcanuk/lumenEh/releases) also publish these artifacts for tagged versions (`vX.Y.Z`).
