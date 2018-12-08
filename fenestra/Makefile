default: fenestra defs.h.out
SRCS=main.c
OBJS=$(patsubst %.c,%.o, $(SRCS))
LIBS=$(shell pkg-config --libs luajit) \
     $(shell pkg-config --libs wayland-server) \
     -L../build

defs.h.out:defs.h
	$(CC) -P -E - < $^ |cat -s > $$$$ && mv $$$$ $@


fenestra: $(OBJS) Makefile
	$(CC) -o $@ $<  $(LDFLAGS) $(LIBS)
