/**
 * @file PacketCopier.h
 * @author Ambroz Bizjak <ambrop7@gmail.com>
 * 
 * @section LICENSE
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
 * 
 * @section DESCRIPTION
 * 
 * Object which copies packets.
 */

#ifndef BADVPN_FLOW_PACKETCOPIER_H
#define BADVPN_FLOW_PACKETCOPIER_H

#include <stdint.h>

#include <flow/PacketPassInterface.h>
#include <flow/PacketRecvInterface.h>

/**
 * Object which copies packets.
 * Input is via {@link PacketPassInterface}.
 * Output is via {@link PacketRecvInterface}.
 */
typedef struct {
    DebugObject d_obj;
    PacketPassInterface input;
    PacketRecvInterface output;
    int in_len;
    uint8_t *in;
    int out_have;
    uint8_t *out;
} PacketCopier;

/**
 * Initializes the object.
 * 
 * @param o the object
 * @param mtu maximum packet size. Must be >=0.
 * @param pg pending group
 */
void PacketCopier_Init (PacketCopier *o, int mtu, BPendingGroup *pg);

/**
 * Frees the object.
 * 
 * @param o the object
 */
void PacketCopier_Free (PacketCopier *o);

/**
 * Returns the input interface.
 * The MTU of the interface will as in {@link PacketCopier_Init}.
 * The interface will support cancel functionality.
 * 
 * @return input interface
 */
PacketPassInterface * PacketCopier_GetInput (PacketCopier *o);

/**
 * Returns the output interface.
 * The MTU of the interface will be as in {@link PacketCopier_Init}.
 * 
 * @return output interface
 */
PacketRecvInterface * PacketCopier_GetOutput (PacketCopier *o);

#endif
