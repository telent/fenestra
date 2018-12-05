default: fenestra
SRCS=main.c
OBJS=$(patsubst %.c,%.o, $(SRCS))
LIBS=$(shell pkg-config --libs luajit) \
     $(shell pkg-config --libs wayland-server) \
     -L../build -Wl,-rpath,../build -lwlroots


fenestra: $(OBJS) Makefile
	$(CC) -o $@ $<  $(LDFLAGS) $(LIBS)
