/*
 * dl_win.c - windows LoadLibrary interface
 *
 *   Copyright (c) 2000-2003 Shiro Kawai, All rights reserved.
 * 
 *   Redistribution and use in source and binary forms, with or without
 *   modification, are permitted provided that the following conditions
 *   are met:
 * 
 *   1. Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *
 *   2. Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *   3. Neither the name of the authors nor the names of its contributors
 *      may be used to endorse or promote products derived from this
 *      software without specific prior written permission.
 *
 *   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 *   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 *   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 *   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 *   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 *   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 *   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 *   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *  $Id: dl_win.c,v 1.4 2004-07-15 07:10:06 shirok Exp $
 */

/* This file is included in load.c */

/* NB: if we use MT, we need a special wrapper around LoadLibrary
   (see gc/gc_dlopen.c).   For the time being we assume MT is off
   on Windows/MinGW version. */

#include <windows.h>

static void *dl_open(const char *path)
{
    return (void*)LoadLibrary(path);
}

static const char *dl_error(void)
{
    char buf[80], *p;
    DWORD code = GetLastError();
    sprintf(buf, "error code %d", code);
    p = SCM_NEW_ATOMIC2(char *, strlen(buf)+1);
    strcpy(p, buf);
    return p;
}

static ScmDynLoadInitFn dl_sym(void *handle, const char *name)
{
    return (ScmDynLoadInitFn)GetProcAddress((HMODULE)handle, name);
}

static void dl_close(void *handle)
{
    (void)FreeLibrary((HMODULE)handle);
}
