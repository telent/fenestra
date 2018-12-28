
FENNEL_SRCS=main.fnl
LUA_SRCS=$(patsubst %.fnl,%.lua,$(FENNEL_SRCS))

default: fenestra

LIBS=$(shell pkg-config --libs luajit) \
     $(shell pkg-config --libs wayland-server) \
     $(shell pkg-config --libs xkbcommon) 

CFLAGS=$(shell pkg-config --cflags xkbcommon) \
       $(shell pkg-config --cflags wayland-server) \
       $(shell pkg-config --cflags wlroots) 

%.lua:%.fnl
	$(FENNEL) --compile $< > /tmp/$$PPID
	mv /tmp/$$PPID $@

defs.h.out:defs.h Makefile
	$(CC) $(CFLAGS) -P -E - < $^ |cat -s > /tmp/$$PPID
	mv /tmp/$$PPID $@

TAGS:
	etags $$(find $$(pkg-config --variable=includedir wlroots) $$(pkg-config --variable=includedir wayland-server) -name \*.[ch])


fenestra: $(LUA_SRCS) defs.h.out
	echo "#!/usr/bin/env luajit" > fenestra.tmp
	for i in $(LUA_SRCS) ; \
	  do ( echo "dofile('./$$i')" >> fenestra.tmp ) ; \
	done
	mv fenestra.tmp $@ && chmod +x $@

