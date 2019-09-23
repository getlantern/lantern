/**
 * @file SingleStreamReceiver.c
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
 */

#include <misc/debug.h>

#include "SingleStreamReceiver.h"

static void input_handler_done (SingleStreamReceiver *o, int data_len)
{
    DebugObject_Access(&o->d_obj);
    ASSERT(data_len > 0)
    ASSERT(data_len <= o->packet_len - o->pos)
    
    // update position
    o->pos += data_len;
    
    // if everything was received, notify user
    if (o->pos == o->packet_len) {
        DEBUGERROR(&o->d_err, o->handler(o->user));
        return;
    }
    
    // receive more
    StreamRecvInterface_Receiver_Recv(o->input, o->packet + o->pos, o->packet_len - o->pos);
}

void SingleStreamReceiver_Init (SingleStreamReceiver *o, uint8_t *packet, int packet_len, StreamRecvInterface *input, BPendingGroup *pg, void *user, SingleStreamReceiver_handler handler)
{
    ASSERT(packet_len > 0)
    ASSERT(handler)
    
    // init arguments
    o->packet = packet;
    o->packet_len = packet_len;
    o->input = input;
    o->user = user;
    o->handler = handler;
    
    // set position zero
    o->pos = 0;
    
    // init output
    StreamRecvInterface_Receiver_Init(o->input, (StreamRecvInterface_handler_done)input_handler_done, o);
    
    // start receiving
    StreamRecvInterface_Receiver_Recv(o->input, o->packet + o->pos, o->packet_len - o->pos);
    
    DebugError_Init(&o->d_err, pg);
    DebugObject_Init(&o->d_obj);
}

void SingleStreamReceiver_Free (SingleStreamReceiver *o)
{
    DebugObject_Free(&o->d_obj);
    DebugError_Free(&o->d_err);
}
