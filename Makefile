default: defs.h.out fenestra

FENNEL_SRCS=main.fnl
LUA_SRCS=$(patsubst %.fnl,%.lua,$(FENNEL_SRCS))

LIBS=$(shell pkg-config --libs luajit) \
     $(shell pkg-config --libs wayland-server) \
     $(shell pkg-config --libs xkbcommon) 

CFLAGS=$(shell pkg-config --cflags xkbcommon) \
       $(shell pkg-config --cflags wayland-server) \
       $(shell pkg-config --cflags wlroots) 

defs.h.out:defs.h Makefile
	$(CC) $(CFLAGS) -P -E - < $^ |cat -s > $$$$ && mv $$$$ $@

%.lua:%.fnl
	$(FENNEL) --compile $< > $$$$ && mv $$$$ $@
