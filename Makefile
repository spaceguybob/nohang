DESTDIR ?=
PREFIX ?=         /usr/local
SYSCONFDIR ?=     /usr/local/etc
SYSTEMDUNITDIR ?= /usr/local/lib/systemd/system

BINDIR ?=  $(PREFIX)/bin
SBINDIR ?= $(PREFIX)/sbin
DATADIR ?= $(PREFIX)/share
DOCDIR ?=  $(DATADIR)/doc/nohang
MANDIR ?=  $(DATADIR)/man

PANDOC := $(shell command -v pandoc 2> /dev/null)

all:
	@ echo "Use: make install, make install-openrc, make uninstall"

update-manpages:

ifdef PANDOC
	pandoc docs/nohang.manpage.md -s -t man > man/nohang.8
	pandoc docs/oom-sort.manpage.md -s -t man > man/oom-sort.1
	pandoc docs/psi2log.manpage.md -s -t man > man/psi2log.1
	pandoc docs/psi-top.manpage.md -s -t man > man/psi-top.1
else
	@echo "pandoc is not installed, skipping manpages generation"
endif

base:
	install -p  $(DESTDIR)$(SBINDIR)
	install -p -m0755 src/nohang $(DESTDIR)$(SBINDIR)/nohang

	install -p $(DESTDIR)$(BINDIR)
	install -p -m0755 src/oom-sort $(DESTDIR)$(BINDIR)/oom-sort
	install -p -m0755 src/psi-top $(DESTDIR)$(BINDIR)/psi-top
	install -p -m0755 src/psi2log $(DESTDIR)$(BINDIR)/psi2log

	install -p  $(DESTDIR)$(SYSCONFDIR)/nohang

	sed "s|:TARGET_DATADIR:|$(DATADIR)|" \
		conf/nohang/nohang.conf.in > nohang.conf

	sed "s|:TARGET_DATADIR:|$(DATADIR)|" \
		conf/nohang/nohang-desktop.conf.in > nohang-desktop.conf

	install -p -m0644 nohang.conf $(DESTDIR)$(SYSCONFDIR)/nohang/nohang.conf
	install -p -m0644 nohang-desktop.conf $(DESTDIR)$(SYSCONFDIR)/nohang/nohang-desktop.conf

	install -p  $(DESTDIR)$(DATADIR)/nohang

	install -p -m0644 nohang.conf $(DESTDIR)$(DATADIR)/nohang/nohang.conf
	install -p -m0644 nohang-desktop.conf $(DESTDIR)$(DATADIR)/nohang/nohang-desktop.conf

	-git describe --tags --long --dirty > version
	install -p -m0644 version $(DESTDIR)$(DATADIR)/nohang/version

	rm -fv nohang.conf
	rm -fv nohang-desktop.conf
	rm -fv version

	install -p  $(DESTDIR)/etc/logrotate.d
	install -p -m0644 conf/logrotate.d/nohang $(DESTDIR)/etc/logrotate.d/nohang

	install -p  $(DESTDIR)$(MANDIR)/man1
	gzip -9cn man/oom-sort.1 > $(DESTDIR)$(MANDIR)/man1/oom-sort.1.gz
	gzip -9cn man/psi-top.1 > $(DESTDIR)$(MANDIR)/man1/psi-top.1.gz
	gzip -9cn man/psi2log.1 > $(DESTDIR)$(MANDIR)/man1/psi2log.1.gz

	install -p  $(DESTDIR)$(MANDIR)/man8

	sed "s|:SYSCONFDIR:|$(SYSCONFDIR)|g; s|:DATADIR:|$(DATADIR)|g" \
		man/nohang.8 > nohang.8

	gzip -9cn nohang.8 > $(DESTDIR)$(MANDIR)/man8/nohang.8.gz
	rm -fv nohang.8

	install -p  $(DESTDIR)$(DOCDIR)
	install -p -m0644 README.md $(DESTDIR)$(DOCDIR)/README.md
	install -p -m0644 CHANGELOG.md $(DESTDIR)$(DOCDIR)/CHANGELOG.md

units:
	install -p -d $(DESTDIR)$(SYSTEMDUNITDIR)

	sed "s|:TARGET_SBINDIR:|$(SBINDIR)|; s|:TARGET_SYSCONFDIR:|$(SYSCONFDIR)|" \
		systemd/nohang.service.in > nohang.service

	sed "s|:TARGET_SBINDIR:|$(SBINDIR)|; s|:TARGET_SYSCONFDIR:|$(SYSCONFDIR)|" \
		systemd/nohang-desktop.service.in > nohang-desktop.service

	install -p -m0644 nohang.service $(DESTDIR)$(SYSTEMDUNITDIR)/nohang.service
	install -p -m0644 nohang-desktop.service $(DESTDIR)$(SYSTEMDUNITDIR)/nohang-desktop.service

	rm -fv nohang.service
	rm -fv nohang-desktop.service

chcon:
	chcon -t systemd_unit_file_t $(DESTDIR)$(SYSTEMDUNITDIR)/nohang.service || :
	chcon -t systemd_unit_file_t $(DESTDIR)$(SYSTEMDUNITDIR)/nohang-desktop.service || :

daemon-reload:
	systemctl daemon-reload || :

build_deb: base units

reinstall-deb:
	set -v
	deb/build.sh
	sudo apt install --reinstall ./deb/package.deb

install: base units chcon daemon-reload
	# This is fine.

install-openrc: base
	install -p -d $(DESTDIR)$(SYSCONFDIR)/init.d
	sed "s|:TARGET_SBINDIR:|$(SBINDIR)|; s|:TARGET_SYSCONFDIR:|$(SYSCONFDIR)|" \
		openrc/nohang.in > openrc/nohang
	sed "s|:TARGET_SBINDIR:|$(SBINDIR)|; s|:TARGET_SYSCONFDIR:|$(SYSCONFDIR)|" \
		openrc/nohang-desktop.in > openrc/nohang-desktop
	install -p -m0775 openrc/nohang $(DESTDIR)$(SYSCONFDIR)/init.d/nohang
	install -p -m0775 openrc/nohang-desktop $(DESTDIR)$(SYSCONFDIR)/init.d/nohang-desktop
	rm -fv openrc/nohang
	rm -fv openrc/nohang-desktop

uninstall-base:
	rm -fv $(DESTDIR)$(SBINDIR)/nohang
	rm -fv $(DESTDIR)$(BINDIR)/oom-sort
	rm -fv $(DESTDIR)$(BINDIR)/psi-top
	rm -fv $(DESTDIR)$(BINDIR)/psi2log

	rm -fv $(DESTDIR)$(MANDIR)/man1/oom-sort.1.gz
	rm -fv $(DESTDIR)$(MANDIR)/man1/psi-top.1.gz
	rm -fv $(DESTDIR)$(MANDIR)/man1/psi2log.1.gz

	rm -fv $(DESTDIR)$(MANDIR)/man8/nohang.8.gz

	rm -fvr $(DESTDIR)$/etc/logrotate.d/nohang
	rm -fvr $(DESTDIR)$(DOCDIR)/
	rm -fvr $(DESTDIR)/var/log/nohang/
	rm -fvr $(DESTDIR)$(DATADIR)/nohang/
	rm -fvr $(DESTDIR)$(SYSCONFDIR)/nohang/

uninstall-units:
	systemctl stop nohang.service || :
	systemctl stop nohang-desktop.service || :
	systemctl disable nohang.service || :
	systemctl disable nohang-desktop.service || :

	rm -fv $(DESTDIR)$(SYSTEMDUNITDIR)/nohang.service
	rm -fv $(DESTDIR)$(SYSTEMDUNITDIR)/nohang-desktop.service

uninstall-openrc:
	rc-service nohang-desktop stop || :
	rc-service nohang stop || :

	rm -fv $(DESTDIR)$(SYSCONFDIR)/init.d/nohang
	rm -fv $(DESTDIR)$(SYSCONFDIR)/init.d/nohang-desktop

uninstall: uninstall-base uninstall-units daemon-reload uninstall-openrc
