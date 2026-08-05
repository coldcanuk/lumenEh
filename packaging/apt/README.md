# APT repository support for lumenEh

Goal: end users can run **`sudo apt install lumeneh`** after adding this project’s
APT source (not via `apt install ./file.deb` alone).

## Checklist

| # | Task | Status |
|---|------|--------|
| 1 | Build a real `.deb` with `Package: lumeneh` | **Done** — `make packages` → `releases/*.deb` |
| 2 | Public OpenPGP key for `Signed-By` | **Done** — `lumeneh-archive-keyring.{asc,gpg}` (uid `Chuck <chuck@actvite.com>`) |
| 3 | Private OpenPGP key (publisher only) | **Done** — in your `~/.gnupg` / LastPass (never in git) |
| 4 | APT tree: `pool/` + `dists/…/Packages` + `Release` | **Done tooling** — `scripts/build-apt-repo.sh` / `make apt-repo` → local `apt-repo/` |
| 5 | Sign `InRelease` / `Release.gpg` with private key | **Pending on your machine** — run `scripts/sign-apt-repo.sh` (passphrase) |
| 6 | Host `apt-repo/` on HTTPS (`<BASE>`) | **Pending** — GitHub Pages, VPS, etc. |
| 7 | Document user `sources.list` + `apt install lumeneh` | **Done** — root `README.md` (replace `<BASE>` when hosted) |
| 8 | Optional: CI rebuild/sign/publish on each release | **Pending** — needs GPG private key as a CI secret + Pages/host token |

## Maintainer commands

```bash
make packages
make apt-repo                 # or: SKIP_SIGN=1 scripts/build-apt-repo.sh
scripts/sign-apt-repo.sh      # interactive GPG passphrase
# then upload/publish the apt-repo/ directory as <BASE>
```

## What is *not* enough

- Putting a `.deb` only in GitHub Releases → users still need `apt install ./lumeneh_….deb`
- Committing only the public keyring → no package index, no install by name
- An unsigned `file:` or `http:` repo → modern `apt` refuses it by default

## Security

- **Never** commit private keys, passphrases, or `*.rev` revocation certs.
- Only the **public** keyring files in this directory belong in git.
