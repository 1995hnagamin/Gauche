/*
 * error.c - error handling
 *
 *   Copyright (c) 2000-2004 Shiro Kawai, All rights reserved.
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
 *  $Id: error.c,v 1.61 2004-11-29 22:18:10 shirok Exp $
 */

#include <errno.h>
#include <string.h>
#define LIBGAUCHE_BODY
#include "gauche.h"
#include "gauche/class.h"
#include "gauche/exception.h"
#include "gauche/vm.h"
#include "gauche/builtin-syms.h"

static void   message_print(ScmObj obj, ScmPort *port, ScmWriteContext *ctx);
static ScmObj message_allocate(ScmClass *klass, ScmObj initargs);
static ScmObj syserror_allocate(ScmClass *klass, ScmObj initargs);
static ScmObj readerror_allocate(ScmClass *klass, ScmObj initargs);
static ScmObj porterror_allocate(ScmClass *klass, ScmObj initargs);
static ScmObj compound_allocate(ScmClass *klass, ScmObj initargs);

/* Setting up CPL is a bit tricky, since we have multiple
   inheritance case. */

#define CONDITION_CPL                           \
    SCM_CLASS_STATIC_PTR(Scm_ConditionClass),   \
    SCM_CLASS_STATIC_PTR(Scm_TopClass)

#define MESSAGE_SERIOUS_CPL \
    SCM_CLASS_STATIC_PTR(Scm_MessageConditionClass), \
    SCM_CLASS_STATIC_PTR(Scm_SeriousConditionClass), \
    CONDITION_CPL

#define ERROR_CPL \
    SCM_CLASS_STATIC_PTR(Scm_ErrorClass),        \
    MESSAGE_SERIOUS_CPL

/*-----------------------------------------------------------
 * Base conditions
 */
static ScmClass *condition_cpl[] = {
    CONDITION_CPL,
    NULL
};

SCM_DEFINE_BASE_CLASS(Scm_ConditionClass, ScmInstance,
                      NULL, NULL, NULL,
                      Scm_ObjectAllocate, SCM_CLASS_DEFAULT_CPL);
SCM_DEFINE_BASE_CLASS(Scm_MessageConditionClass, ScmMessageCondition,
                      message_print, NULL, NULL,
                      message_allocate, condition_cpl);
SCM_DEFINE_BASE_CLASS(Scm_SeriousConditionClass, ScmSeriousCondition,
                      NULL, NULL, NULL,
                      Scm_ObjectAllocate, condition_cpl);

static void message_print(ScmObj obj, ScmPort *port, ScmWriteContext *ctx)
{
    ScmClass *k = SCM_CLASS_OF(obj);
    Scm_Printf(port, "#<%A \"%30.1A\">",
               Scm__InternalClassName(k),
               SCM_ERROR_MESSAGE(obj));
}

static ScmObj message_allocate(ScmClass *klass, ScmObj initargs)
{
    ScmError *e = SCM_ALLOCATE(ScmError, klass);
    SCM_SET_CLASS(e, klass);
    e->message = SCM_FALSE;     /* would be set by initialize */
    return SCM_OBJ(e);
}

static ScmObj message_get(ScmMessageCondition *obj)
{
    return SCM_MESSAGE_CONDITION(obj)->message;
}

static void message_set(ScmMessageCondition *obj, ScmObj val)
{
    obj->message = val;
}

static ScmClassStaticSlotSpec message_slots[] = {
    SCM_CLASS_SLOT_SPEC("message", message_get, message_set),
    { NULL }
};

/*------------------------------------------------------------
 * Errors
 */

static ScmClass *error_cpl[] = {
    ERROR_CPL,
    NULL
};

static ScmClass *porterror_cpl[] = {
    SCM_CLASS_STATIC_PTR(Scm_PortErrorClass),
    SCM_CLASS_STATIC_PTR(Scm_IOErrorClass),
    ERROR_CPL,
    NULL
};
    

SCM_DEFINE_BASE_CLASS(Scm_ErrorClass, ScmError,
                      message_print, NULL, NULL, 
                      message_allocate, error_cpl+1);
SCM_DEFINE_BASE_CLASS(Scm_SystemErrorClass, ScmSystemError,
                      message_print, NULL, NULL,
                      syserror_allocate, error_cpl);
SCM_DEFINE_BASE_CLASS(Scm_ReadErrorClass, ScmReadError,
                      message_print, NULL, NULL,
                      readerror_allocate, error_cpl);
SCM_DEFINE_BASE_CLASS(Scm_IOErrorClass, ScmIOError,
                      message_print, NULL, NULL, 
                      message_allocate, error_cpl);
SCM_DEFINE_BASE_CLASS(Scm_PortErrorClass, ScmPortError,
                      message_print, NULL, NULL, 
                      porterror_allocate, porterror_cpl+1);
SCM_DEFINE_BASE_CLASS(Scm_IOReadErrorClass, ScmIOReadError,
                      message_print, NULL, NULL, 
                      porterror_allocate, porterror_cpl);
SCM_DEFINE_BASE_CLASS(Scm_IOWriteErrorClass, ScmIOWriteError,
                      message_print, NULL, NULL, 
                      porterror_allocate, porterror_cpl);
SCM_DEFINE_BASE_CLASS(Scm_IOClosedErrorClass, ScmIOClosedError,
                      message_print, NULL, NULL, 
                      porterror_allocate, porterror_cpl);
SCM_DEFINE_BASE_CLASS(Scm_IOUnitErrorClass, ScmIOUnitError,
                      message_print, NULL, NULL, 
                      porterror_allocate, porterror_cpl);

static ScmObj syserror_allocate(ScmClass *klass, ScmObj initargs)
{
    ScmSystemError *e = SCM_ALLOCATE(ScmSystemError, klass);
    SCM_SET_CLASS(e, klass);
    e->common.message = SCM_FALSE; /* set by initialize */
    e->error_number = 0;           /* set by initialize */
    return SCM_OBJ(e);
}

static ScmObj readerror_allocate(ScmClass *klass, ScmObj initargs)
{
    ScmReadError *e = SCM_ALLOCATE(ScmReadError, klass);
    SCM_SET_CLASS(e, klass);
    e->common.message = SCM_FALSE; /* set by initialize */
    e->port = NULL;                /* set by initialize */
    e->line = -1;                  /* set by initialize */
    return SCM_OBJ(e);
}

static ScmObj porterror_allocate(ScmClass *klass, ScmObj initargs)
{
    ScmPortError *e = SCM_ALLOCATE(ScmPortError, klass);
    SCM_SET_CLASS(e, klass);
    e->common.message = SCM_FALSE; /* set by initialize */
    e->port = NULL;                /* set by initialize */
    return SCM_OBJ(e);
}

static ScmObj syserror_number_get(ScmSystemError *obj)
{
    return SCM_MAKE_INT(obj->error_number);
}

static void syserror_number_set(ScmSystemError *obj, ScmObj val)
{
    if (!SCM_INTP(val)) {
        Scm_Error("small integer required, but got %S", val);
    }
    obj->error_number = SCM_INT_VALUE(val);
}

static ScmObj readerror_port_get(ScmReadError *obj)
{
    if (obj->port) return SCM_OBJ(obj->port);
    else return SCM_FALSE;
}

static void readerror_port_set(ScmReadError *obj, ScmObj val)
{
    if (SCM_IPORTP(val)) {
        obj->port = SCM_PORT(val);
    }
    else if (SCM_FALSEP(val)) {
        obj->port = NULL;
    }
    else {
        Scm_Error("input port or #f required, but got %S", val);
    }
}

static ScmObj readerror_line_get(ScmReadError *obj)
{
    return SCM_MAKE_INT(obj->line);
}

static void readerror_line_set(ScmReadError *obj, ScmObj val)
{
    if (!SCM_INTP(val)){
        Scm_Error("small integer required, but got %S", val);
    }
    obj->line = SCM_INT_VALUE(val);
}

static ScmObj readerror_dummy_get(ScmReadError *obj)
{
    return SCM_FALSE;
}

static void readerror_dummy_set(ScmReadError *obj, ScmObj val)
{
    /* nothing */
}


static ScmObj porterror_port_get(ScmPortError *obj)
{
    return obj->port? SCM_OBJ(obj->port) : SCM_FALSE;
}

static void porterror_port_set(ScmPortError *obj, ScmObj val)
{
    if (!SCM_PORTP(val) && !SCM_FALSEP(val)) {
        Scm_Error("port or #f required, but got %S", val);
    }
    obj->port = SCM_FALSEP(val)? NULL : SCM_PORT(val);
}

static ScmClassStaticSlotSpec syserror_slots[] = {
    SCM_CLASS_SLOT_SPEC("errno", syserror_number_get, syserror_number_set),
    { NULL }
};

static ScmClassStaticSlotSpec readerror_slots[] = {
    SCM_CLASS_SLOT_SPEC("port", readerror_port_get, readerror_port_set),
    SCM_CLASS_SLOT_SPEC("line", readerror_line_get, readerror_line_set),
    SCM_CLASS_SLOT_SPEC("column", readerror_dummy_get, readerror_dummy_set),
    SCM_CLASS_SLOT_SPEC("position", readerror_dummy_get, readerror_dummy_set),
    SCM_CLASS_SLOT_SPEC("span", readerror_dummy_get, readerror_dummy_set),
    { NULL }
};

static ScmClassStaticSlotSpec porterror_slots[] = {
    SCM_CLASS_SLOT_SPEC("port", porterror_port_get, porterror_port_set),
    { NULL }
};

/*------------------------------------------------------------
 * Compound conditions
 */

static ScmClass *compound_cpl[] = {
    SCM_CLASS_STATIC_PTR(Scm_CompoundConditionClass),
    SCM_CLASS_STATIC_PTR(Scm_SeriousConditionClass),
    CONDITION_CPL,
    NULL
};

SCM_DEFINE_BASE_CLASS(Scm_CompoundConditionClass, ScmCompoundCondition,
                      NULL, NULL, NULL, 
                      compound_allocate, compound_cpl+2);
SCM_DEFINE_BASE_CLASS(Scm_SeriousCompoundConditionClass, ScmCompoundCondition,
                      NULL, NULL, NULL, 
                      compound_allocate, compound_cpl);

static ScmObj compound_allocate(ScmClass *klass, ScmObj initargs)
{
    ScmCompoundCondition *e = SCM_ALLOCATE(ScmCompoundCondition, klass);
    SCM_SET_CLASS(e, klass);
    e->conditions = SCM_NIL;
    return SCM_OBJ(e);
}

ScmObj Scm_MakeCompoundCondition(ScmObj conditions)
{
    ScmObj h = SCM_NIL, t = SCM_NIL, cp, cond;
    int serious = FALSE;
    int nconds = Scm_Length(conditions);

    /* some boundary cases */
    if (nconds < 0) {
        Scm_Error("Scm_MakeCompoundCondition: list required, but got %S",
                  conditions);
    }
    if (nconds == 0) {
        return compound_allocate(SCM_CLASS_COMPOUND_CONDITION, SCM_NIL);
    }
    if (nconds == 1) {
        if (!SCM_CONDITIONP(SCM_CAR(conditions))) {
            Scm_Error("make-compound-condition: given non-condition object: %S", SCM_CAR(cp));
        }
        return SCM_CAR(conditions);
    }

    /* collect conditions and creates compound one */
    SCM_FOR_EACH(cp, conditions) {
        ScmObj c = SCM_CAR(cp);
        if (!SCM_CONDITIONP(c)) {
            Scm_Error("make-compound-condition: given non-condition object: %S", SCM_CAR(cp));
        }
        if (SCM_SERIOUS_CONDITION_P(c)) {
            serious = TRUE;
        }
        
        if (SCM_COMPOUND_CONDITION_P(c)) {
            ScmCompoundCondition *cc = SCM_COMPOUND_CONDITION(c);
            SCM_APPEND(h, t, cc->conditions);
        } else {
            SCM_APPEND1(h, t, c);
        }
    }
    cond = compound_allocate((serious?
                              SCM_CLASS_COMPOUND_CONDITION :
                              SCM_CLASS_SERIOUS_COMPOUND_CONDITION),
                             SCM_NIL);
    SCM_COMPOUND_CONDITION(cond)->conditions = h;
    return cond;
}

static ScmObj conditions_get(ScmCompoundCondition *obj)
{
    return obj->conditions;
}

static void   conditions_set(ScmCompoundCondition *obj, ScmObj conds)
{
    ScmObj cp, eobj;
    SCM_FOR_EACH(cp, conds) {
        if (!SCM_CONDITIONP(SCM_CAR(cp))) goto err;
    }
    if (!SCM_NULLP(cp)) {
      err:
        Scm_Error("conditions slot of a compound condition must be a list of conditions, but got %S", conds);
    }
    obj->conditions = conds;
}

static ScmClassStaticSlotSpec compound_slots[] = {
    SCM_CLASS_SLOT_SPEC("%conditions", conditions_get, conditions_set),
    { NULL }
};


/*
 * C-level Constructors & generic API
 */

/* actual class structure of thread exceptions are in ext/threads */
ScmObj Scm_MakeThreadException(ScmClass *klass, ScmVM *thread)
{
    ScmThreadException *e = SCM_NEW(ScmThreadException);
    SCM_SET_CLASS(e, klass);
    e->thread = thread;
    e->data = SCM_UNDEFINED;
    return SCM_OBJ(e);
}

ScmObj Scm_MakeError(ScmObj message)
{
    ScmError *e = SCM_ERROR(message_allocate(SCM_CLASS_ERROR, SCM_NIL));
    e->message = message;
    return SCM_OBJ(e);
}

ScmObj Scm_MakeSystemError(ScmObj message, int en)
{
    ScmSystemError *e =
        SCM_SYSTEM_ERROR(syserror_allocate(SCM_CLASS_SYSTEM_ERROR, SCM_NIL));
    e->common.message = message;
    e->error_number = en;
    return SCM_OBJ(e);
}

ScmObj Scm_MakeReadError(ScmObj message, ScmPort *port, int line)
{
    ScmReadError *e =
        SCM_READ_ERROR(readerror_allocate(SCM_CLASS_READ_ERROR, SCM_NIL));
    e->common.message = message;
    e->port = port;
    e->line = line;
    return SCM_OBJ(e);
}

int Scm_ConditionHasType(ScmObj c, ScmObj k)
{
    ScmObj cp;
    
    if (!SCM_CONDITIONP(c)) return FALSE;
    if (!SCM_CLASSP(k)) return FALSE;
    if (!SCM_COMPOUND_CONDITION_P(c)) return SCM_ISA(c, SCM_CLASS(k));
    SCM_FOR_EACH(cp, SCM_COMPOUND_CONDITION(c)->conditions) {
        if (SCM_ISA(SCM_CAR(cp), SCM_CLASS(k))) return TRUE;
    }
    return FALSE;
}

ScmObj Scm_ConditionMessage(ScmObj c)
{
    if (SCM_MESSAGE_CONDITION_P(c)) {
        return SCM_MESSAGE_CONDITION(c)->message;
    } else if (SCM_COMPOUND_CONDITION_P(c)) {
        ScmObj cp;
        SCM_FOR_EACH(cp, SCM_COMPOUND_CONDITION(c)->conditions) {
            if (SCM_MESSAGE_CONDITION_P(SCM_CAR(cp))) {
                return SCM_MESSAGE_CONDITION(SCM_CAR(cp))->message;
            }
        }
    }
    return SCM_FALSE;
}

/* Returns a ScmString representiong the 'type name' of the condition,
   suitable for the error message.  Because of personal preference
   and backward compatibility, I upcase the class name of the condition
   sans brackets.  If it is a composite condition, the component's typenames
   are joind with commas.
*/
ScmObj Scm_ConditionTypeName(ScmObj c)
{
    ScmObj sname;
    static SCM_DEFINE_STRING_CONST(cond_name_delim, ",", 1, 1);

    /* just a safety net */
    if (!SCM_CONDITIONP(c)) return SCM_MAKE_STR("(not a condition)");
    
    if (!SCM_COMPOUND_CONDITION_P(c)) {
        sname = Scm__InternalClassName(Scm_ClassOf(c));
    } else {
        ScmObj h = SCM_NIL, t = SCM_NIL, cp;
        SCM_FOR_EACH(cp, SCM_COMPOUND_CONDITION(c)->conditions) {
            ScmObj cc = SCM_CAR(cp);
            SCM_APPEND1(h, t, Scm__InternalClassName(Scm_ClassOf(cc)));
        }
        if (SCM_NULLP(h)) {
            /* not usual, but tolerate */
            sname = Scm__InternalClassName(Scm_ClassOf(c));
        } else {
            sname = Scm_StringJoin(h, &cond_name_delim, SCM_STRING_JOIN_INFIX);
        }
    }
    return sname;
}

/*================================================================
 * Error handling
 *
 *   The interaction with dynamic environment of VM is handled by
 *   Scm_VMThrowException() in vm.c.   These routines provide
 *   application interface.
 */

/*
 * C-like interface
 */

void Scm_Error(const char *msg, ...)
{
    ScmObj e;
    ScmVM *vm = Scm_VM();
    va_list args;

    if (SCM_VM_RUNTIME_FLAG_IS_SET(vm, SCM_ERROR_BEING_HANDLED)) {
        e = Scm_MakeError(SCM_MAKE_STR("Error occurred in error handler"));
        Scm_VMThrowException(e);
    }
    SCM_VM_RUNTIME_FLAG_SET(vm, SCM_ERROR_BEING_HANDLED);
    
    SCM_UNWIND_PROTECT {
        ScmObj ostr = Scm_MakeOutputStringPort(TRUE);
        va_start(args, msg);
        Scm_Vprintf(SCM_PORT(ostr), msg, args, TRUE);
        va_end(args);
        e = Scm_MakeError(Scm_GetOutputString(SCM_PORT(ostr)));
    }
    SCM_WHEN_ERROR {
        /* TODO: should check continuation? */
        e = Scm_MakeError(SCM_MAKE_STR("Error occurred in error handler"));
    }
    SCM_END_PROTECT;
    Scm_VMThrowException(e);
    Scm_Panic("Scm_Error: Scm_VMThrowException returned.  something wrong.");
}

/*
 * Just for convenience to report a system error.   Add strerror() message
 * after the provided message.
 */

static ScmObj get_syserrmsg(int en)
{
    ScmObj syserr;
#ifndef __MINGW32__
    syserr = SCM_MAKE_STR_COPYING(strerror(en));
#else  /*__MINGW32__*/
    LPTSTR msgbuf;
    FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER|FORMAT_MESSAGE_FROM_SYSTEM,
		  NULL,
		  en,
		  0,
		  (LPTSTR)&msgbuf,
		  0, NULL);
    syserr = SCM_MAKE_STR_COPYING(msgbuf);
    LocalFree(msgbuf);
#endif /*__MINGW32__*/
    return syserr;
}

static int get_errno(void)
{
#ifndef __MINGW32__
    return errno;
#else  /*__MINGW32__*/
    return GetLastError();
#endif /*__MINGW32__*/
}

void Scm_SysError(const char *msg, ...)
{
    ScmObj e;
    va_list args;
    int en = get_errno();
    ScmObj syserr = get_syserrmsg(en);
    
    SCM_UNWIND_PROTECT {
        ScmObj ostr = Scm_MakeOutputStringPort(TRUE);
        va_start(args, msg);
        Scm_Vprintf(SCM_PORT(ostr), msg, args, TRUE);
        va_end(args);
        SCM_PUTZ(": ", -1, ostr);
        SCM_PUTS(syserr, ostr);
        e = Scm_MakeSystemError(Scm_GetOutputString(SCM_PORT(ostr)), en);
    }
    SCM_WHEN_ERROR {
        /* TODO: should check continuation */
        e = Scm_MakeError(SCM_MAKE_STR("Error occurred in error handler"));
    }
    SCM_END_PROTECT;
    Scm_VMThrowException(e);
}

/*
 * A convenience function to throw port-relates errors.
 * It creates either one of <port-error>, <io-read-error>,
 * <io-write-error>, <io-closed-error>, or <io-unit-error>,
 * depending on the 'reason' argument being 
 * SCM_PORT_ERROR_{OTHER,INPUT,OUTPUT,CLOSED,UNIT}, respectively.
 * If errno isn't zero, it also creates a <system-error> and throws
 * a compound condition of both.
 */
void Scm_PortError(ScmPort *port, int reason, const char *msg, ...)
{
    ScmObj e, smsg, pe;
    ScmClass *peclass;
    va_list args;
    int en = get_errno();

    SCM_UNWIND_PROTECT {
        ScmObj ostr = Scm_MakeOutputStringPort(TRUE);
        va_start(args, msg);
        Scm_Vprintf(SCM_PORT(ostr), msg, args, TRUE);
        va_end(args);
        if (en != 0) {
            ScmObj syserr = get_syserrmsg(en);
            SCM_PUTZ(": ", -1, ostr);
            SCM_PUTS(syserr, ostr);
        }
        smsg = Scm_GetOutputString(SCM_PORT(ostr));

        switch (reason) {
        case SCM_PORT_ERROR_INPUT:
            peclass = SCM_CLASS_IO_READ_ERROR; break;
        case SCM_PORT_ERROR_OUTPUT:
            peclass = SCM_CLASS_IO_WRITE_ERROR; break;
        case SCM_PORT_ERROR_CLOSED:
            peclass = SCM_CLASS_IO_CLOSED_ERROR; break;
        case SCM_PORT_ERROR_UNIT:
            peclass = SCM_CLASS_IO_UNIT_ERROR; break;
        default:
            peclass = SCM_CLASS_PORT_ERROR; break;
        }
        pe = porterror_allocate(peclass, SCM_NIL);
        SCM_ERROR(pe)->message = smsg;
        SCM_PORT_ERROR(pe)->port = port;
        
        if (en != 0) {
            e = Scm_MakeCompoundCondition(SCM_LIST2(Scm_MakeSystemError(smsg, en),
                                                    pe));
        } else {
            e = pe;
        }
    }
    SCM_WHEN_ERROR {
        /* TODO: should check continuation */
        e = Scm_MakeError(SCM_MAKE_STR("Error occurred in error handler"));
    }
    SCM_END_PROTECT;
    Scm_VMThrowException(e);
}

/*
 * Just print warning
 *  TODO: customize behavior
 */

void Scm_Warn(const char *msg, ...)
{
    va_list args;
    ScmObj ostr = Scm_MakeOutputStringPort(TRUE);
    va_start(args, msg);
    Scm_Vprintf(SCM_PORT(ostr), msg, args, TRUE);
    va_end(args);
    Scm_Printf(SCM_CURERR, "WARNING: %A\n", Scm_GetOutputString(SCM_PORT(ostr)));
    Scm_Flush(SCM_CURERR);
}

/*
 * Those versions are called from Scheme.  Do not use them from C.
 */

/* SRFI-23 compatible error.
   We tolerate reason not to be a string.  It is not encouraged,
   but some third-party code may use different error API, and
   signaling an error as the first arg isn't a string would obscure
   the problem. */
ScmObj Scm_SError(ScmObj reason, ScmObj args)
{
    volatile ScmObj e;

    SCM_UNWIND_PROTECT {
        ScmObj ostr = Scm_MakeOutputStringPort(TRUE);
        ScmObj ap;
        Scm_Write(reason, ostr, SCM_WRITE_DISPLAY);
        SCM_FOR_EACH(ap, args) {
            SCM_PUTC(' ', ostr);
            Scm_Write(SCM_CAR(ap), ostr, SCM_WRITE_WRITE);
        }
        e = Scm_MakeError(Scm_GetOutputString(SCM_PORT(ostr)));
    }
    SCM_WHEN_ERROR {
        /* TODO: should check continuation? */
        e = Scm_MakeError(SCM_MAKE_STR("Error occurred in error handler"));
    }
    SCM_END_PROTECT;
    return Scm_VMThrowException(e);
}

/* format & error */
ScmObj Scm_FError(ScmObj fmt, ScmObj args)
{
    volatile ScmObj e;

    SCM_UNWIND_PROTECT {
        ScmObj ostr = Scm_MakeOutputStringPort(TRUE);
        if (SCM_STRINGP(fmt)) {
            Scm_Format(SCM_PORT(ostr), SCM_STRING(fmt), args, TRUE);
        } else {
            /* this shouldn't happen, but we tolerate it. */
            Scm_Write(fmt, ostr, SCM_WRITE_WRITE);
        }
        e = Scm_MakeError(Scm_GetOutputString(SCM_PORT(ostr)));
    }
    SCM_WHEN_ERROR {
        /* TODO: should check continuation? */
        e = Scm_MakeError(SCM_MAKE_STR("Error occurred in error handler"));
    }
    SCM_END_PROTECT;
    return Scm_VMThrowException(e);
}

/* format & warn */
void Scm_FWarn(ScmString *fmt, ScmObj args)
{
    ScmObj ostr = Scm_MakeOutputStringPort(TRUE);
    Scm_Format(SCM_PORT(ostr), fmt, args, TRUE);
    Scm_Printf(SCM_CURERR, "WARNING: %A\n", Scm_GetOutputString(SCM_PORT(ostr)));
    Scm_Flush(SCM_CURERR);
}

/*
 * Show stack trace.
 *   stacklite - return value of Scm_GetStackLite
 *   maxdepth - maximum # of stacks to be shown.
 *              0 to use the default.  -1 for unlimited.
 *   skip     - ignore this number of frames.  Useful to call this from
 *              a Scheme error handling routine, in order to skip the
 *              frames of the handler itself.
 *   offset   - add this to the frame number.  Useful to show a middle part
 *              of frames only, by combining the skip parameter.
 *   format   - SCM_STACK_TRACE_FORMAT_* enum value.  EXPERIMENTAL.
 */

#define STACK_DEPTH_LIMIT 30

#define FMT_ORIG SCM_STACK_TRACE_FORMAT_ORIGINAL
#define FMT_CC   SCM_STACK_TRACE_FORMAT_CC

#define SHOW_EXPR(depth, expr) \
    Scm_Printf(out, "%3d  %66.1S\n", (depth), Scm_UnwrapSyntax(expr));

void Scm_ShowStackTrace(ScmPort *out, ScmObj stacklite,
                        int maxdepth, int skip, int offset, int format)
{
    ScmObj cp;
    int depth = offset;
    
    if (maxdepth == 0) maxdepth = STACK_DEPTH_LIMIT;
    
    SCM_FOR_EACH(cp, stacklite) {
        if (skip-- > 0) continue;
        if (format == FMT_ORIG) {
            SHOW_EXPR(depth++, SCM_CAR(cp));
        }
        if (SCM_PAIRP(SCM_CAR(cp))) {
            ScmObj srci = Scm_PairAttrGet(SCM_PAIR(SCM_CAR(cp)),
                                          SCM_SYM_SOURCE_INFO, SCM_FALSE);
            if (SCM_PAIRP(srci) && SCM_PAIRP(SCM_CDR(srci))) {
                switch (format) {
                case FMT_ORIG:
                    Scm_Printf(out, "        At line %S of %S\n",
                               SCM_CADR(srci), SCM_CAR(srci));
                    break;
                case FMT_CC:
                    Scm_Printf(out, "%A:%S:\n",
                               SCM_CAR(srci), SCM_CADR(srci));
                    break;
                }
            } else {
                switch (format) {
                case FMT_ORIG:
                    Scm_Printf(out, "        [unknown location]\n");
                    break;
                case FMT_CC:
                    Scm_Printf(out, "[unknown location]:\n");
                    break;
                }
            }
        } else {
            Scm_Printf(out, "\n");
        }
        if (format == FMT_CC) {
            SHOW_EXPR(depth++, SCM_CAR(cp));
        }

        if (maxdepth >= 0 && depth >= STACK_DEPTH_LIMIT) {
            Scm_Printf(out, "... (more stack dump truncated)\n");
            break;
        }
    }
}

#undef SHOW_EXPR


/*
 * Default error reporter
 */

/* The default procedure to display the header of error message.
   E is a thrown condition, not necessarily an error object. */
static void Scm_PrintDefaultErrorHeading(ScmObj e, ScmPort *out)
{
    ScmObj msg;
    char *heading, *p;

    if (SCM_CONDITIONP(e)) {
        heading = Scm_GetString(SCM_STRING(Scm_ConditionTypeName(e)));
        /* TODO: considring that the class name may contain multibyte
           characters, we should use string-upcase here. */
        for (p=heading; *p; p++) {
            *p = toupper(*p);
        }
        msg = Scm_ConditionMessage(e);
        if (!SCM_FALSEP(msg)) {
            Scm_Printf(out, "*** %s: %A\n", heading, msg);
        } else {
            Scm_Printf(out, "*** %s\n", heading);
        }
    } else {
        Scm_Printf(out, "*** ERROR: unhandled exeption: %S\n", e);
    }
}

static void report_error_inner(ScmVM *vm, ScmObj e)
{
    ScmObj stack = Scm_VMGetStackLite(vm), cp;
    ScmPort *err = SCM_VM_CURRENT_ERROR_PORT(vm);
    int depth = 0;

    Scm_PrintDefaultErrorHeading(e, err);
    SCM_PUTZ("Stack Trace:\n", -1, err);
    SCM_PUTZ("_______________________________________\n", -1, err);
    Scm_ShowStackTrace(err, stack, 0, 0, 0, FMT_ORIG);
    /* NB: stderr is autoflushed by default, but in case err is replaced
       by some other port, we explicitly flush it. */
    SCM_FLUSH(err);
}

void Scm_ReportError(ScmObj e)
{
    ScmVM *vm = Scm_VM();

    if (SCM_VM_RUNTIME_FLAG_IS_SET(vm, SCM_ERROR_BEING_REPORTED)) {
        /* An _uncaptured_ error occurred during reporting an error.
           We can't proceed, for it will cause infinite loop.
           Note that it is OK for an error to occur inside the error
           reporter, as far as the error is handled by user-installed
           handler.   The user-installed handler can even invoke a
           continuation that is captured outside; the flag is reset
           in such case. 
           Be careful that it is possible that stderr is no longer
           available here (since it may be the very cause of the
           recursive error).  All we can do is to abort. */
        Scm_Abort("Unhandled error occurred during reporting an error.  Process aborted.\n");
    }

    SCM_VM_RUNTIME_FLAG_SET(vm, SCM_ERROR_BEING_REPORTED);
    SCM_UNWIND_PROTECT {
        if (SCM_PROCEDUREP(vm->defaultEscapeHandler)) {
            Scm_Apply(vm->defaultEscapeHandler, SCM_LIST1(e));
        } else {
            report_error_inner(vm, e);
        }
    }
    SCM_WHEN_ERROR {
        /* NB: this is called when a continuation captured outside is
           invoked inside the error reporter.   It may be invoked by
           the user's error handler.  */
        SCM_VM_RUNTIME_FLAG_CLEAR(vm, SCM_ERROR_BEING_REPORTED);
    }
    SCM_END_PROTECT;
    SCM_VM_RUNTIME_FLAG_CLEAR(vm, SCM_ERROR_BEING_REPORTED);
}

/*
 * Initialization
 */
extern void Scm_Init_exclib(ScmModule *module);

void Scm__InitExceptions(void)
{
    ScmModule *mod = Scm_GaucheModule();
    ScmClass *cond_meta;

    ScmObj mes_ser_supers
        = SCM_LIST2(SCM_OBJ(SCM_CLASS_MESSAGE_CONDITION),
                    SCM_OBJ(SCM_CLASS_SERIOUS_CONDITION));
    ScmObj com_ser_supers
        = SCM_LIST2(SCM_OBJ(SCM_CLASS_COMPOUND_CONDITION),
                    SCM_OBJ(SCM_CLASS_SERIOUS_CONDITION));

    Scm_InitStaticClassWithMeta(SCM_CLASS_CONDITION,
                                "<condition>",
                                mod, NULL, SCM_FALSE, NULL, 0);
    cond_meta = Scm_ClassOf(SCM_OBJ(SCM_CLASS_CONDITION));
    Scm_InitStaticClassWithMeta(SCM_CLASS_SERIOUS_CONDITION,
                                "<serious-condition>",
                                mod, cond_meta, SCM_FALSE, NULL, 0);
    Scm_InitStaticClassWithMeta(SCM_CLASS_MESSAGE_CONDITION,
                                "<message-condition>",
                                mod, cond_meta, SCM_FALSE, message_slots, 0);

    Scm_InitStaticClassWithMeta(SCM_CLASS_ERROR,
                                "<error>",
                                mod, cond_meta, mes_ser_supers,
                                message_slots, 0);
    Scm_InitStaticClassWithMeta(SCM_CLASS_SYSTEM_ERROR,
                                "<system-error>",
                                mod, cond_meta, SCM_FALSE,
                                syserror_slots, 0);
    Scm_InitStaticClassWithMeta(SCM_CLASS_READ_ERROR,
                                "<read-error>",
                                mod, cond_meta, SCM_FALSE,
                                readerror_slots, 0);
    Scm_InitStaticClassWithMeta(SCM_CLASS_IO_ERROR,
                                "<io-error>",
                                mod, cond_meta, SCM_FALSE,
                                NULL, 0);
    Scm_InitStaticClassWithMeta(SCM_CLASS_PORT_ERROR,
                                "<port-error>",
                                mod, cond_meta, SCM_FALSE,
                                porterror_slots, 0);
    Scm_InitStaticClassWithMeta(SCM_CLASS_IO_READ_ERROR,
                                "<io-read-error>",
                                mod, cond_meta, SCM_FALSE,
                                porterror_slots, 0);
    Scm_InitStaticClassWithMeta(SCM_CLASS_IO_WRITE_ERROR,
                                "<io-write-error>",
                                mod, cond_meta, SCM_FALSE,
                                porterror_slots, 0);
    Scm_InitStaticClassWithMeta(SCM_CLASS_IO_CLOSED_ERROR,
                                "<io-closed-error>",
                                mod, cond_meta, SCM_FALSE,
                                porterror_slots, 0);
    Scm_InitStaticClassWithMeta(SCM_CLASS_IO_UNIT_ERROR,
                                "<io-unit-error>",
                                mod, cond_meta, SCM_FALSE,
                                porterror_slots, 0);

    Scm_InitStaticClassWithMeta(SCM_CLASS_COMPOUND_CONDITION,
                                "<compound-condition>",
                                mod, cond_meta, SCM_FALSE,
                                compound_slots, 0);
    Scm_InitStaticClassWithMeta(SCM_CLASS_SERIOUS_COMPOUND_CONDITION,
                                "<serious-compound-condition>",
                                mod, cond_meta, com_ser_supers,
                                compound_slots, 0);

    Scm_Init_exclib(mod);
}

