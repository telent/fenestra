
FENNEL_SRCS=main.fnl
LUA_SRCS=$(patsubst %.fnl,%.fnl.lua,$(FENNEL_SRCS))
PROTOCOLS=$(shell pkg-config wayland-protocols --variable=datarootdir)

default: fenestra

LIBS=$(shell pkg-config --libs luajit) \
     $(shell pkg-config --libs wayland-server) \
     $(shell pkg-config --libs xkbcommon) 

CFLAGS=$(shell pkg-config --cflags xkbcommon) \
       $(shell pkg-config --cflags wayland-server) \
       $(shell pkg-config --cflags wlroots) \
	-I .

%.fnl.lua:%.fnl
	$(FENNEL) --compile $< > /tmp/$$PPID
	mv /tmp/$$PPID $@

xdg-shell-protocol.h:
	wayland-scanner server-header $(PROTOCOLS)/wayland-protocols/stable/xdg-shell/xdg-shell.xml  xdg-shell-protocol.h

defs.h.out: xdg-shell-protocol.h Makefile
%.h.out: %.h 
	$(CC) $(CFLAGS) -P -E - < $< |cat -s > /tmp/$$PPID
	mv /tmp/$$PPID $@

TAGS:
	etags $$(find $$(pkg-config --variable=includedir wlroots) $$(pkg-config --variable=includedir wayland-server) -name \*.[ch])


fenestra: $(LUA_SRCS) defs.h.out
	echo "#!/usr/bin/env luajit" > fenestra.tmp
	for i in $(LUA_SRCS) ; \
	  do ( echo "dofile('./$$i')" >> fenestra.tmp ) ; \
	done
	mv fenestra.tmp $@ && chmod +x $@

