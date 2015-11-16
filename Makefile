BADVPNDIR = badvpn
LWIPDIR ?= $(BADVPNDIR)/lwip
INCLUDES = -I$(BADVPNDIR) -I$(LWIPDIR)/src/include/ipv4 -I$(LWIPDIR)/src/include/ipv6 -I$(LWIPDIR)/src/include -I$(LWIPDIR)/custom
CC ?= gcc
AR ?= ar
LIBS ?= -lrt -lpthread

LOCAL_CFLAGS = -std=gnu99
LOCAL_CFLAGS += -DBADVPN_THREAD_SAFE=0 -DBADVPN_LINUX -DBADVPN_BREACTOR_BADVPN -D_GNU_SOURCE
LOCAL_CFLAGS += -DBADVPN_USE_EPOLL -DBADVPN_USE_SELFPIPE
LOCAL_CFLAGS += -DBADVPN_LITTLE_ENDIAN

ENDIAN = little
OBJDIR = ./obj

libtun2io: deps main

docker-android-libtun2io:
	GCCBIN=/pkg/gomobile/android-ndk-r10e/arm/bin \
	LIBS="" \
	CC=$$GCCBIN/arm-linux-androideabi-gcc \
	AR=$$GCCBIN/arm-linux-androideabi-ar \
	make lib

lib: deps
	mkdir -p lib && \
	$(CC) -fpic -c $(LOCAL_CFLAGS) $(INCLUDES) $(LDFLAGS) tun2io.c $(LIBS) && \
	$(CC) -shared -o lib/libtun2io.so tun2io.o $(OBJDIR)/*.o $(LIBS)
	$(AR) rcs lib/libtun2io.a tun2io.o $(OBJDIR)/*.o

deps:
	mkdir -p $(OBJDIR) && \
	for f in $$(cat compile.list | grep -v "^#"); do \
		o=$$(basename "$$f" .c).o && \
		$(CC) -fpic -c $(LOCAL_CFLAGS) $(INCLUDES) $(BADVPNDIR)/$$f -o $(OBJDIR)/$$o $(LIBS) && \
		echo "-> $(OBJDIR)/$$o"; \
	done

clean:
	rm -f $(OBJDIR)/*.o
	rm -f lib/*
	rm -f *.o

.PHONY: libtun2io
