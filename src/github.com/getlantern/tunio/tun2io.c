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

// IP address of netif
BIPAddr netif_ipaddr;

// netmask of netif
BIPAddr netif_netmask;

// IP6 address of netif
struct ipv6_addr netif_ip6addr;

// allocated password file contents
uint8_t *password_file_contents;

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

// TCP clients
LinkedList1 tcp_clients;

// number of clients
int num_clients;

static int configure(char *tundev, char *ipaddr, char *netmask)
{
  // open standard streams
  open_standard_streams();

  // parse command-line arguments
  options.help = 0;
  options.version = 0;
  options.logger = LOGGER_STDOUT;
  #ifndef BADVPN_USE_WINAPI
  options.logger_syslog_facility = "daemon";
  options.logger_syslog_ident = "tun2io";
  #endif
  options.loglevel = -1;
  for (int i = 0; i < BLOG_NUM_CHANNELS; i++) {
		options.loglevels[i] = -1;
  }
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
				goto fail0;
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

  return setup_listener(options);

fail0:
  DebugObjectGlobal_Finish();
  return 1;
fail1:
	BFree(password_file_contents);
	BLog(BLOG_NOTICE, "exiting");
	BLog_Free();
}

static int setup_listener (options_t options)
{
	BLog(BLOG_NOTICE, "initializing "GLOBAL_PRODUCT_NAME" "PROGRAM_NAME" "GLOBAL_VERSION);

	// clear password contents pointer
	password_file_contents = NULL;

	// initialize network
	if (!BNetwork_GlobalInit()) {
		BLog(BLOG_ERROR, "BNetwork_GlobalInit failed");
		goto fail1;
	}

	// init time
	BTime_Init();

	// init reactor
	if (!BReactor_Init(&ss)) {
		BLog(BLOG_ERROR, "BReactor_Init failed");
		goto fail1;
	}

	// set not quitting
	quitting = 0;

	// setup signal handler
	if (!BSignal_Init(&ss, signal_handler, NULL)) {
		BLog(BLOG_ERROR, "BSignal_Init failed");
		goto fail2;
	}

	// init TUN device
	if (!BTap_Init(&device, &ss, options.tundev, device_error_handler, NULL, 1)) {
		BLog(BLOG_ERROR, "BTap_Init failed");
		goto fail3;
	}

	// NOTE: the order of the following is important:
	// first device writing must evaluate,
	// then lwip (so it can send packets to the device),
	// then device reading (so it can pass received packets to lwip).

	// init device reading
	PacketPassInterface_Init(&device_read_interface, BTap_GetMTU(&device), device_read_handler_send, NULL, BReactor_PendingGroup(&ss));
	if (!SinglePacketBuffer_Init(&device_read_buffer, BTap_GetOutput(&device), &device_read_interface, BReactor_PendingGroup(&ss))) {
		BLog(BLOG_ERROR, "SinglePacketBuffer_Init failed");
		goto fail4;
	}

	// init lwip init job
	BPending_Init(&lwip_init_job, BReactor_PendingGroup(&ss), lwip_init_job_hadler, NULL);
	BPending_Set(&lwip_init_job);

	// init device write buffer
	if (!(device_write_buf = (uint8_t *)BAlloc(BTap_GetMTU(&device)))) {
		BLog(BLOG_ERROR, "BAlloc failed");
		goto fail5;
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

	// init clients list
	LinkedList1_Init(&tcp_clients);

	// init number of clients
	num_clients = 0;

	// enter event loop
	BLog(BLOG_NOTICE, "entering event loop");
	BReactor_Exec(&ss);

	// free clients
	LinkedList1Node *node;
	while (node = LinkedList1_GetFirst(&tcp_clients)) {
		struct tcp_client *client = UPPER_OBJECT(node, struct tcp_client, list_node);
		client_murder(client);
	}

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
fail5:
	BPending_Free(&lwip_init_job);
fail4a:
	SinglePacketBuffer_Free(&device_read_buffer);
fail4:
	PacketPassInterface_Free(&device_read_interface);
	BTap_Free(&device);
fail3:
	BSignal_Finish();
fail2:
	BReactor_Free(&ss);
fail1:
	BFree(password_file_contents);
	BLog(BLOG_NOTICE, "exiting");
	BLog_Free();
fail0:
	DebugObjectGlobal_Finish();

	return 1;
}

void terminate (void)
{
	ASSERT(!quitting)

	BLog(BLOG_NOTICE, "tearing down");

	// set quitting
	quitting = 1;

	// exit event loop
	BReactor_Quit(&ss, 1);
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
		goto fail;
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
		goto fail;
	}

	// bind listener
	if (tcp_bind_to_netif(l, "ho0") != ERR_OK) {
		BLog(BLOG_ERROR, "tcp_bind_to_netif failed");
		tcp_close(l);
		goto fail;
	}

	// listen listener
	if (!(listener = tcp_listen(l))) {
		BLog(BLOG_ERROR, "tcp_listen failed");
		tcp_close(l);
		goto fail;
	}

	// setup listener accept handler
	tcp_accept(listener, listener_accept_func);

	if (options.netif_ip6addr) {
		struct tcp_pcb *l_ip6 = tcp_new_ip6();
		if (!l_ip6) {
			BLog(BLOG_ERROR, "tcp_new_ip6 failed");
			goto fail;
		}

		if (tcp_bind_to_netif(l_ip6, "ho0") != ERR_OK) {
			BLog(BLOG_ERROR, "tcp_bind_to_netif failed");
			tcp_close(l_ip6);
			goto fail;
		}

		if (!(listener_ip6 = tcp_listen(l_ip6))) {
			BLog(BLOG_ERROR, "tcp_listen failed");
			tcp_close(l_ip6);
			goto fail;
		}

		tcp_accept(listener_ip6, listener_accept_func);
	}

	return;

fail:
	if (!quitting) {
		terminate();
	}
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

	BLog(BLOG_DEBUG, "device: received packet");

	// accept packet
	PacketPassInterface_Done(&device_read_interface);

	// obtain pbuf
	if (data_len > UINT16_MAX) {
		BLog(BLOG_WARNING, "device read: packet too large");
		return;
	}
	struct pbuf *p = pbuf_alloc(PBUF_RAW, data_len, PBUF_POOL);
	if (!p) {
		BLog(BLOG_WARNING, "device read: pbuf_alloc failed");
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
	SYNC_DECL

	BLog(BLOG_DEBUG, "device write: send packet");

	if (quitting) {
		return ERR_OK;
	}

	// if there is just one chunk, send it directly, else via buffer
	if (!p->next) {
		if (p->len > BTap_GetMTU(&device)) {
			BLog(BLOG_WARNING, "netif func output: no space left");
			goto out;
		}

		SYNC_FROMHERE
		BTap_Send(&device, (uint8_t *)p->payload, p->len);
		SYNC_COMMIT
	} else {
		int len = 0;
		do {
			if (p->len > BTap_GetMTU(&device) - len) {
				BLog(BLOG_WARNING, "netif func output: no space left");
				goto out;
			}
			memcpy(device_write_buf + len, p->payload, p->len);
			len += p->len;
		} while (p = p->next);

		SYNC_FROMHERE
		BTap_Send(&device, device_write_buf, len);
		SYNC_COMMIT
	}

out:
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

void client_logfunc (struct tcp_client *client)
{
	char local_addr_s[BADDR_MAX_PRINT_LEN];
	BAddr_Print(&client->local_addr, local_addr_s);
	char remote_addr_s[BADDR_MAX_PRINT_LEN];
	BAddr_Print(&client->remote_addr, remote_addr_s);

	BLog_Append("%05d (%s %s): ", num_clients, local_addr_s, remote_addr_s);
}

void client_log (struct tcp_client *client, int level, const char *fmt, ...)
{
	va_list vl;
	va_start(vl, fmt);
	BLog_LogViaFuncVarArg((BLog_logfunc)client_logfunc, client, BLOG_CURRENT_CHANNEL, level, fmt, vl);
	va_end(vl);
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
		goto fail0;
  }
  //client->socks_username = NULL;

  SYNC_DECL
  SYNC_FROMHERE

  // read addresses
  client->local_addr = baddr_from_lwip(PCB_ISIPV6(newpcb), &newpcb->local_ip, newpcb->local_port);
  client->remote_addr = baddr_from_lwip(PCB_ISIPV6(newpcb), &newpcb->remote_ip, newpcb->remote_port);

  // get destination address
  BAddr addr = client->local_addr;
#ifdef OVERRIDE_DEST_ADDR
  ASSERT_FORCE(BAddr_Parse2(&addr, OVERRIDE_DEST_ADDR, NULL, 0, 1))
#endif

	// Init Go tunnel.
#ifdef CGO
	switch (client->remote_addr.type) {
		case BADDR_TYPE_IPV4:
			client->tunnel_id = goNewTunnel(client);
			printf("tunno: %d\n", client->tunnel_id);
		break;
	}
#endif

  // init dead vars
  DEAD_INIT(client->dead);
  DEAD_INIT(client->dead_client);

  // add to linked list
  LinkedList1_Append(&tcp_clients, &client->list_node);

  // increment counter
  ASSERT(num_clients >= 0)
  num_clients++;

  // set pcb
  client->pcb = newpcb;

  // set client not closed
  client->client_closed = 0;

  // setup handler argument
  tcp_arg(client->pcb, client);

  // setup handlers
  tcp_err(client->pcb, client_err_func);
  tcp_recv(client->pcb, client_recv_func);

  // setup buffer
  client->buf_used = 0;

  client_log(client, BLOG_INFO, "accepted");

  DEAD_ENTER(client->dead_client)
  SYNC_COMMIT
  DEAD_LEAVE2(client->dead_client)
  if (DEAD_KILLED) {
		return ERR_ABRT;
  }

  return ERR_OK;

fail1:
  SYNC_BREAK
  //free(client->socks_username);
  free(client);
fail0:
  return ERR_MEM;
}

void client_handle_freed_client (struct tcp_client *client)
{
	ASSERT(!client->client_closed)

	// pcb was taken care of by the caller

	// kill client dead var
	DEAD_KILL(client->dead_client);

	// set client closed
	client->client_closed = 1;

	client_dealloc(client);
}

void client_free_client (struct tcp_client *client)
{
	ASSERT(!client->client_closed)

	// remove callbacks
	tcp_err(client->pcb, NULL);
	tcp_recv(client->pcb, NULL);
	tcp_sent(client->pcb, NULL);

	// free pcb
	err_t err = tcp_close(client->pcb);
	if (err != ERR_OK) {
		client_log(client, BLOG_ERROR, "tcp_close failed (%d)", err);
		tcp_abort(client->pcb);
	}

	client_handle_freed_client(client);
}

void client_abort_client (struct tcp_client *client)
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

void client_murder (struct tcp_client *client)
{
	// free client
	if (!client->client_closed) {
		// remove callbacks
		tcp_err(client->pcb, NULL);
		tcp_recv(client->pcb, NULL);
		tcp_sent(client->pcb, NULL);

		// abort
		tcp_abort(client->pcb);

		// kill client dead var
		DEAD_KILL(client->dead_client);

		// set client closed
		client->client_closed = 1;
	}

	// dealloc entry
	client_dealloc(client);
}

void client_dealloc (struct tcp_client *client)
{
	ASSERT(client->client_closed)
	//ASSERT(client->socks_closed)

	// decrement counter
	ASSERT(num_clients > 0)
	num_clients--;

	// remove client entry
	LinkedList1_Remove(&tcp_clients, &client->list_node);

	// kill dead var
	DEAD_KILL(client->dead);

	// free memory
	free(client);
}

void client_err_func (void *arg, err_t err)
{
	struct tcp_client *client = (struct tcp_client *)arg;
	ASSERT(!client->client_closed)

	client_log(client, BLOG_INFO, "client error (%d)", (int)err);

	goTunnelDestroy(client->tunnel_id);

	// the pcb was taken care of by the caller
	client_handle_freed_client(client);
}

static err_t client_recv_func(void *arg, struct tcp_pcb *pcb, struct pbuf *p, err_t err)
{
	struct tcp_client *client = (struct tcp_client *)arg;
	ASSERT(!client->client_closed)

	// checked in lwIP source. Otherwise, I've no idea what should be done with
	// the pbuf in case of an error.
	ASSERT(err == ERR_OK)

	if (!p) {
		client_log(client, BLOG_INFO, "client closed");

		goTunnelDestroy(client->tunnel_id);

    client_free_client(client);

    return ERR_ABRT;
	}

	ASSERT(p->tot_len > 0)

	goTunnelWrite(client->tunnel_id, p->payload, p->len);

	pbuf_free(p);

  return ERR_OK;
}

static char *dump_dest_addr(struct tcp_client *client) {
	char *addr;
	addr = malloc(sizeof(char)*BADDR_MAX_ADDR_LEN);
	BAddr_Print(&client->local_addr, addr);
	return addr;
}
