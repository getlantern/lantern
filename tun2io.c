/*
 * Copyright (C) Ambroz Bizjak <ambrop7@gmail.com>
 * Contributions:
 * Transparent DNS: Copyright (C) Kerem Hadimli <kerem.hadimli@gmail.com>
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

#include "tun2io.h"

#ifndef _TUN2IO_C
#define _TUN2IO_C

// IP address of netif
BIPAddr netif_ipaddr;

// netmask of netif
BIPAddr netif_netmask;

// IP6 address of netif
struct ipv6_addr netif_ip6addr;

// reactor
BReactor ss;

// set to 1 by terminate
int quitting;

// TUN device
BTap device;

// device write buffer
uint8_t *device_write_buf;

// device reading
SinglePacketBuffer device_read_buffer;
PacketPassInterface device_read_interface;

// udpgw client
int udp_mtu;

// remote udpgw server addr, if provided
BAddr udpgw_remote_server_addr;

// TCP timer
BTimer tcp_timer;

// job for initializing lwip
BPending lwip_init_job;

// lwip netif
int have_netif;
struct netif netif;

// lwip TCP listener
struct tcp_pcb *listener;

// lwip TCP/IPv6 listener
struct tcp_pcb *listener_ip6;

static int configure(char *tundev, char *ipaddr, char *netmask, char *udpgw_addr)
{
  // open standard streams
  open_standard_streams();

  // parse command-line arguments
  options.logger = LOGGER_STDOUT;
  #ifndef BADVPN_USE_WINAPI
  options.logger_syslog_facility = "daemon";
  options.logger_syslog_ident = "tun2io";
  #endif

  options.loglevel = -1;

  options.tundev = tundev;
  options.netif_ipaddr = ipaddr;
  options.netif_netmask = netmask;

  // initialize logger
  switch (options.logger) {
    case LOGGER_STDOUT:
      BLog_InitStdout();
    break;
    #ifndef BADVPN_USE_WINAPI
    case LOGGER_SYSLOG:
      if (!BLog_InitSyslog(options.logger_syslog_ident, options.logger_syslog_facility)) {
        fprintf(stderr, "Failed to initialize syslog logger\n");
        DebugObjectGlobal_Finish();
        return 1;
      }
    break;
    #endif
    default:
      ASSERT(0);
  }

  // resolve netif ipaddr
  if (!BIPAddr_Resolve(&netif_ipaddr, options.netif_ipaddr, 0)) {
    BLog(BLOG_ERROR, "netif ipaddr: BIPAddr_Resolve failed");
    return 0;
  }
  if (netif_ipaddr.type != BADDR_TYPE_IPV4) {
    BLog(BLOG_ERROR, "netif ipaddr: must be an IPv4 address");
    return 0;
  }

  // resolve netif netmask
  if (!BIPAddr_Resolve(&netif_netmask, options.netif_netmask, 0)) {
    BLog(BLOG_ERROR, "netif netmask: BIPAddr_Resolve failed");
    return 0;
  }
  if (netif_netmask.type != BADDR_TYPE_IPV4) {
    BLog(BLOG_ERROR, "netif netmask: must be an IPv4 address");
    return 0;
  }

  // parse IP6 address
  if (options.netif_ip6addr) {
    if (!ipaddr6_parse_ipv6_addr(options.netif_ip6addr, &netif_ip6addr)) {
      BLog(BLOG_ERROR, "netif ip6addr: incorrect");
      return 0;
    }
  }

  options.udpgw_remote_server_addr = udpgw_addr;
  options.udpgw_max_connections = DEFAULT_UDPGW_MAX_CONNECTIONS;
  options.udpgw_connection_buffer_size = DEFAULT_UDPGW_CONNECTION_BUFFER_SIZE;
  options.udpgw_transparent_dns = 0;

  // resolve remote udpgw server address
  if (options.udpgw_remote_server_addr) {
    if (!BAddr_Parse2(&udpgw_remote_server_addr, options.udpgw_remote_server_addr, NULL, 0, 0)) {
      BLog(BLOG_ERROR, "remote udpgw server addr: BAddr_Parse2 failed");
      return 0;
    }
  }

  return setup_listener(options);
}

static int setup_listener (options_t options)
{
  BLog(BLOG_NOTICE, "initializing "GLOBAL_PRODUCT_NAME" "PROGRAM_NAME" "GLOBAL_VERSION);

  // initialize network
  if (!BNetwork_GlobalInit()) {
    BLog(BLOG_ERROR, "BNetwork_GlobalInit failed");
    BLog_Free();
    return 1;
  }

  // init time
  BTime_Init();

  // init reactor
  if (!BReactor_Init(&ss)) {
    BLog(BLOG_ERROR, "BReactor_Init failed");
    BLog_Free();
    return 1;
  }

  // set not quitting
  quitting = 0;

  // setup signal handler
  if (!BSignal_Init(&ss, signal_handler, NULL)) {
    BLog(BLOG_ERROR, "BSignal_Init failed");
    BReactor_Free(&ss);
    return 1;
  }

  // init TUN device
  if (!BTap_Init(&device, &ss, options.tundev, device_error_handler, NULL, 1)) {
    BLog(BLOG_ERROR, "BTap_Init failed");
    BSignal_Finish();
    return 1;
  }

  // NOTE: the order of the following is important:
  // first device writing must evaluate,
  // then lwip (so it can send packets to the device),
  // then device reading (so it can pass received packets to lwip).

  // init device reading
  PacketPassInterface_Init(&device_read_interface, BTap_GetMTU(&device), device_read_handler_send, NULL, BReactor_PendingGroup(&ss));
  if (!SinglePacketBuffer_Init(&device_read_buffer, BTap_GetOutput(&device), &device_read_interface, BReactor_PendingGroup(&ss))) {
    BLog(BLOG_ERROR, "SinglePacketBuffer_Init failed");
    PacketPassInterface_Free(&device_read_interface);
    BTap_Free(&device);
    return 1;
  }

  if (options.udpgw_remote_server_addr) {
    // compute maximum UDP payload size we need to pass through udpgw
    udp_mtu = BTap_GetMTU(&device) - (int)(sizeof(struct ipv4_header) + sizeof(struct udp_header));
    if (options.netif_ip6addr) {
      int udp_ip6_mtu = BTap_GetMTU(&device) - (int)(sizeof(struct ipv6_header) + sizeof(struct udp_header));
      if (udp_mtu < udp_ip6_mtu) {
        udp_mtu = udp_ip6_mtu;
      }
    }
    if (udp_mtu < 0) {
      udp_mtu = 0;
    }

    // make sure our UDP payloads aren't too large for udpgw
    int udpgw_mtu = udpgw_compute_mtu(udp_mtu);
    if (udpgw_mtu < 0 || udpgw_mtu > PACKETPROTO_MAXPAYLOAD) {
      BLog(BLOG_ERROR, "device MTU is too large for UDP");
      SinglePacketBuffer_Free(&device_read_buffer);
      return 1;
    }

    int udpgw_client_err = goUdpGwClient_Configure(udp_mtu, DEFAULT_UDPGW_MAX_CONNECTIONS, options.udpgw_connection_buffer_size, UDPGW_KEEPALIVE_TIME);
    if (udpgw_client_err != ERR_OK) {
      BLog(BLOG_ERROR, "goUdpGwClient_Configure failed");
      SinglePacketBuffer_Free(&device_read_buffer);
      return 1;
    }
  }

  // init lwip init job
  BPending_Init(&lwip_init_job, BReactor_PendingGroup(&ss), lwip_init_job_hadler, NULL);
  BPending_Set(&lwip_init_job);

  // init device write buffer
  if (!(device_write_buf = (uint8_t *)BAlloc(BTap_GetMTU(&device)))) {
    BLog(BLOG_ERROR, "BAlloc failed");
    BPending_Free(&lwip_init_job);
    return 1;
  }

  // init TCP timer
  // it won't trigger before lwip is initialized, becuase the lwip init is a job
  BTimer_Init(&tcp_timer, TCP_TMR_INTERVAL, tcp_timer_handler, NULL);
  BReactor_SetTimer(&ss, &tcp_timer);

  // set no netif
  have_netif = 0;

  // set no listener
  listener = NULL;
  listener_ip6 = NULL;

  // enter event loop
  BLog(BLOG_NOTICE, "entering event loop");
  BReactor_Exec(&ss);
  BLog(BLOG_NOTICE, "exiting event loop");

  // free listener
  if (listener_ip6) {
    tcp_close(listener_ip6);
  }

  if (listener) {
    tcp_close(listener);
  }

  // free netif
  if (have_netif) {
    netif_remove(&netif);
  }

  BReactor_RemoveTimer(&ss, &tcp_timer);
  BFree(device_write_buf);

  return 0;
}

void terminate (void)
{
  if (!quitting) {
    BLog(BLOG_NOTICE, "tearing down");

    // set quitting
    quitting = 1;

    // exit event loop
    BReactor_Quit(&ss, 1);
  }
}

void signal_handler (void *unused)
{
  ASSERT(!quitting)

  BLog(BLOG_NOTICE, "termination requested");

  terminate();
}

BAddr baddr_from_lwip (int is_ipv6, const ipX_addr_t *ipx_addr, uint16_t port_hostorder)
{
  BAddr addr;
  if (is_ipv6) {
    BAddr_InitIPv6(&addr, (uint8_t *)ipx_addr->ip6.addr, hton16(port_hostorder));
  } else {
    BAddr_InitIPv4(&addr, ipx_addr->ip4.addr, hton16(port_hostorder));
  }
  return addr;
}

void lwip_init_job_hadler (void *unused)
{
  ASSERT(!quitting)
  ASSERT(netif_ipaddr.type == BADDR_TYPE_IPV4)
  ASSERT(netif_netmask.type == BADDR_TYPE_IPV4)
  ASSERT(!have_netif)
  ASSERT(!listener)
  ASSERT(!listener_ip6)

  BLog(BLOG_DEBUG, "lwip init");

  // NOTE: the device may fail during this, but there's no harm in not checking
  // for that at every step

  // init lwip
  lwip_init();

  // make addresses for netif
  ip_addr_t addr;
  addr.addr = netif_ipaddr.ipv4;
  ip_addr_t netmask;
  netmask.addr = netif_netmask.ipv4;
  ip_addr_t gw;
  ip_addr_set_any(&gw);

  // init netif
  if (!netif_add(&netif, &addr, &netmask, &gw, NULL, netif_init_func, netif_input_func)) {
    BLog(BLOG_ERROR, "netif_add failed");
    terminate();
    return;
  }
  have_netif = 1;

  // set netif up
  netif_set_up(&netif);

  // set netif pretend TCP
  netif_set_pretend_tcp(&netif, 1);

  // set netif default
  netif_set_default(&netif);

  if (options.netif_ip6addr) {
    // add IPv6 address
    memcpy(netif_ip6_addr(&netif, 0), netif_ip6addr.bytes, sizeof(netif_ip6addr.bytes));
    netif_ip6_addr_set_state(&netif, 0, IP6_ADDR_VALID);
  }

  // init listener
  struct tcp_pcb *l = tcp_new();
  if (!l) {
    BLog(BLOG_ERROR, "tcp_new failed");
    terminate();
    return;
  }

  // bind listener
  if (tcp_bind_to_netif(l, "ho0") != ERR_OK) {
    BLog(BLOG_ERROR, "tcp_bind_to_netif failed");
    tcp_close(l);
    terminate();
    return;
  }

  // listen listener
  if (!(listener = tcp_listen(l))) {
    BLog(BLOG_ERROR, "tcp_listen failed");
    tcp_close(l);
    terminate();
    return;
  }

  // setup listener accept handler
  tcp_accept(listener, listener_accept_func);

  if (options.netif_ip6addr) {
    struct tcp_pcb *l_ip6 = tcp_new_ip6();
    if (!l_ip6) {
      BLog(BLOG_ERROR, "tcp_new_ip6 failed");
      terminate();
      return;
    }

    if (tcp_bind_to_netif(l_ip6, "ho0") != ERR_OK) {
      BLog(BLOG_ERROR, "tcp_bind_to_netif failed");
      tcp_close(l_ip6);
      terminate();
      return;
    }

    if (!(listener_ip6 = tcp_listen(l_ip6))) {
      BLog(BLOG_ERROR, "tcp_listen failed");
      tcp_close(l_ip6);
      terminate();
      return;
    }

    tcp_accept(listener_ip6, listener_accept_func);
  }

  BLog(BLOG_NOTICE, "lwip_init_job_hadler");
}

void tcp_timer_handler (void *unused)
{
  ASSERT(!quitting)

  BLog(BLOG_DEBUG, "TCP timer");

  // schedule next timer
  // TODO: calculate timeout so we don't drift
  BReactor_SetTimer(&ss, &tcp_timer);

  tcp_tmr();
  return;
}

void device_error_handler (void *unused)
{
  ASSERT(!quitting)

  BLog(BLOG_ERROR, "device error");

  terminate();
  return;
}

void device_read_handler_send (void *unused, uint8_t *data, int data_len)
{
  ASSERT(!quitting)
  ASSERT(data_len >= 0)
  BLog(BLOG_NOTICE, "device: received packet");

  // accept packet
  PacketPassInterface_Done(&device_read_interface);

  // process UDP directly
  if (process_device_udp_packet(data, data_len)) {
    return;
  }

  // obtain pbuf
  if (data_len > UINT16_MAX) {
    BLog(BLOG_WARNING, "device read: packet too large");
    free(data);
    return;
  }
  struct pbuf *p = pbuf_alloc(PBUF_RAW, data_len, PBUF_POOL);
  if (!p) {
    BLog(BLOG_WARNING, "device read: pbuf_alloc failed");
    free(data);
    return;
  }

  // write packet to pbuf
  ASSERT_FORCE(pbuf_take(p, data, data_len) == ERR_OK)

  // pass pbuf to input
  if (netif.input(p, &netif) != ERR_OK) {
    BLog(BLOG_WARNING, "device read: input failed");
    pbuf_free(p);
  }
}

err_t netif_init_func (struct netif *netif)
{
  BLog(BLOG_DEBUG, "netif func init");

  netif->name[0] = 'h';
  netif->name[1] = 'o';
  netif->output = netif_output_func;
  netif->output_ip6 = netif_output_ip6_func;

  return ERR_OK;
}

err_t netif_output_func (struct netif *netif, struct pbuf *p, ip_addr_t *ipaddr)
{
  return common_netif_output(netif, p);
}

err_t netif_output_ip6_func (struct netif *netif, struct pbuf *p, ip6_addr_t *ipaddr)
{
  return common_netif_output(netif, p);
}

err_t common_netif_output (struct netif *netif, struct pbuf *p)
{
  BLog(BLOG_DEBUG, "device write: send packet");

  if (quitting) {
    return ERR_OK;
  }

  // if there is just one chunk, send it directly, else via buffer
  if (!p->next) {
    if (p->len > BTap_GetMTU(&device)) {
      BLog(BLOG_WARNING, "netif func output: no space left");
      return ERR_OK;
    }

    BTap_Send(&device, (uint8_t *)p->payload, p->len);
  } else {
    int len = 0;
    do {
      if (p->len > BTap_GetMTU(&device) - len) {
        BLog(BLOG_WARNING, "netif func output: no space left");
        return ERR_OK;
      }
      memcpy(device_write_buf + len, p->payload, p->len);
      len += p->len;
    } while (p = p->next);

    BTap_Send(&device, device_write_buf, len);
  }

  return ERR_OK;
}

err_t netif_input_func (struct pbuf *p, struct netif *inp)
{
  uint8_t ip_version = 0;
  if (p->len > 0) {
    ip_version = (((uint8_t *)p->payload)[0] >> 4);
  }

  switch (ip_version) {
    case 4: {
      return ip_input(p, inp);
    } break;
    case 6: {
      if (options.netif_ip6addr) {
        return ip6_input(p, inp);
      }
    } break;
  }

  pbuf_free(p);
  return ERR_OK;
}

err_t listener_accept_func (void *arg, struct tcp_pcb *newpcb, err_t err)
{
  ASSERT(err == ERR_OK)

  // signal accepted
  struct tcp_pcb *this_listener = (PCB_ISIPV6(newpcb) ? listener_ip6 : listener);
  tcp_accepted(this_listener);

  // allocate client structure
  struct tcp_client *client = (struct tcp_client *)malloc(sizeof(*client));
  if (!client) {
    BLog(BLOG_ERROR, "listener accept: malloc failed");
    return ERR_MEM;
  }

  // read addresses
  client->local_addr = baddr_from_lwip(PCB_ISIPV6(newpcb), &newpcb->local_ip, newpcb->local_port);
  client->remote_addr = baddr_from_lwip(PCB_ISIPV6(newpcb), &newpcb->remote_ip, newpcb->remote_port);

  // get destination address
  BAddr addr = client->local_addr;
#ifdef OVERRIDE_DEST_ADDR
  ASSERT_FORCE(BAddr_Parse2(&addr, OVERRIDE_DEST_ADDR, NULL, 0, 1))
#endif

  // Init Go tunnel.
  client->tunnel_id = 0;

#ifdef CGO
  switch (client->remote_addr.type) {
    case BADDR_TYPE_IPV4:
      client->tunnel_id = goNewTunnel(client);
      if (client->tunnel_id == 0) {
        BLog(BLOG_ERROR, "could not create new tunnel.");
        return ERR_MEM;
      }
      err_t err = goInitTunnel(client->tunnel_id);
      if (err != ERR_OK) {
        BLog(BLOG_ERROR, "could not initialize tunnel.");
        return ERR_ABRT;
      }
    break;
  }
#endif

  // set pcb
  client->pcb = newpcb;

  // set client not closed
  client->client_closed = 0;

  // setup handler argument
  tcp_arg(client->pcb, client);

  // setup handlers
  tcp_err(client->pcb, client_err_func);
  tcp_recv(client->pcb, client_recv_func);
  tcp_sent(client->pcb, client_sent_func);

  // setup buffer
  client->buf_used = 0;

  return ERR_OK;
}

static void client_handle_freed_client(struct tcp_client *client)
{
  if (client == NULL) {
    return;
  }

  err_t err = goTunnelDestroy(client->tunnel_id);

  if (err == ERR_OK) {
    client->client_closed = 1;
    client->tunnel_id = 0;
    free(client);
  }
}

void client_close(struct tcp_client *client)
{
  if (client == NULL) {
    return;
  }

  if (!client->client_closed) {
    client_free_client(client);
  }
}

static void client_free_client (struct tcp_client *client)
{
    ASSERT(!client->client_closed)

    // remove callbacks
    tcp_err(client->pcb, NULL);
    tcp_recv(client->pcb, NULL);
    tcp_sent(client->pcb, NULL);

    // free pcb
    err_t err = tcp_close(client->pcb);
    if (err != ERR_OK) {
      tcp_abort(client->pcb);
    }

    client_handle_freed_client(client);
}

void client_err_func (void *arg, err_t err)
{
  struct tcp_client *client = (struct tcp_client *)arg;

  ASSERT(!client->client_closed)

  client_handle_freed_client(client);
}

static err_t client_recv_func(void *arg, struct tcp_pcb *pcb, struct pbuf *p, err_t err)
{
  struct tcp_client *client = (struct tcp_client *)arg;

  if (client->client_closed) {
    return ERR_ABRT;
  }

  if (err != ERR_OK) {
    return ERR_ABRT;
  }

  if (!p) {
    client_free_client(client);
    return ERR_ABRT;
  }

  ASSERT(p->tot_len > 0)

  err_t werr;
  werr = goTunnelWrite(client->tunnel_id, p->payload, p->len);

  if (werr == ERR_OK) {
    tcp_recved(client->pcb, p->len);
  }

  pbuf_free(p);

  return werr;
}

err_t client_sent_func (void *arg, struct tcp_pcb *tpcb, u16_t len)
{
  struct tcp_client *client = (struct tcp_client *)arg;

  ASSERT(!client->client_closed)
  ASSERT(len > 0)

  if (client == NULL) {
    return ERR_ABRT;
  }

  if (client->client_closed) {
    return ERR_ABRT;
  }

  return goTunnelSentACK(client->tunnel_id, len);
}

static char *baddr_to_str(BAddr *baddr) {
  char *dest;
  dest = malloc(sizeof(char)*BADDR_MAX_ADDR_LEN);
  BAddr_Print(baddr, dest);
  return dest;
}

// dump_dest_addr dumps the client's local address into an string.
static char *dump_dest_addr(struct tcp_client *client) {
  char *addr;
  addr = malloc(sizeof(char)*BADDR_MAX_ADDR_LEN);
  BAddr_Print(&client->local_addr, addr);
  return addr;
}

static unsigned int tcp_client_sndbuf(struct tcp_client *client) {
  return (unsigned int)tcp_sndbuf(client->pcb);
}

static void client_dealloc (struct tcp_client *client)
{
  ASSERT(client->client_closed)
  free(client);
}

static void client_abort_client (struct tcp_client *client)
{
  ASSERT(!client->client_closed)

  // remove callbacks
  tcp_err(client->pcb, NULL);
  tcp_recv(client->pcb, NULL);
  tcp_sent(client->pcb, NULL);

  // free pcb
  tcp_abort(client->pcb);

  client_handle_freed_client(client);
}

static int tcp_client_output(struct tcp_client *client) {
  if (client == NULL) {
    return ERR_ABRT;
  }

  if (client->client_closed) {
    return ERR_ABRT;
  }

  if (client->pcb) {
    err_t err =  tcp_output(client->pcb);
    if (err != ERR_OK) {
      return -1;
    }
  }

  return ERR_OK;
}

static void udpgw_client_handler_received(void *unused, BAddr local_addr, BAddr remote_addr, const uint8_t *data, int data_len)
{
  ASSERT(options.udpgw_remote_server_addr)
  ASSERT(local_addr.type == BADDR_TYPE_IPV4 || local_addr.type == BADDR_TYPE_IPV6)
  ASSERT(local_addr.type == remote_addr.type)
  ASSERT(data_len >= 0)

  int packet_length = 0;

  switch (local_addr.type) {
    case BADDR_TYPE_IPV4: {
      BLog(BLOG_INFO, "UDP: from udpgw %d bytes", data_len);

      if (data_len > UINT16_MAX - (sizeof(struct ipv4_header) + sizeof(struct udp_header)) ||
        data_len > BTap_GetMTU(&device) - (int)(sizeof(struct ipv4_header) + sizeof(struct udp_header))
      ) {
        BLog(BLOG_ERROR, "UDP: packet is too large");
        return;
      }

      // build IP header
      struct ipv4_header iph;
      iph.version4_ihl4 = IPV4_MAKE_VERSION_IHL(sizeof(iph));
      iph.ds = hton8(0);
      iph.total_length = hton16(sizeof(iph) + sizeof(struct udp_header) + data_len);
      iph.identification = hton16(0);
      iph.flags3_fragmentoffset13 = hton16(0);
      iph.ttl = hton8(64);
      iph.protocol = hton8(IPV4_PROTOCOL_UDP);
      iph.checksum = hton16(0);
      iph.source_address = remote_addr.ipv4.ip;
      iph.destination_address = local_addr.ipv4.ip;
      iph.checksum = ipv4_checksum(&iph, NULL, 0);

      // build UDP header
      struct udp_header udph;
      udph.source_port = remote_addr.ipv4.port;
      udph.dest_port = local_addr.ipv4.port;
      udph.length = hton16(sizeof(udph) + data_len);
      udph.checksum = hton16(0);
      udph.checksum = udp_checksum(&udph, data, data_len, iph.source_address, iph.destination_address);

      // write packet
      memcpy(device_write_buf, &iph, sizeof(iph));
      memcpy(device_write_buf + sizeof(iph), &udph, sizeof(udph));
      memcpy(device_write_buf + sizeof(iph) + sizeof(udph), data, data_len);
      packet_length = sizeof(iph) + sizeof(udph) + data_len;
    } break;

    case BADDR_TYPE_IPV6: {
      BLog(BLOG_INFO, "UDP/IPv6: from udpgw %d bytes", data_len);

      if (!options.netif_ip6addr) {
        BLog(BLOG_ERROR, "got IPv6 packet from udpgw but IPv6 is disabled");
        return;
      }

      if (data_len > UINT16_MAX - sizeof(struct udp_header) ||
        data_len > BTap_GetMTU(&device) - (int)(sizeof(struct ipv6_header) + sizeof(struct udp_header))
      ) {
        BLog(BLOG_ERROR, "UDP/IPv6: packet is too large");
        return;
      }

      // build IPv6 header
      struct ipv6_header iph;
      iph.version4_tc4 = hton8((6 << 4));
      iph.tc4_fl4 = hton8(0);
      iph.fl = hton16(0);
      iph.payload_length = hton16(sizeof(struct udp_header) + data_len);
      iph.next_header = hton8(IPV6_NEXT_UDP);
      iph.hop_limit = hton8(64);
      memcpy(iph.source_address, remote_addr.ipv6.ip, 16);
      memcpy(iph.destination_address, local_addr.ipv6.ip, 16);

      // build UDP header
      struct udp_header udph;
      udph.source_port = remote_addr.ipv6.port;
      udph.dest_port = local_addr.ipv6.port;
      udph.length = hton16(sizeof(udph) + data_len);
      udph.checksum = hton16(0);
      udph.checksum = udp_ip6_checksum(&udph, data, data_len, iph.source_address, iph.destination_address);

      // write packet
      memcpy(device_write_buf, &iph, sizeof(iph));
      memcpy(device_write_buf + sizeof(iph), &udph, sizeof(udph));
      memcpy(device_write_buf + sizeof(iph) + sizeof(udph), data, data_len);
      packet_length = sizeof(iph) + sizeof(udph) + data_len;
    } break;
  }

  // submit packet
  BTap_Send(&device, device_write_buf, packet_length);
}

static int process_device_udp_packet (uint8_t *data, int data_len)
{
  ASSERT(data_len >= 0)

  // Do nothing if we don't have udpgw
  if (!options.udpgw_remote_server_addr) {
    return 0;
  }

  BAddr local_addr;
  BAddr remote_addr;
  int is_dns;

  uint8_t ip_version = 0;
  if (data_len > 0) {
    ip_version = (data[0] >> 4);
  }

  switch (ip_version) {
    case 4: {
      // ignore non-UDP packets
      if (data_len < sizeof(struct ipv4_header) || data[offsetof(struct ipv4_header, protocol)] != IPV4_PROTOCOL_UDP) {
        return 0;
      }

      // parse IPv4 header
      struct ipv4_header ipv4_header;
      if (!ipv4_check(data, data_len, &ipv4_header, &data, &data_len)) {
        return 0;
      }

      // parse UDP
      struct udp_header udp_header;
      if (!udp_check(data, data_len, &udp_header, &data, &data_len)) {
        return 0;
      }

      // verify UDP checksum
      uint16_t checksum_in_packet = udp_header.checksum;
      udp_header.checksum = 0;
      uint16_t checksum_computed = udp_checksum(&udp_header, data, data_len, ipv4_header.source_address, ipv4_header.destination_address);
      if (checksum_in_packet != checksum_computed) {
        return 0;
      }

      BLog(BLOG_INFO, "UDP: from device %d bytes", data_len);

      // construct addresses
      BAddr_InitIPv4(&local_addr, ipv4_header.source_address, udp_header.source_port);
      BAddr_InitIPv4(&remote_addr, ipv4_header.destination_address, udp_header.dest_port);

      // if transparent DNS is enabled, any packet arriving at out netif
      // address to port 53 is considered a DNS packet
      is_dns = (options.udpgw_transparent_dns &&
                ipv4_header.destination_address == netif_ipaddr.ipv4 &&
                udp_header.dest_port == hton16(53));
    } break;

    case 6: {
      // ignore if IPv6 support is disabled
      if (!options.netif_ip6addr) {
        return 0;
      }

      // ignore non-UDP packets
      if (data_len < sizeof(struct ipv6_header) || data[offsetof(struct ipv6_header, next_header)] != IPV6_NEXT_UDP) {
        return 0;
      }

      // parse IPv6 header
      struct ipv6_header ipv6_header;
      if (!ipv6_check(data, data_len, &ipv6_header, &data, &data_len)) {
        return 0;
      }

      // parse UDP
      struct udp_header udp_header;
      if (!udp_check(data, data_len, &udp_header, &data, &data_len)) {
        return 0;
      }

      // verify UDP checksum
      uint16_t checksum_in_packet = udp_header.checksum;
      udp_header.checksum = 0;
      uint16_t checksum_computed = udp_ip6_checksum(&udp_header, data, data_len, ipv6_header.source_address, ipv6_header.destination_address);
      if (checksum_in_packet != checksum_computed) {
        return 0;
      }

      BLog(BLOG_INFO, "UDP/IPv6: from device %d bytes", data_len);

      // construct addresses
      BAddr_InitIPv6(&local_addr, ipv6_header.source_address, udp_header.source_port);
      BAddr_InitIPv6(&remote_addr, ipv6_header.destination_address, udp_header.dest_port);

      // TODO dns
      is_dns = 0;
    } break;

    default: {
      return 0;
    } break;
  }

  // check payload length
  if (data_len > udp_mtu) {
    BLog(BLOG_ERROR, "packet is too large, cannot send to udpgw");
    return 0;
  }

  // submit packet to udpgw
  UdpGwClient_SubmitPacket(local_addr, remote_addr, is_dns, data, data_len);

  return 1;
}

static uint8_t dataAt(uint8_t *in, int i) {
  return in[i];
}

static void udpGWClient_ReceiveFromServer(char *data, int data_len)
{
  ASSERT(data_len >= 0)

  // check header
  if (data_len < sizeof(struct udpgw_header)) {
    BLog(BLOG_ERROR, "missing header");
    return;
  }

  struct udpgw_header header;
  memcpy(&header, data, sizeof(header));
  data += sizeof(header);
  data_len -= sizeof(header);
  uint8_t flags = ltoh8(header.flags);
  uint16_t conid = ltoh16(header.conid);

  // parse address
  BAddr remote_addr;
  if ((flags & UDPGW_CLIENT_FLAG_IPV6)) {
    if (data_len < sizeof(struct udpgw_addr_ipv6)) {
      BLog(BLOG_ERROR, "missing ipv6 address");
      return;
    }
    struct udpgw_addr_ipv6 addr_ipv6;
    memcpy(&addr_ipv6, data, sizeof(addr_ipv6));
    data += sizeof(addr_ipv6);
    data_len -= sizeof(addr_ipv6);
    BAddr_InitIPv6(&remote_addr, addr_ipv6.addr_ip, addr_ipv6.addr_port);
  } else {
    if (data_len < sizeof(struct udpgw_addr_ipv4)) {
      BLog(BLOG_ERROR, "missing ipv4 address");
      return;
    }
    struct udpgw_addr_ipv4 addr_ipv4;
    memcpy(&addr_ipv4, data, sizeof(addr_ipv4));
    data += sizeof(addr_ipv4);
    data_len -= sizeof(addr_ipv4);
    BAddr_InitIPv4(&remote_addr, addr_ipv4.addr_ip, addr_ipv4.addr_port);
  }

  BAddr local_addr;
  local_addr = goUdpGwClient_GetLocalAddrByConnId(conid);

  // pass packet to user
  udpgw_client_handler_received(NULL, local_addr, remote_addr, data, data_len);
  return;
}

static void UdpGwClient_SendData(uint16_t connId, BAddr remote_addr, uint8_t flags, const uint8_t *data, int data_len)
{
  ASSERT(data_len >= 0)
  // ASSERT(data_len <= o->udp_mtu)

  // get buffer location
  uint8_t *out;
  out = malloc(sizeof(char)*(data_len + sizeof(struct udpgw_header) + sizeof(struct udpgw_addr_ipv6)));
  int out_pos = 0;

  flags |= UDPGW_CLIENT_FLAG_REBIND;
  //flags |= UDPGW_CLIENT_FLAG_DNS;

  if (remote_addr.type == BADDR_TYPE_IPV6) {
    flags |= UDPGW_CLIENT_FLAG_IPV6;
  }

  // write header
  struct udpgw_header header;
  header.flags = ltoh8(flags);
  header.conid = ltoh16(connId);
  memcpy(out + out_pos, &header, sizeof(header));
  out_pos += sizeof(header);

  // write address
  switch (remote_addr.type) {
    case BADDR_TYPE_IPV4: {
      struct udpgw_addr_ipv4 addr_ipv4;
      addr_ipv4.addr_ip = remote_addr.ipv4.ip;
      addr_ipv4.addr_port = remote_addr.ipv4.port;
      memcpy(out + out_pos, &addr_ipv4, sizeof(addr_ipv4));
      out_pos += sizeof(addr_ipv4);
    } break;
    case BADDR_TYPE_IPV6: {
      struct udpgw_addr_ipv6 addr_ipv6;
      memcpy(addr_ipv6.addr_ip, remote_addr.ipv6.ip, sizeof(addr_ipv6.addr_ip));
      addr_ipv6.addr_port = remote_addr.ipv6.port;
      memcpy(out + out_pos, &addr_ipv6, sizeof(addr_ipv6));
      out_pos += sizeof(addr_ipv6);
    } break;
    default:
      printf("no remote addr provided.");
    break;
  }

  // write packet to buffer
  memcpy(out + out_pos, data, data_len);
  out_pos += data_len;

  goUdpGwClient_Send(connId, out, out_pos);

  free(out);
}

static void UdpGwClient_SubmitPacket(BAddr local_addr, BAddr remote_addr, int is_dns, const uint8_t *data, int data_len)
{
  ASSERT(local_addr.type == BADDR_TYPE_IPV4 || local_addr.type == BADDR_TYPE_IPV6)
  ASSERT(remote_addr.type == BADDR_TYPE_IPV4 || remote_addr.type == BADDR_TYPE_IPV6)

  uint8_t flags = 0;

  if (is_dns) {
    // route to remote DNS server instead of provided address
    flags |= UDPGW_CLIENT_FLAG_DNS;
  }

  uint16_t connId = goUdpGwClient_FindConnectionByAddr(local_addr, remote_addr);
  UdpGwClient_SendData(connId, remote_addr, flags, data, data_len);
}

#endif
