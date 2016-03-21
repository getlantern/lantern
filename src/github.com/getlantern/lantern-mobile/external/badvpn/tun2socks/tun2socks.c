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

#include <stdint.h>
#include <stdio.h>
#include <stddef.h>
#include <string.h>
#include <limits.h>

// PSIPHON
#include "jni.h"

#include <misc/version.h>
#include <misc/loggers_string.h>
#include <misc/loglevel.h>
#include <misc/minmax.h>
#include <misc/offset.h>
#include <misc/dead.h>
#include <misc/ipv4_proto.h>
#include <misc/ipv6_proto.h>
#include <misc/udp_proto.h>
#include <misc/byteorder.h>
#include <misc/balloc.h>
#include <misc/open_standard_streams.h>
#include <misc/read_file.h>
#include <misc/ipaddr6.h>
#include <misc/concat_strings.h>
#include <structure/LinkedList1.h>
#include <base/BLog.h>
#include <system/BReactor.h>
#include <system/BSignal.h>
#include <system/BAddr.h>
#include <system/BNetwork.h>
#include <flow/SinglePacketBuffer.h>
#include <socksclient/BSocksClient.h>
#include <tuntap/BTap.h>
#include <lwip/init.h>
#include <lwip/tcp_impl.h>
#include <lwip/netif.h>
#include <lwip/tcp.h>
#include <tun2socks/SocksUdpGwClient.h>

#ifndef BADVPN_USE_WINAPI
#include <base/BLog_syslog.h>
#endif

#include <tun2socks/tun2socks.h>

#include <generated/blog_channel_tun2socks.h>

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
struct {
    int help;
    int version;
    int logger;
    #ifndef BADVPN_USE_WINAPI
    char *logger_syslog_facility;
    char *logger_syslog_ident;
    #endif
    int loglevel;
    int loglevels[BLOG_NUM_CHANNELS];
    char *tundev;
    char *netif_ipaddr;
    char *netif_netmask;
    char *netif_ip6addr;
    char *socks_server_addr;
    char *username;
    char *password;
    char *password_file;
    int append_source_to_username;
    char *udpgw_remote_server_addr;
    int udpgw_max_connections;
    int udpgw_connection_buffer_size;
    int udpgw_transparent_dns;

    // ==== PSIPHON ====
    int tun_fd;
    int tun_mtu;
    int set_signal;
    // ==== PSIPHON ====
} options;

// TCP client
struct tcp_client {
    dead_t dead;
    dead_t dead_client;
    LinkedList1Node list_node;
    BAddr local_addr;
    BAddr remote_addr;
    struct tcp_pcb *pcb;
    int client_closed;
    uint8_t buf[TCP_WND];
    int buf_used;
    char *socks_username;
    BSocksClient socks_client;
    int socks_up;
    int socks_closed;
    StreamPassInterface *socks_send_if;
    StreamRecvInterface *socks_recv_if;
    uint8_t socks_recv_buf[CLIENT_SOCKS_RECV_BUF_SIZE];
    int socks_recv_buf_used;
    int socks_recv_buf_sent;
    int socks_recv_waiting;
    int socks_recv_tcp_pending;
};

// IP address of netif
BIPAddr netif_ipaddr;

// netmask of netif
BIPAddr netif_netmask;

// IP6 address of netif
struct ipv6_addr netif_ip6addr;

// SOCKS server address
BAddr socks_server_addr;

// allocated password file contents
uint8_t *password_file_contents;

// SOCKS authentication information
struct BSocksClient_auth_info socks_auth_info[2];
size_t socks_num_auth_info;

// remote udpgw server addr, if provided
BAddr udpgw_remote_server_addr;

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
SocksUdpGwClient udpgw_client;
int udp_mtu;

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

// ==== PSIPHON ====
static void run (void);
static void init_arguments (const char* program_name);
// ==== PSIPHON ====

static void terminate (void);
static void print_help (const char *name);
static void print_version (void);
static int parse_arguments (int argc, char *argv[]);
static int process_arguments (void);
static void signal_handler (void *unused);
static BAddr baddr_from_lwip (int is_ipv6, const ipX_addr_t *ipx_addr, uint16_t port_hostorder);
static void lwip_init_job_hadler (void *unused);
static void tcp_timer_handler (void *unused);
static void device_error_handler (void *unused);
static void device_read_handler_send (void *unused, uint8_t *data, int data_len);
static int process_device_udp_packet (uint8_t *data, int data_len);
static err_t netif_init_func (struct netif *netif);
static err_t netif_output_func (struct netif *netif, struct pbuf *p, ip_addr_t *ipaddr);
static err_t netif_output_ip6_func (struct netif *netif, struct pbuf *p, ip6_addr_t *ipaddr);
static err_t common_netif_output (struct netif *netif, struct pbuf *p);
static err_t netif_input_func (struct pbuf *p, struct netif *inp);
static void client_logfunc (struct tcp_client *client);
static void client_log (struct tcp_client *client, int level, const char *fmt, ...);
static err_t listener_accept_func (void *arg, struct tcp_pcb *newpcb, err_t err);
static void client_handle_freed_client (struct tcp_client *client);
static void client_free_client (struct tcp_client *client);
static void client_abort_client (struct tcp_client *client);
static void client_free_socks (struct tcp_client *client);
static void client_murder (struct tcp_client *client);
static void client_dealloc (struct tcp_client *client);
static void client_err_func (void *arg, err_t err);
static err_t client_recv_func (void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err);
static void client_socks_handler (struct tcp_client *client, int event);
static void client_send_to_socks (struct tcp_client *client);
static void client_socks_send_handler_done (struct tcp_client *client, int data_len);
static void client_socks_recv_initiate (struct tcp_client *client);
static void client_socks_recv_handler_done (struct tcp_client *client, int data_len);
static int client_socks_recv_send_out (struct tcp_client *client);
static err_t client_sent_func (void *arg, struct tcp_pcb *tpcb, u16_t len);
static void udpgw_client_handler_received (void *unused, BAddr local_addr, BAddr remote_addr, const uint8_t *data, int data_len);


//==== PSIPHON ====

#ifdef PSIPHON

JNIEnv* g_env = 1;

void PsiphonLog(const char *levelStr, const char *channelStr, const char *msgStr)
{
    if (!g_env)
    {
        return;
    }
    // Note: we could cache the class and method references if log is called frequently

    jstring level = (*g_env)->NewStringUTF(g_env, levelStr);
    jstring channel = (*g_env)->NewStringUTF(g_env, channelStr);
    jstring msg = (*g_env)->NewStringUTF(g_env, msgStr);

    jclass cls = (*g_env)->FindClass(g_env, "org/getlantern/lantern/android/vpn/Tun2Socks");
    jmethodID logMethod = (*g_env)->GetStaticMethodID(g_env, cls, "logTun2Socks", "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");
    (*g_env)->CallStaticVoidMethod(g_env, cls, logMethod, level, channel, msg);

    (*g_env)->DeleteLocalRef(g_env, cls);

    (*g_env)->DeleteLocalRef(g_env, level);
    (*g_env)->DeleteLocalRef(g_env, channel);
    (*g_env)->DeleteLocalRef(g_env, msg);
}

JNIEXPORT jint JNICALL Java_org_getlantern_lantern_android_vpn_Tun2Socks_runTun2Socks(
    JNIEnv* env,
    jclass cls,
    jint vpnInterfaceFileDescriptor,
    jint vpnInterfaceMTU,
    jstring vpnIpAddress,
    jstring vpnNetMask,
    jstring socksServerAddress,
    jstring udpgwServerAddress,
    jint udpgwTransparentDNS)
{
    g_env = env;

    const char* vpnIpAddressStr = (*env)->GetStringUTFChars(env, vpnIpAddress, 0);
    const char* vpnNetMaskStr = (*env)->GetStringUTFChars(env, vpnNetMask, 0);
    const char* socksServerAddressStr = (*env)->GetStringUTFChars(env, socksServerAddress, 0);
    const char* udpgwServerAddressStr = (*env)->GetStringUTFChars(env, udpgwServerAddress, 0);

    init_arguments("Psiphon tun2socks");

    options.netif_ipaddr = (char*)vpnIpAddressStr;
    options.netif_netmask = (char*)vpnNetMaskStr;
    options.socks_server_addr = (char*)socksServerAddressStr;
    options.udpgw_remote_server_addr = (char*)udpgwServerAddressStr;
    options.udpgw_transparent_dns = udpgwTransparentDNS;
    options.tun_fd = vpnInterfaceFileDescriptor;
    options.tun_mtu = vpnInterfaceMTU;
    options.set_signal = 0;
    options.loglevel = 2;

    BLog_InitPsiphon();

    run();

    (*env)->ReleaseStringUTFChars(env, vpnIpAddress, vpnIpAddressStr);
    (*env)->ReleaseStringUTFChars(env, vpnNetMask, vpnNetMaskStr);
    (*env)->ReleaseStringUTFChars(env, socksServerAddress, socksServerAddressStr);
    (*env)->ReleaseStringUTFChars(env, udpgwServerAddress, udpgwServerAddressStr);

    g_env = 0;

    // TODO: return success/error

    return 1;
}

JNIEXPORT jint JNICALL Java_org_getlantern_lantern_android_vpn_Tun2Socks_terminateTun2Socks(
    jclass cls,
    JNIEnv* env)
{
    terminate();
    return 0;
}

// from tcp_helper.c
/** Remove all pcbs on the given list. */
static void tcp_remove(struct tcp_pcb* pcb_list)
{
    struct tcp_pcb *pcb = pcb_list;
    struct tcp_pcb *pcb2;

    while(pcb != NULL)
    {
        pcb2 = pcb;
        pcb = pcb->next;
        tcp_abort(pcb2);
    }
}

//==== PSIPHON ====

#else

int main (int argc, char **argv)
{
    if (argc <= 0) {
        return 1;
    }
    
    // open standard streams
    open_standard_streams();
    
    // parse command-line arguments
    if (!parse_arguments(argc, argv)) {
        fprintf(stderr, "Failed to parse arguments\n");
        print_help(argv[0]);
        goto fail0;
    }
    
    // handle --help and --version
    if (options.help) {
        print_version();
        print_help(argv[0]);
        return 0;
    }
    if (options.version) {
        print_version();
        return 0;
    }
    
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

    run();

    return 1;
}

#endif

void run()
{
    // configure logger channels
    for (int i = 0; i < BLOG_NUM_CHANNELS; i++) {
        if (options.loglevels[i] >= 0) {
            BLog_SetChannelLoglevel(i, options.loglevels[i]);
        }
        else if (options.loglevel >= 0) {
            BLog_SetChannelLoglevel(i, options.loglevel);
        }
    }
    
    BLog(BLOG_NOTICE, "initializing "GLOBAL_PRODUCT_NAME" "PROGRAM_NAME" "GLOBAL_VERSION);
    
    // clear password contents pointer
    password_file_contents = NULL;
    
    // initialize network
    if (!BNetwork_GlobalInit()) {
        BLog(BLOG_ERROR, "BNetwork_GlobalInit failed");
        goto fail1;
    }
    
    // process arguments
    if (!process_arguments()) {
        BLog(BLOG_ERROR, "Failed to process arguments");
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
    
    // PSIPHON
    if (options.set_signal) {
        // setup signal handler
        if (!BSignal_Init(&ss, signal_handler, NULL)) {
            BLog(BLOG_ERROR, "BSignal_Init failed");
            goto fail2;
        }
    }
    
    // PSIPHON
    if (options.tun_fd) {
        // use supplied file descriptor
        if (!BTap_InitWithFD(&device, &ss, options.tun_fd, options.tun_mtu, device_error_handler, NULL, 1)) {
            BLog(BLOG_ERROR, "BTap_InitWithFD failed");
            goto fail3;
        }
    } else {
        // init TUN device
        if (!BTap_Init(&device, &ss, options.tundev, device_error_handler, NULL, 1)) {
            BLog(BLOG_ERROR, "BTap_Init failed");
            goto fail3;
        }
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
            goto fail4a;
        }
        
        // init udpgw client
        if (!SocksUdpGwClient_Init(&udpgw_client, udp_mtu, DEFAULT_UDPGW_MAX_CONNECTIONS, options.udpgw_connection_buffer_size, UDPGW_KEEPALIVE_TIME,
                                   socks_server_addr, socks_auth_info, socks_num_auth_info,
                                   udpgw_remote_server_addr, UDPGW_RECONNECT_TIME, &ss, NULL, udpgw_client_handler_received
        )) {
            BLog(BLOG_ERROR, "SocksUdpGwClient_Init failed");
            goto fail4a;
        }
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

    // ==== PSIPHON ====
    // The existing tun2socks cleanup sometimes leaves some TCP connections
    // in the TIME_WAIT state. With regular tun2socks, these will be cleaned up
    // by process termination. Since we re-init tun2socks within one process,
    // and tcp_bind_to_netif requires no TCP connections bound to the network
    // interface, we need to explicitly clean these up. Since we're also closing
    // both sources of tunneled packets (VPN fd and SOCKS sockets), there should
    // be no need to keep these TCP connections in TIME_WAIT between tun2socks
    // invocations.
    // After further testing, we found at least one TCP connection left in the
    // active list (with state SYN_RCVD). Now we're aborting the active list
    // as well, and the bound list for good measure.
    tcp_remove(tcp_bound_pcbs);
    tcp_remove(tcp_active_pcbs);
    tcp_remove(tcp_tw_pcbs);
    // ==== PSIPHON ====
    

    BReactor_RemoveTimer(&ss, &tcp_timer);
    BFree(device_write_buf);
fail5:
    BPending_Free(&lwip_init_job);
    if (options.udpgw_remote_server_addr) {
        SocksUdpGwClient_Free(&udpgw_client);
    }
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

void print_help (const char *name)
{
    printf(
        "Usage:\n"
        "    %s\n"
        "        [--help]\n"
        "        [--version]\n"
        "        [--logger <"LOGGERS_STRING">]\n"
        #ifndef BADVPN_USE_WINAPI
        "        (logger=syslog?\n"
        "            [--syslog-facility <string>]\n"
        "            [--syslog-ident <string>]\n"
        "        )\n"
        #endif
        "        [--loglevel <0-5/none/error/warning/notice/info/debug>]\n"
        "        [--channel-loglevel <channel-name> <0-5/none/error/warning/notice/info/debug>] ...\n"
        "        [--tundev <name>]\n"
        "        --netif-ipaddr <ipaddr>\n"
        "        --netif-netmask <ipnetmask>\n"
        "        --socks-server-addr <addr>\n"
        "        [--netif-ip6addr <addr>]\n"
        "        [--username <username>]\n"
        "        [--password <password>]\n"
        "        [--password-file <file>]\n"
        "        [--append-source-to-username]\n"
        "        [--udpgw-remote-server-addr <addr>]\n"
        "        [--udpgw-max-connections <number>]\n"
        "        [--udpgw-connection-buffer-size <number>]\n"
        "        [--udpgw-transparent-dns]\n"
        "Address format is a.b.c.d:port (IPv4) or [addr]:port (IPv6).\n",
        name
    );
}

void print_version (void)
{
    printf(GLOBAL_PRODUCT_NAME" "PROGRAM_NAME" "GLOBAL_VERSION"\n"GLOBAL_COPYRIGHT_NOTICE"\n");
}

//==== PSIPHON ====

void init_arguments (const char* program_name)
{
    options.help = 0;
    options.version = 0;
    options.logger = LOGGER_STDOUT;
    #ifndef BADVPN_USE_WINAPI
    options.logger_syslog_facility = "daemon";
    options.logger_syslog_ident = (char*)program_name;
    #endif
    options.loglevel = -1;
    for (int i = 0; i < BLOG_NUM_CHANNELS; i++) {
        options.loglevels[i] = -1;
    }
    options.tundev = NULL;
    options.netif_ipaddr = NULL;
    options.netif_netmask = NULL;
    options.netif_ip6addr = NULL;
    options.socks_server_addr = NULL;
    options.username = NULL;
    options.password = NULL;
    options.password_file = NULL;
    options.append_source_to_username = 0;
    options.udpgw_remote_server_addr = NULL;
    options.udpgw_max_connections = DEFAULT_UDPGW_MAX_CONNECTIONS;
    options.udpgw_connection_buffer_size = DEFAULT_UDPGW_CONNECTION_BUFFER_SIZE;
    options.udpgw_transparent_dns = 0;

    options.tun_fd = 0;
    options.set_signal = 1;
}

//==== PSIPHON ====

int parse_arguments (int argc, char *argv[])
{
    if (argc <= 0) {
        return 0;
    }
    
    // PSIPHON
    init_arguments(argv[0]);
    
    int i;
    for (i = 1; i < argc; i++) {
        char *arg = argv[i];
        if (!strcmp(arg, "--help")) {
            options.help = 1;
        }
        else if (!strcmp(arg, "--version")) {
            options.version = 1;
        }
        else if (!strcmp(arg, "--logger")) {
            if (1 >= argc - i) {
                fprintf(stderr, "%s: requires an argument\n", arg);
                return 0;
            }
            char *arg2 = argv[i + 1];
            if (!strcmp(arg2, "stdout")) {
                options.logger = LOGGER_STDOUT;
            }
            #ifndef BADVPN_USE_WINAPI
            else if (!strcmp(arg2, "syslog")) {
                options.logger = LOGGER_SYSLOG;
            }
            #endif
            else {
                fprintf(stderr, "%s: wrong argument\n", arg);
                return 0;
            }
            i++;
        }
        #ifndef BADVPN_USE_WINAPI
        else if (!strcmp(arg, "--syslog-facility")) {
            if (1 >= argc - i) {
                fprintf(stderr, "%s: requires an argument\n", arg);
                return 0;
            }
            options.logger_syslog_facility = argv[i + 1];
            i++;
        }
        else if (!strcmp(arg, "--syslog-ident")) {
            if (1 >= argc - i) {
                fprintf(stderr, "%s: requires an argument\n", arg);
                return 0;
            }
            options.logger_syslog_ident = argv[i + 1];
            i++;
        }
        #endif
        else if (!strcmp(arg, "--loglevel")) {
            if (1 >= argc - i) {
                fprintf(stderr, "%s: requires an argument\n", arg);
                return 0;
            }
            if ((options.loglevel = parse_loglevel(argv[i + 1])) < 0) {
                fprintf(stderr, "%s: wrong argument\n", arg);
                return 0;
            }
            i++;
        }
        else if (!strcmp(arg, "--channel-loglevel")) {
            if (2 >= argc - i) {
                fprintf(stderr, "%s: requires two arguments\n", arg);
                return 0;
            }
            int channel = BLogGlobal_GetChannelByName(argv[i + 1]);
            if (channel < 0) {
                fprintf(stderr, "%s: wrong channel argument\n", arg);
                return 0;
            }
            int loglevel = parse_loglevel(argv[i + 2]);
            if (loglevel < 0) {
                fprintf(stderr, "%s: wrong loglevel argument\n", arg);
                return 0;
            }
            options.loglevels[channel] = loglevel;
            i += 2;
        }
        else if (!strcmp(arg, "--tundev")) {
            if (1 >= argc - i) {
                fprintf(stderr, "%s: requires an argument\n", arg);
                return 0;
            }
            options.tundev = argv[i + 1];
            i++;
        }
        else if (!strcmp(arg, "--netif-ipaddr")) {
            if (1 >= argc - i) {
                fprintf(stderr, "%s: requires an argument\n", arg);
                return 0;
            }
            options.netif_ipaddr = argv[i + 1];
            i++;
        }
        else if (!strcmp(arg, "--netif-netmask")) {
            if (1 >= argc - i) {
                fprintf(stderr, "%s: requires an argument\n", arg);
                return 0;
            }
            options.netif_netmask = argv[i + 1];
            i++;
        }
        else if (!strcmp(arg, "--netif-ip6addr")) {
            if (1 >= argc - i) {
                fprintf(stderr, "%s: requires an argument\n", arg);
                return 0;
            }
            options.netif_ip6addr = argv[i + 1];
            i++;
        }
        else if (!strcmp(arg, "--socks-server-addr")) {
            if (1 >= argc - i) {
                fprintf(stderr, "%s: requires an argument\n", arg);
                return 0;
            }
            options.socks_server_addr = argv[i + 1];
            i++;
        }
        else if (!strcmp(arg, "--username")) {
            if (1 >= argc - i) {
                fprintf(stderr, "%s: requires an argument\n", arg);
                return 0;
            }
            options.username = argv[i + 1];
            i++;
        }
        else if (!strcmp(arg, "--password")) {
            if (1 >= argc - i) {
                fprintf(stderr, "%s: requires an argument\n", arg);
                return 0;
            }
            options.password = argv[i + 1];
            i++;
        }
        else if (!strcmp(arg, "--password-file")) {
            if (1 >= argc - i) {
                fprintf(stderr, "%s: requires an argument\n", arg);
                return 0;
            }
            options.password_file = argv[i + 1];
            i++;
        }
        else if (!strcmp(arg, "--append-source-to-username")) {
            options.append_source_to_username = 1;
        }
        else if (!strcmp(arg, "--udpgw-remote-server-addr")) {
            if (1 >= argc - i) {
                fprintf(stderr, "%s: requires an argument\n", arg);
                return 0;
            }
            options.udpgw_remote_server_addr = argv[i + 1];
            i++;
        }
        else if (!strcmp(arg, "--udpgw-max-connections")) {
            if (1 >= argc - i) {
                fprintf(stderr, "%s: requires an argument\n", arg);
                return 0;
            }
            if ((options.udpgw_max_connections = atoi(argv[i + 1])) <= 0) {
                fprintf(stderr, "%s: wrong argument\n", arg);
                return 0;
            }
            i++;
        }
        else if (!strcmp(arg, "--udpgw-connection-buffer-size")) {
            if (1 >= argc - i) {
                fprintf(stderr, "%s: requires an argument\n", arg);
                return 0;
            }
            if ((options.udpgw_connection_buffer_size = atoi(argv[i + 1])) <= 0) {
                fprintf(stderr, "%s: wrong argument\n", arg);
                return 0;
            }
            i++;
        }
        else if (!strcmp(arg, "--udpgw-transparent-dns")) {
            options.udpgw_transparent_dns = 1;
        }
        else {
            fprintf(stderr, "unknown option: %s\n", arg);
            return 0;
        }
    }
    
    if (options.help || options.version) {
        return 1;
    }
    
    if (!options.netif_ipaddr) {
        fprintf(stderr, "--netif-ipaddr is required\n");
        return 0;
    }
    
    if (!options.netif_netmask) {
        fprintf(stderr, "--netif-netmask is required\n");
        return 0;
    }
    
    if (!options.socks_server_addr) {
        fprintf(stderr, "--socks-server-addr is required\n");
        return 0;
    }
    
    if (options.username) {
        if (!options.password && !options.password_file) {
            fprintf(stderr, "username given but password not given\n");
            return 0;
        }
        
        if (options.password && options.password_file) {
            fprintf(stderr, "--password and --password-file cannot both be given\n");
            return 0;
        }
    }
    
    return 1;
}

int process_arguments (void)
{
    ASSERT(!password_file_contents)
    
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
    
    // resolve SOCKS server address
    if (!BAddr_Parse2(&socks_server_addr, options.socks_server_addr, NULL, 0, 0)) {
        BLog(BLOG_ERROR, "socks server addr: BAddr_Parse2 failed");
        return 0;
    }
    
    // add none socks authentication method
    socks_auth_info[0] = BSocksClient_auth_none();
    socks_num_auth_info = 1;
    
    // add password socks authentication method
    if (options.username) {
        const char *password;
        size_t password_len;
        if (options.password) {
            password = options.password;
            password_len = strlen(options.password);
        } else {
            if (!read_file(options.password_file, &password_file_contents, &password_len)) {
                BLog(BLOG_ERROR, "failed to read password file");
                return 0;
            }
            password = (char *)password_file_contents;
        }
        
        socks_auth_info[socks_num_auth_info++] = BSocksClient_auth_password(
            options.username, strlen(options.username),
            password, password_len
        );
    }
    
    // resolve remote udpgw server address
    if (options.udpgw_remote_server_addr) {
        if (!BAddr_Parse2(&udpgw_remote_server_addr, options.udpgw_remote_server_addr, NULL, 0, 0)) {
            BLog(BLOG_ERROR, "remote udpgw server addr: BAddr_Parse2 failed");
            return 0;
        }
    }
    
    return 1;
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
    
    // process UDP directly
    if (process_device_udp_packet(data, data_len)) {
        return;
    }
    
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

int process_device_udp_packet (uint8_t *data, int data_len)
{
    ASSERT(data_len >= 0)
    
    // do nothing if we don't have udpgw
    if (!options.udpgw_remote_server_addr) {
        goto fail;
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
                goto fail;
            }
            
            // parse IPv4 header
            struct ipv4_header ipv4_header;
            if (!ipv4_check(data, data_len, &ipv4_header, &data, &data_len)) {
                goto fail;
            }
            
            // parse UDP
            struct udp_header udp_header;
            if (!udp_check(data, data_len, &udp_header, &data, &data_len)) {
                goto fail;
            }
            
            // verify UDP checksum
            uint16_t checksum_in_packet = udp_header.checksum;
            udp_header.checksum = 0;
            uint16_t checksum_computed = udp_checksum(&udp_header, data, data_len, ipv4_header.source_address, ipv4_header.destination_address);
            if (checksum_in_packet != checksum_computed) {
                goto fail;
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
                goto fail;
            }
            
            // ignore non-UDP packets
            if (data_len < sizeof(struct ipv6_header) || data[offsetof(struct ipv6_header, next_header)] != IPV6_NEXT_UDP) {
                goto fail;
            }
            
            // parse IPv6 header
            struct ipv6_header ipv6_header;
            if (!ipv6_check(data, data_len, &ipv6_header, &data, &data_len)) {
                goto fail;
            }
            
            // parse UDP
            struct udp_header udp_header;
            if (!udp_check(data, data_len, &udp_header, &data, &data_len)) {
                goto fail;
            }
            
            // verify UDP checksum
            uint16_t checksum_in_packet = udp_header.checksum;
            udp_header.checksum = 0;
            uint16_t checksum_computed = udp_ip6_checksum(&udp_header, data, data_len, ipv6_header.source_address, ipv6_header.destination_address);
            if (checksum_in_packet != checksum_computed) {
                goto fail;
            }
            
            BLog(BLOG_INFO, "UDP/IPv6: from device %d bytes", data_len);
            
            // construct addresses
            BAddr_InitIPv6(&local_addr, ipv6_header.source_address, udp_header.source_port);
            BAddr_InitIPv6(&remote_addr, ipv6_header.destination_address, udp_header.dest_port);
            
            // TODO dns
            is_dns = 0;
        } break;
        
        default: {
            goto fail;
        } break;
    }
    
    // check payload length
    if (data_len > udp_mtu) {
        BLog(BLOG_ERROR, "packet is too large, cannot send to udpgw");
        goto fail;
    }
    
    // submit packet to udpgw
    SocksUdpGwClient_SubmitPacket(&udpgw_client, local_addr, remote_addr, is_dns, data, data_len);
    
    return 1;
    
fail:
    return 0;
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
    client->socks_username = NULL;
    
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
    
    // add source address to username if requested
    if (options.username && options.append_source_to_username) {
        char addr_str[BADDR_MAX_PRINT_LEN];
        BAddr_Print(&client->remote_addr, addr_str);
        client->socks_username = concat_strings(3, options.username, "@", addr_str);
        if (!client->socks_username) {
            goto fail1;
        }
        socks_auth_info[1].password.username = client->socks_username;
        socks_auth_info[1].password.username_len = strlen(client->socks_username);
    }
    
    // init SOCKS
    if (!BSocksClient_Init(&client->socks_client, socks_server_addr, socks_auth_info, socks_num_auth_info,
                           addr, (BSocksClient_handler)client_socks_handler, client, &ss)) {
        BLog(BLOG_ERROR, "listener accept: BSocksClient_Init failed");
        goto fail1;
    }
    
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
    
    // set SOCKS not up, not closed
    client->socks_up = 0;
    client->socks_closed = 0;
    
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
    free(client->socks_username);
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
    
    // if we have data to be sent to SOCKS and can send it, keep sending
    if (client->buf_used > 0 && !client->socks_closed) {
        client_log(client, BLOG_INFO, "waiting untill buffered data is sent to SOCKS");
    } else {
        if (!client->socks_closed) {
            client_free_socks(client);
        } else {
            client_dealloc(client);
        }
    }
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

void client_free_socks (struct tcp_client *client)
{
    ASSERT(!client->socks_closed)
    
    // stop sending to SOCKS
    if (client->socks_up) {
        // stop receiving from client
        if (!client->client_closed) {
            tcp_recv(client->pcb, NULL);
        }
    }
    
    // free SOCKS
    BSocksClient_Free(&client->socks_client);
    
    // set SOCKS closed
    client->socks_closed = 1;
    
    // if we have data to be sent to the client and we can send it, keep sending
    if (client->socks_up && (client->socks_recv_buf_used >= 0 || client->socks_recv_tcp_pending > 0) && !client->client_closed) {
        client_log(client, BLOG_INFO, "waiting until buffered data is sent to client");
    } else {
        if (!client->client_closed) {
            client_free_client(client);
        } else {
            client_dealloc(client);
        }
    }
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
    
    // free SOCKS
    if (!client->socks_closed) {
        // free SOCKS
        BSocksClient_Free(&client->socks_client);
        
        // set SOCKS closed
        client->socks_closed = 1;
    }
    
    // dealloc entry
    client_dealloc(client);
}

void client_dealloc (struct tcp_client *client)
{
    ASSERT(client->client_closed)
    ASSERT(client->socks_closed)
    
    // decrement counter
    ASSERT(num_clients > 0)
    num_clients--;
    
    // remove client entry
    LinkedList1_Remove(&tcp_clients, &client->list_node);
    
    // kill dead var
    DEAD_KILL(client->dead);
    
    // free memory
    free(client->socks_username);
    free(client);
}

void client_err_func (void *arg, err_t err)
{
    struct tcp_client *client = (struct tcp_client *)arg;
    ASSERT(!client->client_closed)
    
    client_log(client, BLOG_INFO, "client error (%d)", (int)err);
    
    // the pcb was taken care of by the caller
    client_handle_freed_client(client);
}

err_t client_recv_func (void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err)
{
    struct tcp_client *client = (struct tcp_client *)arg;
    ASSERT(!client->client_closed)
    ASSERT(err == ERR_OK) // checked in lwIP source. Otherwise, I've no idea what should
                          // be done with the pbuf in case of an error.
    
    if (!p) {
        client_log(client, BLOG_INFO, "client closed");
        client_free_client(client);
        return ERR_ABRT;
    }
    
    ASSERT(p->tot_len > 0)
    
    // check if we have enough buffer
    if (p->tot_len > sizeof(client->buf) - client->buf_used) {
        client_log(client, BLOG_ERROR, "no buffer for data !?!");
        return ERR_MEM;
    }
    
    // copy data to buffer
    ASSERT_EXECUTE(pbuf_copy_partial(p, client->buf + client->buf_used, p->tot_len, 0) == p->tot_len)
    client->buf_used += p->tot_len;
    
    // if there was nothing in the buffer before, and SOCKS is up, start send data
    if (client->buf_used == p->tot_len && client->socks_up) {
        ASSERT(!client->socks_closed) // this callback is removed when SOCKS is closed
        
        SYNC_DECL
        SYNC_FROMHERE
        client_send_to_socks(client);
        DEAD_ENTER(client->dead_client)
        SYNC_COMMIT
        DEAD_LEAVE2(client->dead_client)
        if (DEAD_KILLED) {
            return ERR_ABRT;
        }
    }
    
    // free pbuff
    pbuf_free(p);
    
    return ERR_OK;
}

void client_socks_handler (struct tcp_client *client, int event)
{
    ASSERT(!client->socks_closed)
    
    switch (event) {
        case BSOCKSCLIENT_EVENT_ERROR: {
            client_log(client, BLOG_INFO, "SOCKS error");
            
            client_free_socks(client);
        } break;
        
        case BSOCKSCLIENT_EVENT_UP: {
            ASSERT(!client->socks_up)
            
            client_log(client, BLOG_INFO, "SOCKS up");
            
            // init sending
            client->socks_send_if = BSocksClient_GetSendInterface(&client->socks_client);
            StreamPassInterface_Sender_Init(client->socks_send_if, (StreamPassInterface_handler_done)client_socks_send_handler_done, client);
            
            // init receiving
            client->socks_recv_if = BSocksClient_GetRecvInterface(&client->socks_client);
            StreamRecvInterface_Receiver_Init(client->socks_recv_if, (StreamRecvInterface_handler_done)client_socks_recv_handler_done, client);
            client->socks_recv_buf_used = -1;
            client->socks_recv_tcp_pending = 0;
            if (!client->client_closed) {
                tcp_sent(client->pcb, client_sent_func);
            }
            
            // set up
            client->socks_up = 1;
            
            // start sending data if there is any
            if (client->buf_used > 0) {
                client_send_to_socks(client);
            }
            
            // start receiving data if client is still up
            if (!client->client_closed) {
                client_socks_recv_initiate(client);
            }
        } break;
        
        case BSOCKSCLIENT_EVENT_ERROR_CLOSED: {
            ASSERT(client->socks_up)
            
            client_log(client, BLOG_INFO, "SOCKS closed");
            
            client_free_socks(client);
        } break;
        
        default:
            ASSERT(0);
    }
}

void client_send_to_socks (struct tcp_client *client)
{
    ASSERT(!client->socks_closed)
    ASSERT(client->socks_up)
    ASSERT(client->buf_used > 0)
    
    // schedule sending
    StreamPassInterface_Sender_Send(client->socks_send_if, client->buf, client->buf_used);
}

void client_socks_send_handler_done (struct tcp_client *client, int data_len)
{
    ASSERT(!client->socks_closed)
    ASSERT(client->socks_up)
    ASSERT(client->buf_used > 0)
    ASSERT(data_len > 0)
    ASSERT(data_len <= client->buf_used)
    
    // remove sent data from buffer
    memmove(client->buf, client->buf + data_len, client->buf_used - data_len);
    client->buf_used -= data_len;
    
    if (!client->client_closed) {
        // confirm sent data
        tcp_recved(client->pcb, data_len);
    }
    
    if (client->buf_used > 0) {
        // send any further data
        StreamPassInterface_Sender_Send(client->socks_send_if, client->buf, client->buf_used);
    }
    else if (client->client_closed) {
        // client was closed we've sent everything we had buffered; we're done with it
        client_log(client, BLOG_INFO, "removing after client went down");
        
        client_free_socks(client);
    }
}

void client_socks_recv_initiate (struct tcp_client *client)
{
    ASSERT(!client->client_closed)
    ASSERT(!client->socks_closed)
    ASSERT(client->socks_up)
    ASSERT(client->socks_recv_buf_used == -1)
    
    StreamRecvInterface_Receiver_Recv(client->socks_recv_if, client->socks_recv_buf, sizeof(client->socks_recv_buf));
}

void client_socks_recv_handler_done (struct tcp_client *client, int data_len)
{
    ASSERT(data_len > 0)
    ASSERT(data_len <= sizeof(client->socks_recv_buf))
    ASSERT(!client->socks_closed)
    ASSERT(client->socks_up)
    ASSERT(client->socks_recv_buf_used == -1)
    
    // if client was closed, stop receiving
    if (client->client_closed) {
        return;
    }
    
    // set amount of data in buffer
    client->socks_recv_buf_used = data_len;
    client->socks_recv_buf_sent = 0;
    client->socks_recv_waiting = 0;
    
    // send to client
    if (client_socks_recv_send_out(client) < 0) {
        return;
    }
    
    // continue receiving if needed
    if (client->socks_recv_buf_used == -1) {
        client_socks_recv_initiate(client);
    }
}

int client_socks_recv_send_out (struct tcp_client *client)
{
    ASSERT(!client->client_closed)
    ASSERT(client->socks_up)
    ASSERT(client->socks_recv_buf_used > 0)
    ASSERT(client->socks_recv_buf_sent < client->socks_recv_buf_used)
    ASSERT(!client->socks_recv_waiting)
    
    // return value -1 means tcp_abort() was done,
    // 0 means it wasn't and the client (pcb) is still up
    
    do {
        int to_write = bmin_int(client->socks_recv_buf_used - client->socks_recv_buf_sent, tcp_sndbuf(client->pcb));
        if (to_write == 0) {
            break;
        }
        
        err_t err = tcp_write(client->pcb, client->socks_recv_buf + client->socks_recv_buf_sent, to_write, TCP_WRITE_FLAG_COPY);
        if (err != ERR_OK) {
            if (err == ERR_MEM) {
                break;
            }
            
            client_log(client, BLOG_INFO, "tcp_write failed (%d)", (int)err);
            
            client_abort_client(client);
            return -1;
        }
        
        client->socks_recv_buf_sent += to_write;
        client->socks_recv_tcp_pending += to_write;
    } while (client->socks_recv_buf_sent < client->socks_recv_buf_used);
    
    // start sending now
    err_t err = tcp_output(client->pcb);
    if (err != ERR_OK) {
        client_log(client, BLOG_INFO, "tcp_output failed (%d)", (int)err);
        
        client_abort_client(client);
        return -1;
    }
    
    // more data to queue?
    if (client->socks_recv_buf_sent < client->socks_recv_buf_used) {
        if (client->socks_recv_tcp_pending == 0) {
            client_log(client, BLOG_ERROR, "can't queue data, but all data was confirmed !?!");
            
            client_abort_client(client);
            return -1;
        }
        
        // set waiting, continue in client_sent_func
        client->socks_recv_waiting = 1;
        return 0;
    }
    
    // everything was queued
    client->socks_recv_buf_used = -1;
    
    return 0;
}

err_t client_sent_func (void *arg, struct tcp_pcb *tpcb, u16_t len)
{
    struct tcp_client *client = (struct tcp_client *)arg;
    
    ASSERT(!client->client_closed)
    ASSERT(client->socks_up)
    ASSERT(len > 0)
    ASSERT(len <= client->socks_recv_tcp_pending)
    
    // decrement pending
    client->socks_recv_tcp_pending -= len;
    
    // continue queuing
    if (client->socks_recv_buf_used > 0) {
        ASSERT(client->socks_recv_waiting)
        ASSERT(client->socks_recv_buf_sent < client->socks_recv_buf_used)
        
        // set not waiting
        client->socks_recv_waiting = 0;
        
        // possibly send more data
        if (client_socks_recv_send_out(client) < 0) {
            return ERR_ABRT;
        }
        
        // we just queued some data, so it can't have been confirmed yet
        ASSERT(client->socks_recv_tcp_pending > 0)
        
        // continue receiving if needed
        if (client->socks_recv_buf_used == -1 && !client->socks_closed) {
            SYNC_DECL
            SYNC_FROMHERE
            client_socks_recv_initiate(client);
            DEAD_ENTER(client->dead_client)
            SYNC_COMMIT
            DEAD_LEAVE2(client->dead_client)
            if (DEAD_KILLED) {
                return ERR_ABRT;
            }
        }
        
        return ERR_OK;
    }
    
    // have we sent everything after SOCKS was closed?
    if (client->socks_closed && client->socks_recv_tcp_pending == 0) {
        client_log(client, BLOG_INFO, "removing after SOCKS went down");
        client_free_client(client);
        return ERR_ABRT;
    }
    
    return ERR_OK;
}

void udpgw_client_handler_received (void *unused, BAddr local_addr, BAddr remote_addr, const uint8_t *data, int data_len)
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
