/**
 * @file PacketRecvConnector.h
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
 * A {@link PacketRecvInterface} layer which allows the input to be
 * connected and disconnected on the fly.
 */

#ifndef BADVPN_FLOW_PACKETRECVCONNECTOR_H
#define BADVPN_FLOW_PACKETRECVCONNECTOR_H

#include <stdint.h>

#include <base/DebugObject.h>
#include <flow/PacketRecvInterface.h>

/**
 * A {@link PacketRecvInterface} layer which allows the input to be
 * connected and disconnected on the fly.
 */
typedef struct {
    PacketRecvInterface output;
    int output_mtu;
    int out_have;
    uint8_t *out;
    PacketRecvInterface *input;
    DebugObject d_obj;
} PacketRecvConnector;

/**
 * Initializes the object.
 * The object is initialized in not connected state.
 *
 * @param o the object
 * @param mtu maximum output packet size. Must be >=0.
 * @param pg pending group
 */
void PacketRecvConnector_Init (PacketRecvConnector *o, int mtu, BPendingGroup *pg);

/**
 * Frees the object.
 *
 * @param o the object
 */
void PacketRecvConnector_Free (PacketRecvConnector *o);

/**
 * Returns the output interface.
 * The MTU of the interface will be as in {@link PacketRecvConnector_Init}.
 *
 * @param o the object
 * @return output interface
 */
PacketRecvInterface * PacketRecvConnector_GetOutput (PacketRecvConnector *o);

/**
 * Connects input.
 * The object must be in not connected state.
 * The object enters connected state.
 *
 * @param o the object
 * @param output input to connect. Its MTU must be <= MTU specified in
 *               {@link PacketRecvConnector_Init}.
 */
void PacketRecvConnector_ConnectInput (PacketRecvConnector *o, PacketRecvInterface *input);

/**
 * Disconnects input.
 * The object must be in connected state.
 * The object enters not connected state.
 *
 * @param o the object
 */
void PacketRecvConnector_DisconnectInput (PacketRecvConnector *o);

#endif
