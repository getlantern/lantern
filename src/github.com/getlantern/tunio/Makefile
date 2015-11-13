BADVPNDIR = badvpn
LWIPDIR ?= $(BADVPNDIR)/lwip
INCLUDES = -I$(BADVPNDIR) -I$(LWIPDIR)/src/include/ipv4 -I$(LWIPDIR)/src/include/ipv6 -I$(LWIPDIR)/src/include -I$(LWIPDIR)/custom
CC ?= gcc
AR ?= ar
LIBS ?= -lrt -lpthread
CFLAGS ="-std=gnu99"
CDEFS ?= -DBADVPN_THREAD_SAFE=0 -DBADVPN_LINUX -DBADVPN_BREACTOR_BADVPN -D_GNU_SOURCE -DBADVPN_USE_POLL -DBADVPN_LITTLE_ENDIAN -DBADVPN_USE_SELFPIPE
ENDIAN = little
OBJDIR = ./obj

all: deps main

main:
	$(CC) $(CFLAGS) $(CDEFS) $(INCLUDES) $(LDFLAGS) -o tun2io tun2io.* $(OBJDIR)/*.o $(LIBS)

docker-android-lib:
	GCCBIN=/pkg/gomobile/android-ndk-r10e/arm/bin \
	LIBS="-ldl" \
	CC=$$GCCBIN/arm-linux-androideabi-gcc \
	AR=$$GCCBIN/arm-linux-androideabi-ar \
	make lib

lib: deps-lib
	mkdir -p lib && \
	$(CC) -fpic -c $(CFLAGS) $(CDEFS) $(INCLUDES) $(LDFLAGS) tun2io.c $(LIBS) && \
	$(CC) -shared -o lib/libtun2io.so tun2io.o $(OBJDIR)/*.o $(LIBS)
	$(AR) rcs lib/libtun2io.a tun2io.o $(OBJDIR)/*.o

tun2socks:
	$(CC) $(CDEFS) $(INCLUDES) $(LDFLAGS) -o tun2socks $(OBJDIR)/*.o $(LIBS)

deps-lib:
	mkdir -p $(OBJDIR) && \
	for f in $$(cat compile.list | grep -v "^#"); do \
		o=$$(basename "$$f" .c).o && \
		$(CC) -fpic -c $(CFLAGS) $(CDEFS) $(INCLUDES) $(BADVPNDIR)/$$f -o $(OBJDIR)/$$o $(LIBS) && \
		echo "-> $(OBJDIR)/$$o"; \
	done

deps:
	mkdir -p $(OBJDIR) && \
	for f in $$(cat compile.list | grep -v "^#"); do \
		o=$$(basename "$$f" .c).o && \
		$(CC) -c $(CFLAGS) $(CDEFS) $(INCLUDES) $(BADVPNDIR)/$$f -o $(OBJDIR)/$$o && \
		echo "-> $(OBJDIR)/$$o"; \
	done

clean:
	rm -f $(OBJDIR)/*.o
	rm -f lib/*
	rm -f *.o

.PHONY: main tun2socks
