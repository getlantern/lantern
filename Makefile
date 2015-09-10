BADVPNDIR=badvpn
LWIPDIR ?=$(BADVPNDIR)/lwip
INCLUDES =-I$(BADVPNDIR) -I$(LWIPDIR)/src/include/ipv4 -I$(LWIPDIR)/src/include/ipv6 -I$(LWIPDIR)/src/include -I$(LWIPDIR)/custom
CC ?= gcc
AR ?= ar
CFLAGS="-std=gnu99"
CDEFS=-DBADVPN_THREAD_SAFE=0 -DBADVPN_LINUX -DBADVPN_BREACTOR_BADVPN -D_GNU_SOURCE -DBADVPN_USE_SIGNALFD -DBADVPN_USE_EPOLL -DBADVPN_LITTLE_ENDIAN
ENDIAN=little
OBJDIR=./obj

all: deps main

main:
	$(CC) $(CFLAGS) $(CDEFS) $(INCLUDES) $(LDFLAGS) -o tun2io tun2io.* $(OBJDIR)/*.o -lrt -lpthread

lib: deps-lib
	mkdir -p lib && \
	$(CC) -fpic -c $(CFLAGS) $(CDEFS) $(INCLUDES) $(LDFLAGS) tun2io.c -lrt -lpthread && \
	$(CC) -shared -o lib/libtun2io.so tun2io.o $(OBJDIR)/*.o -lrt -lpthread
	$(AR) rcs lib/libtun2io.a tun2io.o $(OBJDIR)/*.o

tun2socks:
	$(CC) $(CDEFS) $(INCLUDES) $(LDFLAGS) -o tun2socks $(OBJDIR)/*.o -lrt -lpthread

deps-lib:
	mkdir -p $(OBJDIR) && \
	for f in $$(cat files.txt | grep -v "^#"); do \
		o=$$(basename "$$f" .c).o && \
		$(CC) -fpic -c $(CFLAGS) $(CDEFS) $(INCLUDES) $(BADVPNDIR)/$$f -o $(OBJDIR)/$$o && \
		echo "-> $(OBJDIR)/$$o"; \
	done

deps:
	mkdir -p $(OBJDIR) && \
	for f in $$(cat files.txt | grep -v "^#"); do \
		o=$$(basename "$$f" .c).o && \
		$(CC) -c $(CFLAGS) $(CDEFS) $(INCLUDES) $(BADVPNDIR)/$$f -o $(OBJDIR)/$$o && \
		echo "-> $(OBJDIR)/$$o"; \
	done

clean:
	rm -f $(OBJDIR)/*.o

.PHONY: main tun2socks
