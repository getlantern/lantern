/*
 * Copyright (C) Ambroz Bizjak <ambrop7@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the author nor the
 *    names of its contributors may be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _TUN2IO_H
#define _TUN2IO_H

// name of the program
#define PROGRAM_NAME "tun2io"

// size of temporary buffer for passing data from the SOCKS server to TCP for sending
#define CLIENT_SOCKS_RECV_BUF_SIZE 8192

// maximum number of udpgw connections
#define DEFAULT_UDPGW_MAX_CONNECTIONS 256

// udpgw per-connection send buffer size, in number of packets
#define DEFAULT_UDPGW_CONNECTION_BUFFER_SIZE 8

// udpgw reconnect time after connection fails
#define UDPGW_RECONNECT_TIME 5000

// udpgw keepalive sending interval
#define UDPGW_KEEPALIVE_TIME 10000

#include <stdint.h>
#include <stdio.h>
#include <stddef.h>
#include <string.h>
#include <limits.h>

#include <misc/version.h>
#include <misc/loglevel.h>
#include <misc/dead.h>
#include <misc/ipv4_proto.h>
#include <misc/ipv6_proto.h>
#include <misc/open_standard_streams.h>
#include <misc/ipaddr6.h>
#include <system/BReactor.h>
#include <system/BSignal.h>
#include <system/BAddr.h>
#include <system/BNetwork.h>
#include <flow/SinglePacketBuffer.h>
#include <tuntap/BTap.h>
#include <lwip/init.h>
#include <lwip/tcp_impl.h>
#include <lwip/netif.h>
#include <lwip/tcp.h>

#ifndef BADVPN_USE_WINAPI
#include <base/BLog_syslog.h>
#endif

#define LOGGER_STDOUT 1
#define LOGGER_SYSLOG 2

#define SYNC_DECL \
	BPending sync_mark; \

#define SYNC_FROMHERE \
	BPending_Init(&sync_mark, BReactor_PendingGroup(&ss), NULL, NULL); \
	BPending_Set(&sync_mark);

#define SYNC_BREAK \
	BPending_Free(&sync_mark);

#define SYNC_COMMIT \
	BReactor_Synchronize(&ss, &sync_mark.base); \
	BPending_Free(&sync_mark);

// command-line options
typedef struct {
  int logger;
	#ifndef BADVPN_USE_WINAPI
	char *logger_syslog_facility;
	char *logger_syslog_ident;
	#endif
	int loglevel;
	char *tundev;
	char *netif_ipaddr;
	char *netif_netmask;
	char *netif_ip6addr;
} options_t;

options_t options;

// TCP client
struct tcp_client {
	dead_t dead;
	dead_t dead_client;
	BAddr local_addr;
	BAddr remote_addr;
	struct tcp_pcb *pcb;
	int client_closed;
	uint8_t buf[TCP_WND];
	int buf_used;
	uint32_t tunnel_id;
};

static void terminate (void);
static void signal_handler (void *unused);
static BAddr baddr_from_lwip (int is_ipv6, const ipX_addr_t *ipx_addr, uint16_t port_hostorder);
static void lwip_init_job_hadler (void *unused);
static void tcp_timer_handler (void *unused);
static void device_error_handler (void *unused);
static void device_read_handler_send (void *unused, uint8_t *data, int data_len);
static err_t netif_init_func (struct netif *netif);
static err_t netif_output_func (struct netif *netif, struct pbuf *p, ip_addr_t *ipaddr);
static err_t netif_output_ip6_func (struct netif *netif, struct pbuf *p, ip6_addr_t *ipaddr);
static err_t common_netif_output (struct netif *netif, struct pbuf *p);
static err_t netif_input_func (struct pbuf *p, struct netif *inp);
static void client_logfunc (struct tcp_client *client);
static void client_log (struct tcp_client *client, int level, const char *fmt, ...);
static err_t listener_accept_func (void *arg, struct tcp_pcb *newpcb, err_t err);
static void client_close (struct tcp_client *client);
static void client_err_func (void *arg, err_t err);
static err_t client_recv_func (void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err);
static err_t client_sent_func (void *arg, struct tcp_pcb *tpcb, u16_t len);
static int setup_listener(options_t);
static int configure(char *tundev, char *ipaddr, char *netmask);

uint32_t goNewTunnel(struct tcp_client *client);
int goTunnelWrite(uint32_t tunno, char *data, size_t size);
int goTunnelDestroy(uint32_t tunno);

static char *dump_dest_addr(struct tcp_client *client);

#endif
