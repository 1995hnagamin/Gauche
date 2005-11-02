/*
 * core.c - core kernel interface
 *
 *   Copyright (c) 2000-2005 Shiro Kawai, All rights reserved.
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
 *  $Id: core.c,v 1.69 2005-11-02 06:03:26 shirok Exp $
 */

#include <stdlib.h>
#include <unistd.h>
#define LIBGAUCHE_BODY
#include "gauche.h"
#include "gauche/arch.h"
#include "gauche/paths.h"

/*
 * out-of-memory handler.  this will be called by GC.
 */

static GC_PTR oom_handler(size_t bytes)
{
    Scm_Panic("out of memory (%d).  aborting...", bytes);
    return NULL;                /* dummy */
}

/*=============================================================
 * Program initialization
 */

extern void Scm__InitModule(void);
extern void Scm__InitSymbol(void);
extern void Scm__InitKeyword(void);
extern void Scm__InitNumber(void);
extern void Scm__InitChar(void);
extern void Scm__InitClass(void);
extern void Scm__InitExceptions(void);
extern void Scm__InitPort(void);
extern void Scm__InitWrite(void);
extern void Scm__InitCompaux(void);
extern void Scm__InitMacro(void);
extern void Scm__InitLoad(void);
extern void Scm__InitProc(void);
extern void Scm__InitRegexp(void);
extern void Scm__InitRead(void);
extern void Scm__InitSignal(void);
extern void Scm__InitSystem(void);
extern void Scm__InitCode(void);
extern void Scm__InitVM(void);
extern void Scm__InitRepl(void);
extern void Scm__InitParameter(void);
extern void Scm__InitAutoloads(void);

extern void Scm_Init_stdlib(ScmModule *);
extern void Scm_Init_extlib(ScmModule *);
extern void Scm_Init_syslib(ScmModule *);
extern void Scm_Init_moplib(ScmModule *);
extern void Scm_Init_intlib(ScmModule *);

extern void Scm_Init_scmlib(void);
extern void Scm_Init_compile(void);
extern void Scm_Init_objlib(void);

static void finalizable(void);


#ifdef GAUCHE_USE_PTHREADS
/* a trick to make sure the gc thread object is linked */
static int (*ptr_pthread_create)(void) = NULL;
#endif

/*
 * Entry point of initlalizing Gauche runtime
 */
void Scm_Init(const char *signature)
{
    /* make sure the main program links the same version of libgauche */
    if (strcmp(signature, GAUCHE_SIGNATURE) != 0) {
        Scm_Panic("libgauche version mismatch: libgauche %s, expected %s",
                  GAUCHE_SIGNATURE, signature);
    }

    /* Some platforms require this.  It is harmless if GC is
       already initialized, so we call it here just in case. */
    GC_init();

    /* Set up GC parameters.  We need to call finalizers at the safe
       point of VM loop, so we disable auto finalizer invocation, and
       ask GC to call us back when finalizers are queued. */
    GC_oom_fn = oom_handler;
    GC_finalize_on_demand = TRUE;
    GC_finalizer_notifier = finalizable;

    /* Initialize components.  The order is important, for some components
       rely on the other components to be initialized. */
    Scm__InitSymbol();
    Scm__InitModule();
    Scm__InitKeyword();
    Scm__InitNumber();
    Scm__InitChar();
    Scm__InitClass();
    Scm__InitExceptions();
    Scm__InitProc();
    Scm__InitPort();
    Scm__InitWrite();
    Scm__InitCode();
    Scm__InitVM();
    Scm__InitParameter();
    Scm__InitMacro();
    Scm__InitLoad();
    Scm__InitRegexp();
    Scm__InitRead();
    Scm__InitSignal();
    Scm__InitSystem();
    Scm__InitRepl();
    
    Scm_Init_stdlib(Scm_SchemeModule());
    Scm_Init_extlib(Scm_GaucheModule());
    Scm_Init_syslib(Scm_GaucheModule());
    Scm_Init_moplib(Scm_GaucheModule());
    Scm_Init_intlib(Scm_GaucheInternalModule());

    Scm_Init_scmlib();
    Scm_Init_compile();
    Scm_Init_objlib();

    Scm__InitCompaux();

    Scm_SelectModule(Scm_GaucheModule());
    Scm__InitAutoloads();

    Scm_SelectModule(Scm_UserModule());

#ifdef GAUCHE_USE_PTHREADS
    /* a trick to make sure the gc thread object is linked */
    ptr_pthread_create = (int (*)(void))GC_pthread_create;
#endif
}

/*=============================================================
 * GC utilities
 */

/*
 * External API to register root set in dynamically loaded library.
 * Boehm GC doesn't do this automatically on some platforms.
 *
 * NB: The scheme we're using to find bss area (by Scm__bss{start|end})
 * is getting less effective, since more platforms are adopting the
 * linker that rearranges bss variables.  The extensions should not
 * keep GC_MALLOCED pointer into the bss variable.
 */
void Scm_RegisterDL(void *data_start, void *data_end,
                    void *bss_start, void *bss_end)
{
    if (data_start < data_end) {
        GC_add_roots((GC_PTR)data_start, (GC_PTR)data_end);
    }
    if (bss_start < bss_end) {
        GC_add_roots((GC_PTR)bss_start, (GC_PTR)bss_end);
    }
}

/*
 * Useful routine for debugging, to check if an object is inadvertently
 * collected.
 */
static void gc_sentinel(ScmObj obj, void *data)
{
    Scm_Printf(SCM_CURERR, "WARNING: object %s(%p) is inadvertently collected\n", (char *)data, obj);
}

void Scm_GCSentinel(void *obj, const char *name)
{
    Scm_RegisterFinalizer(SCM_OBJ(obj), gc_sentinel, (void*)name);
}


/*=============================================================
 * Finalization.  Scheme finalizers are added as NO_ORDER.
 */
void Scm_RegisterFinalizer(ScmObj z, ScmFinalizerProc finalizer, void *data)
{
    GC_finalization_proc ofn; GC_PTR ocd;
    GC_REGISTER_FINALIZER_NO_ORDER(z, (GC_finalization_proc)finalizer,
                                   data, &ofn, &ocd);
}

void Scm_UnregisterFinalizer(ScmObj z)
{
    GC_finalization_proc ofn; GC_PTR ocd;
    GC_REGISTER_FINALIZER_NO_ORDER(z, (GC_finalization_proc)NULL, NULL,
                                   &ofn, &ocd);
}

/* GC calls this back when finalizers are queued */
void finalizable(void)
{
    ScmVM *vm = Scm_VM();
    vm->queueNotEmpty |= SCM_VM_FINQ_MASK;
}

/* Called from VM loop.  Queue is not empty. */
ScmObj Scm_VMFinalizerRun(ScmVM *vm)
{
    GC_invoke_finalizers();
    vm->queueNotEmpty &= ~SCM_VM_FINQ_MASK;
    return SCM_UNDEFINED;
}

/*=============================================================
 * Program cleanup & termination
 */

struct cleanup_handler_rec {
    void (*handler)(void *data);
    void *data;
    struct cleanup_handler_rec *next;
};

static struct {
    int dirty;                  /* Flag to avoid cleaning up more than once. */
    struct cleanup_handler_rec *handlers;
} cleanup = { TRUE, NULL }; 

/* Add cleanup handler.  Returns an opaque handle, which can be
   passed to DeleteCleanupHandler. */
void *Scm_AddCleanupHandler(void (*h)(void *d), void *d)
{
    struct cleanup_handler_rec *r = SCM_NEW(struct cleanup_handler_rec);
    r->handler = h;
    r->data = d;
    r->next = cleanup.handlers;
    cleanup.handlers = r;
    return r;
}

/* Delete cleanup handler.  HANDLE should be an opaque pointer
   returned from Scm_AddCleanupHandler, but it won't complain if
   other pointer is given. */
void Scm_DeleteCleanupHandler(void *handle)
{
    struct cleanup_handler_rec *x = NULL, *y = cleanup.handlers;
    while (y) {
        if (y == handle) {
            if (x == NULL) {
                cleanup.handlers = y->next;
            } else {
                x->next = y->next;
            }
            break;
        }
    }
}

/* Scm_Cleanup and Scm_Exit
   Usually calling Scm_Exit is the easiest way to terminate Gauche
   application safely.  If the application wants to continue operation
   after shutting down the Scheme part, however, it can call Scm_Cleanup().
*/

void Scm_Exit(int code)
{
    Scm_Cleanup();
    exit(code);
}

void Scm_Cleanup(void)
{
    ScmVM *vm = Scm_VM();
    ScmObj hp;
    struct cleanup_handler_rec *ch;

    if (!cleanup.dirty) return;
    cleanup.dirty = FALSE;
    
    /* Execute pending dynamic handlers */
    SCM_FOR_EACH(hp, vm->handlers) {
        vm->handlers = SCM_CDR(hp);
        Scm_Apply(SCM_CDAR(hp), SCM_NIL);
    }

    /* Call the C-registered cleanup handlers. */
    for (ch = cleanup.handlers; ch; ch = ch->next) {
        ch->handler(ch->data);
    }
    
    /* Flush Scheme ports. */
    Scm_FlushAllPorts(TRUE);
}

void Scm_Panic(const char *msg, ...)
{
    va_list args;
    va_start(args, msg);
    vfprintf(stderr, msg, args);
    va_end(args);
    fputc('\n', stderr);
    fflush(stderr);
    _exit(1);
}

/* Use this for absolute emergency.  Newline is not attached to msg. */
void Scm_Abort(const char *msg)
{
    int size = strlen(msg);
    write(2, msg, size); /* this may return an error, but we don't care */
    _exit(1);
}

/*=============================================================
 * Inspect the configuration
 *
 */

const char *Scm_HostArchitecture(void)
{
    return GAUCHE_ARCH;
}

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

ScmObj Scm_LibraryDirectory(void)
{
    static ScmObj dir = SCM_FALSE;
    if (SCM_FALSEP(dir)) {
        char buf[PATH_MAX];
        Scm_GetLibraryDirectory(buf, PATH_MAX, Scm_Error);
        dir = Scm_MakeString(buf, -1, -1,
                             SCM_MAKSTR_COPYING|SCM_MAKSTR_IMMUTABLE);
    }
    return dir;
}

ScmObj Scm_ArchitectureDirectory(void)
{
    static ScmObj dir = SCM_FALSE;
    if (SCM_FALSEP(dir)) {
        char buf[PATH_MAX];
        Scm_GetArchitectureDirectory(buf, PATH_MAX, Scm_Error);
        dir = Scm_MakeString(buf, -1, -1,
                             SCM_MAKSTR_COPYING|SCM_MAKSTR_IMMUTABLE);
    }
    return dir;
}

ScmObj Scm_SiteLibraryDirectory(void)
{
    static ScmObj dir = SCM_FALSE;
    if (SCM_FALSEP(dir)) {
        char buf[PATH_MAX];
        Scm_GetSiteLibraryDirectory(buf, PATH_MAX, Scm_Error);
        dir = Scm_MakeString(buf, -1, -1,
                             SCM_MAKSTR_COPYING|SCM_MAKSTR_IMMUTABLE);
    }
    return dir;
}

ScmObj Scm_SiteArchitectureDirectory(void)
{
    static ScmObj dir = SCM_FALSE;
    if (SCM_FALSEP(dir)) {
        char buf[PATH_MAX];
        Scm_GetSiteArchitectureDirectory(buf, PATH_MAX, Scm_Error);
        dir = Scm_MakeString(buf, -1, -1,
                             SCM_MAKSTR_COPYING|SCM_MAKSTR_IMMUTABLE);
    }
    return dir;
}

/*
 * When creating DLL under Cygwin, we need the following dummy main()
 * or we get "undefined reference _WinMain@16" error.
 * (See cygwin FAQ, http://cygwin.com/faq/)
 */
#ifdef __CYGWIN__
int main(void)
{
    return 0;
}
#endif /*__CYGWIN__*/
