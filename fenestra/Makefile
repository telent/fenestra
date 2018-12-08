default: fenestra defs.h.out
SRCS=main.c
OBJS=$(patsubst %.c,%.o, $(SRCS))
LIBS=$(shell pkg-config --libs luajit) \
     $(shell pkg-config --libs wayland-server) \
     -L../build
CFLAGS=-I../include

defs.h.out:defs.h Makefile
	$(CC) $(CFLAGS) -P -E - < $^ |cat -s > $$$$ && mv $$$$ $@


fenestra: $(OBJS) Makefile
	$(CC) -o $@ $<  $(LDFLAGS) $(LIBS)
