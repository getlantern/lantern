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
#include "SocksUdpGwClient.h"

#include <misc/debug.h>
#include <base/BLog.h>

static void udpgw_handler_servererror (TunioUdpGwClient *o);
static void udpgw_handler_received (TunioUdpGwClient *o, BAddr local_addr, BAddr remote_addr, const uint8_t *data, int data_len);

static void udpgw_handler_servererror (TunioUdpGwClient *o)
{
    DebugObject_Access(&o->d_obj);
    BLog(BLOG_INFO, "udpgw_handler_servererror");
}

static void udpgw_handler_received (TunioUdpGwClient *o, BAddr local_addr, BAddr remote_addr, const uint8_t *data, int data_len)
{
    DebugObject_Access(&o->d_obj);
    BLog(BLOG_INFO, "udpgw_handler_received");
    return;
}

int TunioUdpGwClient_Init (TunioUdpGwClient *o, int udp_mtu, int max_connections, int send_buffer_size, btime_t keepalive_time,
                           BAddr remote_udpgw_addr, btime_t reconnect_time, BReactor *reactor, void *user,
                           TunioUdpGwClient_handler_received handler_received)
{
    // see asserts in UdpGwClient_Init
  ASSERT(remote_udpgw_addr.type == BADDR_TYPE_IPV4 || remote_udpgw_addr.type == BADDR_TYPE_IPV6)

  // init arguments
  o->udp_mtu = udp_mtu;
  o->remote_udpgw_addr = remote_udpgw_addr;
  o->reactor = reactor;
  o->user = user;
  o->handler_received = handler_received;

  printf("MTU WAS %d\n", udp_mtu);

  return 1;

fail0:
  return 0;
}

void TunioUdpGwClient_SubmitPacket (TunioUdpGwClient *o, BAddr local_addr, BAddr remote_addr, int is_dns, const uint8_t *data, int data_len)
{
  //DebugObject_Access(&o->d_obj);
  UdpGwClient_SubmitPacket(&o->udpgw_client, local_addr, remote_addr, is_dns, data, data_len);
}
