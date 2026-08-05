include config.mk

SRCDIR = src
OBJDIR = obj
BINDIR = .

SOURCES = $(wildcard $(SRCDIR)/*.c)
OBJECTS = $(SOURCES:$(SRCDIR)/%.c=$(OBJDIR)/%.o) $(OBJDIR)/md4c.o
TARGET = $(BINDIR)/lumeneh

DESTDIR ?=
# Opt-in personal Desktop shortcut: set DESKTOP_SHORTCUT=1 (or yes/true).
# Never installed when DESTDIR is set (packaging / staged installs).
DESKTOP_SHORTCUT ?=

# Fallbacks when config.mk predates iconsdir (re-run ./configure for full paths).
datadir ?= $(PREFIX)/share
applicationsdir ?= $(datadir)/applications
iconsdir ?= $(datadir)/icons/hicolor/256x256/apps

ICON_SRC = assets/icons/lumeneh.png
ICON_NAME = lumeneh.png
DESKTOP_SRC = assets/lumeneh.desktop
# Shared SUDO_USER-aware Desktop path resolution (install + uninstall).
DESKTOP_HELPER = scripts/resolve_desktop.sh

.PHONY: all clean install uninstall maybe-desktop-shortcut do-desktop-shortcut test-install packages apt-repo

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(OBJECTS) -o $@ $(LDFLAGS)

$(OBJDIR)/%.o: $(SRCDIR)/%.c Makefile config.mk | $(OBJDIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJDIR)/md4c.o: $(SRCDIR)/md4c/md4c.c Makefile config.mk | $(OBJDIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJDIR):
	mkdir -p $(OBJDIR)

clean:
	rm -rf $(OBJDIR) $(TARGET)

install: $(TARGET)
	@test -f $(ICON_SRC) || { echo "error: missing icon $(ICON_SRC)" >&2; exit 1; }
	install -Dm755 $(TARGET) $(DESTDIR)$(bindir)/lumeneh
	install -Dm644 $(DESKTOP_SRC) $(DESTDIR)$(applicationsdir)/lumeneh.desktop
	install -Dm644 $(ICON_SRC) $(DESTDIR)$(iconsdir)/$(ICON_NAME)
	@$(MAKE) --no-print-directory maybe-desktop-shortcut

# Personal Desktop shortcut is opt-in only.
# - DESTDIR set (packaging): never create, never prompt.
# - DESKTOP_SHORTCUT=1|yes|true: create without prompting.
# - DESKTOP_SHORTCUT=0|no|false: skip without prompting.
# - Unset + interactive TTY (no DESTDIR): ask the user [y/N].
# - Unset + non-interactive: skip (safe for scripts).
maybe-desktop-shortcut:
	@if [ -n "$(DESTDIR)" ]; then \
		exit 0; \
	fi; \
	case "$(DESKTOP_SHORTCUT)" in \
		1|yes|YES|true|TRUE) \
			$(MAKE) --no-print-directory do-desktop-shortcut; \
			exit $$?; \
			;; \
		0|no|NO|false|FALSE) \
			exit 0; \
			;; \
	esac; \
	if [ -t 0 ]; then \
		printf "Install a lumenEh shortcut on your Desktop as well? [y/N] "; \
		read ans || ans=; \
		case "$$ans" in \
			y|Y|yes|YES) $(MAKE) --no-print-directory do-desktop-shortcut ;; \
			*) echo "Skipping personal Desktop shortcut." ;; \
		esac; \
	else \
		echo "Note: pass DESKTOP_SHORTCUT=1 to also install a personal Desktop shortcut."; \
	fi

# Place lumeneh.desktop on the invoking user's Desktop (SUDO_USER under sudo).
do-desktop-shortcut:
	@if [ -n "$(DESTDIR)" ]; then \
		echo "error: do-desktop-shortcut refuses DESTDIR installs" >&2; \
		exit 1; \
	fi
	@bash $(DESKTOP_HELPER) install-shortcut $(DESKTOP_SRC)

uninstall:
	rm -f $(DESTDIR)$(bindir)/lumeneh
	rm -f $(DESTDIR)$(applicationsdir)/lumeneh.desktop
	rm -f $(DESTDIR)$(iconsdir)/$(ICON_NAME)
	@if [ -z "$(DESTDIR)" ]; then \
		bash $(DESKTOP_HELPER) remove-shortcut; \
	fi

# Committed install-path smoke test (drives real make install/uninstall).
test-install:
	bash tests/test_install.sh

# Build versioned .deb and .rpm into releases/ (see VERSION).
packages:
	bash scripts/build-packages.sh

# Build APT repository tree under apt-repo/ (from releases/*.deb).
# Sign with scripts/sign-apt-repo.sh if non-interactive signing is unavailable.
apt-repo: packages
	bash scripts/build-apt-repo.sh

# Header dependencies
$(OBJDIR)/main.o: $(SRCDIR)/app.h $(SRCDIR)/window.h
$(OBJDIR)/app.o: $(SRCDIR)/app.h $(SRCDIR)/config.h $(SRCDIR)/window.h $(SRCDIR)/editor.h $(SRCDIR)/remote_ssh.h
$(OBJDIR)/window.o: $(SRCDIR)/window.h $(SRCDIR)/app.h $(SRCDIR)/editor.h $(SRCDIR)/config.h $(SRCDIR)/remote_ssh.h
$(OBJDIR)/editor.o: $(SRCDIR)/editor.h $(SRCDIR)/markdown.h $(SRCDIR)/app.h $(SRCDIR)/remote_ssh.h
$(OBJDIR)/markdown.o: $(SRCDIR)/markdown.h $(SRCDIR)/code_highlight.h
$(OBJDIR)/code_highlight.o: $(SRCDIR)/code_highlight.h
$(OBJDIR)/config.o: $(SRCDIR)/config.h
$(OBJDIR)/remote_ssh.o: $(SRCDIR)/remote_ssh.h
$(OBJDIR)/md4c.o: $(SRCDIR)/md4c/md4c.h
