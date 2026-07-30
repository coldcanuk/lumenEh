include config.mk

SRCDIR = src
OBJDIR = obj
BINDIR = .

SOURCES = $(wildcard $(SRCDIR)/*.c)
OBJECTS = $(SOURCES:$(SRCDIR)/%.c=$(OBJDIR)/%.o) $(OBJDIR)/md4c.o
TARGET = $(BINDIR)/viewmd

DESTDIR ?=

.PHONY: all clean install uninstall

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
	install -Dm755 $(TARGET) $(DESTDIR)$(bindir)/viewmd
	install -Dm644 assets/viewmd.desktop $(DESTDIR)$(applicationsdir)/viewmd.desktop

uninstall:
	rm -f $(DESTDIR)$(bindir)/viewmd
	rm -f $(DESTDIR)$(applicationsdir)/viewmd.desktop

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

