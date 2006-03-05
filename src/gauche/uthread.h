/*
 * uthread.h - user level thread primitives
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
 *  $Id: uthread.h,v 1.7 2006-03-05 08:00:37 shirok Exp $
 */

#ifndef GAUCHE_UTHREAD_H
#define GAUCHE_UTHREAD_H

typedef int ScmInternalMutex;
#define SCM_INTERNAL_MUTEX_INIT(mutex)     (0)
#define SCM_INTERNAL_MUTEX_LOCK(mutex)     (0)
#define SCM_INTERNAL_MUTEX_UNLOCK(mutex)   (0)
#define SCM_INTERNAL_MUTEX_INITIALIZER     (0)

typedef int ScmInternalCond;
#define SCM_INTERNAL_COND_INIT(cond)       (0)
#define SCM_INTERNAL_COND_SIGNAL(cond)     (0)
#define SCM_INTERNAL_COND_BROADCAST(cond)  (0)
#define SCM_INTERNAL_COND_WAIT(cond, mutex) (0)
#define SCM_INTERNAL_COND_DESTROY(cond)    (0)
#define SCM_INTERNAL_COND_INITIALIZER      (0)

#endif /* GAUCHE_UTHREAD_H */
