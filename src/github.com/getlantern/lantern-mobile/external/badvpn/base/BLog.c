/**
 * @file BLog.c
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

#include <stdio.h>
#include <stddef.h>

#include "BLog.h"

#ifndef BADVPN_PLUGIN

struct _BLog_channel blog_channel_list[] = {
#include <generated/blog_channels_list.h>
};

struct _BLog_global blog_global = {
    #ifndef NDEBUG
    0
    #endif
};

#endif

// keep in sync with level numbers in BLog.h!
static char *level_names[] = { NULL, "ERROR", "WARNING", "NOTICE", "INFO", "DEBUG" };

static void stdout_log (int channel, int level, const char *msg)
{
    fprintf(stdout, "%s(%s): %s\n", level_names[level], blog_global.channels[channel].name, msg);
}

static void stderr_log (int channel, int level, const char *msg)
{
    fprintf(stderr, "%s(%s): %s\n", level_names[level], blog_global.channels[channel].name, msg);
}

static void stdout_stderr_free (void)
{
}

void BLog_InitStdout (void)
{
    BLog_Init(stdout_log, stdout_stderr_free);
}

void BLog_InitStderr (void)
{
    BLog_Init(stderr_log, stdout_stderr_free);
}

// ==== PSIPHON ====
#ifdef PSIPHON

void PsiphonLog(const char *level, const char *channel, const char *msg);

static void psiphon_log (int channel, int level, const char *msg)
{
    PsiphonLog(level_names[level], blog_global.channels[channel].name, msg);
}

static void psiphon_free (void)
{
}

void BLog_InitPsiphon (void)
{
    BLog_Init(psiphon_log, psiphon_free);
}

#endif
// ==== PSIPHON ====
