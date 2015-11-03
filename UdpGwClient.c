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

#ifndef _UDPGW_CLIENT_C
#define _UDPGW_CLIENT_C

#include <stdlib.h>
#include <string.h>

#include <misc/offset.h>
#include <misc/byteorder.h>
#include <misc/compare.h>
#include <base/BLog.h>

#include "tun2io.h"
#include "UdpGwClient.h"

#include <generated/blog_channel_UdpGwClient.h>

static int uint16_comparator (void *unused, uint16_t *v1, uint16_t *v2);
static int conaddr_comparator (void *unused, struct UdpGwClient_conaddr *v1, struct UdpGwClient_conaddr *v2);
static void free_server (UdpGwClient *o);
static void recv_interface_handler_send (UdpGwClient *o, uint8_t *data, int data_len);
static struct UdpGwClient_connection * reuse_connection (UdpGwClient *o, struct UdpGwClient_conaddr conaddr);

static int uint16_comparator (void *unused, uint16_t *v1, uint16_t *v2)
{
    return B_COMPARE(*v1, *v2);
}

static int conaddr_comparator (void *unused, struct UdpGwClient_conaddr *v1, struct UdpGwClient_conaddr *v2)
{
    int r = BAddr_CompareOrder(&v1->remote_addr, &v2->remote_addr);
    if (r) {
        return r;
    }
    return BAddr_CompareOrder(&v1->local_addr, &v2->local_addr);
}

static void prepare_data(uint32_t connId, BAddr remote_addr, uint8_t flags, const uint8_t *data, int data_len)
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

  goUdpGwClient_Send(connId, flags, out, out_pos);

  free(out);
}

void UdpGwClient_SubmitPacket2(UdpGwClient *o, BAddr local_addr, BAddr remote_addr, int is_dns, const uint8_t *data, int data_len)
{
    //DebugObject_Access(&o->d_obj);

    ASSERT(local_addr.type == BADDR_TYPE_IPV4 || local_addr.type == BADDR_TYPE_IPV6)
    ASSERT(remote_addr.type == BADDR_TYPE_IPV4 || remote_addr.type == BADDR_TYPE_IPV6)
    ASSERT(data_len >= 0)
    //ASSERT(data_len <= o->udp_mtu)

    uint8_t flags = 0;

    if (is_dns) {
        // route to remote DNS server instead of provided address
        //flags |= UDPGW_CLIENT_FLAG_DNS;
    }

    printf("UdpGwClient_SubmitPacket2\n");

    uint32_t connId = goUdpGwClient_FindConnectionByAddr(local_addr, remote_addr);
    prepare_data(connId, remote_addr, flags, data, data_len);

}

#endif
