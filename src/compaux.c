/*
 * compaux.c - C API bridge for the compiler
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
 *  $Id: compaux.c,v 1.7 2005-05-22 11:00:22 shirok Exp $
 */

/* This file serves as a bridge to the compiler, which is implemented
   in Scheme (see compile.scm) */

#include <stdlib.h>
#define LIBGAUCHE_BODY
#include "gauche.h"
#include "gauche/vm.h"
#include "gauche/vminsn.h"
#include "gauche/class.h"
#include "gauche/code.h"
#include "gauche/builtin-syms.h"

/*
 * Syntax
 */


/*
 * Compiler Entry
 */

static ScmGloc *compile_gloc = NULL;
static ScmGloc *compile_partial_gloc = NULL;
static ScmGloc *compile_finish_gloc = NULL;
static ScmGloc *init_compiler_gloc = NULL;

static ScmInternalMutex compile_finish_mutex;

ScmObj Scm_Compile(ScmObj program, ScmObj env)
{
    return Scm_Apply(SCM_GLOC_GET(compile_gloc), SCM_LIST2(program, env));
}

ScmObj Scm_CompilePartial(ScmObj program, ScmObj env)
{
    return Scm_Apply(SCM_GLOC_GET(compile_partial_gloc),
                     SCM_LIST2(program, env));
}

void Scm_CompileFinish(ScmCompiledCode *cc)
{
    if (cc->code == NULL) {
        SCM_INTERNAL_MUTEX_LOCK(compile_finish_mutex);
        SCM_UNWIND_PROTECT {
            if (cc->code == NULL) {
                Scm_Apply(SCM_GLOC_GET(compile_finish_gloc),
                          SCM_LIST1(SCM_OBJ(cc)));
            }
        }
        SCM_WHEN_ERROR {
            SCM_INTERNAL_MUTEX_UNLOCK(compile_finish_mutex);
            SCM_NEXT_HANDLER;
        }
        SCM_END_PROTECT;
        SCM_INTERNAL_MUTEX_UNLOCK(compile_finish_mutex);
    }
}

/*-------------------------------------------------------------
 * Syntactic closure object
 */

static void synclo_print(ScmObj obj, ScmPort *port, ScmWriteContext *ctx)
{
    Scm_Printf(port, "#<syntactic-closure %S>",
               SCM_SYNTACTIC_CLOSURE(obj)->expr);
}

SCM_DEFINE_BUILTIN_CLASS_SIMPLE(Scm_SyntacticClosureClass, synclo_print);

ScmObj Scm_MakeSyntacticClosure(ScmObj env, ScmObj literals, ScmObj expr)
{
    ScmSyntacticClosure *s = SCM_NEW(ScmSyntacticClosure);
    SCM_SET_CLASS(s, SCM_CLASS_SYNTACTIC_CLOSURE);
    s->env = env;
    s->literals = literals;
    s->expr = expr;
    return SCM_OBJ(s);
}

static ScmObj synclo_env_get(ScmObj obj)
{
    return SCM_SYNTACTIC_CLOSURE(obj)->env;
}

static ScmObj synclo_literals_get(ScmObj obj)
{
    return SCM_SYNTACTIC_CLOSURE(obj)->literals;
}

static ScmObj synclo_expr_get(ScmObj obj)
{
    return SCM_SYNTACTIC_CLOSURE(obj)->expr;
}

static ScmClassStaticSlotSpec synclo_slots[] = {
    SCM_CLASS_SLOT_SPEC("env", synclo_env_get, NULL),
    SCM_CLASS_SLOT_SPEC("literals", synclo_literals_get, NULL),
    SCM_CLASS_SLOT_SPEC("expr", synclo_expr_get, NULL),
    SCM_CLASS_SLOT_SPEC_END()
};

/*-------------------------------------------------------------
 * Identifier object
 */

static void identifier_print(ScmObj obj, ScmPort *port, ScmWriteContext *ctx)
{
    ScmIdentifier *id = SCM_IDENTIFIER(obj);
    /* We may want to have an external identifier syntax, so that an
       identifier can be written out and then read back.  It will be
       convenient if we can embed a reference to other module's global
       binding directly in the program.  However, it can also breaches
       module-based sandbox implementation, so further consideration is
       required.
    */
    Scm_Printf(port, "#<identifier %S#%S>", id->module->name, id->name);
}

SCM_DEFINE_BUILTIN_CLASS_SIMPLE(Scm_IdentifierClass, identifier_print);

static ScmObj get_binding_frame(ScmObj var, ScmObj env)
{
    ScmObj frame, fp;
    SCM_FOR_EACH(frame, env) {
        if (!SCM_PAIRP(SCM_CAR(frame))) continue;
        SCM_FOR_EACH(fp, SCM_CDAR(frame)) {
            if (SCM_CAAR(fp) == var) return frame;
        }
    }
    return SCM_NIL;
}

ScmObj Scm_MakeIdentifier(ScmSymbol *name, ScmObj env)
{
    ScmIdentifier *id = SCM_NEW(ScmIdentifier);
    SCM_SET_CLASS(id, SCM_CLASS_IDENTIFIER);
    id->name = name;
    id->module = SCM_CURRENT_MODULE();
    id->env = (env == SCM_NIL)? SCM_NIL : get_binding_frame(SCM_OBJ(name), env);
    return SCM_OBJ(id);
}

/* Temporary: for the new compiler */
ScmObj Scm_MakeIdentifierWithModule(ScmSymbol *name, ScmObj env, ScmModule *mod)
{
    ScmIdentifier *id = SCM_NEW(ScmIdentifier);
    SCM_SET_CLASS(id, SCM_CLASS_IDENTIFIER);
    id->name = name;
    id->module = mod;
    id->env = env;
    return SCM_OBJ(id);
}

/* returns true if SYM has the same binding with ID in ENV. */
int Scm_IdentifierBindingEqv(ScmIdentifier *id, ScmSymbol *sym, ScmObj env)
{
    ScmObj bf = get_binding_frame(SCM_OBJ(sym), env);
    return (bf == id->env);
}

ScmObj Scm_CopyIdentifier(ScmIdentifier *orig)
{
    ScmIdentifier *id = SCM_NEW(ScmIdentifier);
    SCM_SET_CLASS(id, SCM_CLASS_IDENTIFIER);
    id->name = orig->name;
    id->module = orig->module;
    id->env = orig->env;
    return SCM_OBJ(id);
}

static ScmObj identifier_name_get(ScmObj obj)
{
    return SCM_OBJ(SCM_IDENTIFIER(obj)->name);
}

static void   identifier_name_set(ScmObj obj, ScmObj val)
{
    if (!SCM_SYMBOLP(val)) {
        Scm_Error("symbol required, but got %S", val);
    }
    SCM_IDENTIFIER(obj)->name = SCM_SYMBOL(val);
}

static ScmObj identifier_module_get(ScmObj obj)
{
    return SCM_OBJ(SCM_IDENTIFIER(obj)->module);
}

static void   identifier_module_set(ScmObj obj, ScmObj val)
{
    if (!SCM_MODULEP(val)) {
        Scm_Error("module required, but got %S", val);
    }
    SCM_IDENTIFIER(obj)->module = SCM_MODULE(val);
}

static ScmObj identifier_env_get(ScmObj obj)
{
    return SCM_IDENTIFIER(obj)->env;
}

static void   identifier_env_set(ScmObj obj, ScmObj val)
{
    if (!SCM_LISTP(val)) {
        Scm_Error("list required, but got %S", val);
    }
    SCM_IDENTIFIER(obj)->env = val;
}

static ScmClassStaticSlotSpec identifier_slots[] = {
    SCM_CLASS_SLOT_SPEC("name", identifier_name_get, identifier_name_set),
    SCM_CLASS_SLOT_SPEC("module", identifier_module_get, identifier_module_set),
    SCM_CLASS_SLOT_SPEC("env", identifier_env_get, identifier_env_set),
    { NULL }
};

/*------------------------------------------------------------------
 * Utility functions
 */

/* Lookup variable reference from the compiler environment Cenv.
   Called in Pass1.  This is the most frequently called procedure
   in the compiler, so we implement this in C.
   See compile.scm for Cenv structure.

   cenv-lookup :: Cenv, Name, LookupAs -> Var
        where Var = Lvar | Identifier | Macro

   LookupAs ::
      LEXICAL(0) - lookup only lexical bindings
    | SYNTAX(1)  - lookup lexical and syntactic bindings
    | PATTERN(2) - lookup lexical, syntactic and pattern bindings

   PERFORMANCE KLUDGE:
     - We assume the frame structure is well-formed, so skip some tests.
     - We assume 'lookupAs' and the car of each frame are small non-negative
       integers, so we directly compare them without unboxing them.
*/

ScmObj Scm_CompilerEnvLookup(ScmObj cenv, ScmObj name, ScmObj lookupAs)
{
    ScmObj frames, fp, vp;
    int name_identifier = SCM_IDENTIFIERP(name);
    SCM_ASSERT(SCM_VECTORP(cenv));
    frames = SCM_VECTOR_ELEMENT(cenv, 2);
    SCM_FOR_EACH(fp, frames) {
        ScmObj p;
        if (name_identifier && SCM_IDENTIFIER(name)->env == fp) {
            /* strip identifier if we're in the same env (kludge). */
            name = SCM_OBJ(SCM_IDENTIFIER(name)->name);
        }
        if (SCM_CAAR(fp) > lookupAs) continue; /* see PERFORMANCE KLUDGE above */
        /* We inline assq here to squeeze performance. */
        SCM_FOR_EACH(vp, SCM_CDAR(fp)) {
            if (SCM_EQ(name, SCM_CAAR(vp))) return SCM_CDAR(vp);
        }
    }
    if (SCM_SYMBOLP(name)) {
        ScmObj mod = SCM_VECTOR_ELEMENT(cenv, 1);
        SCM_ASSERT(SCM_MODULEP(mod));
        return Scm_MakeIdentifierWithModule(SCM_SYMBOL(name), SCM_NIL,
                                            SCM_MODULE(mod));
    } else {
        SCM_ASSERT(SCM_IDENTIFIERP(name));
        return name;
    }
}

/* Lookup local variable from the runtime envirnoment Renv.
 * Called in Pass3.  Moved here for efficiency.
 *
 *   renv-lookup : [[Lvar]], Lvar -> Int, Int
 *
 * Returns depth and offset of local variable frame.
 * Note that this routine is agnostic about the structure of Lvar.
 */
ScmObj Scm_RuntimeEnvLookup(ScmObj renv, ScmObj lvar)
{
    ScmObj fp, lp;
    int depth = 0;
    SCM_FOR_EACH(fp, renv) {
        int count = 1;
        SCM_FOR_EACH(lp, SCM_CAR(fp)) {
            if (SCM_EQ(SCM_CAR(lp), lvar)) {
                return Scm_Values2(SCM_MAKE_INT(depth),
                                   SCM_MAKE_INT(Scm_Length(SCM_CAR(fp))-count));
            }
            count++;
        }
        depth++;
    }
    Scm_Error("[internal error] stray local variable:", lvar);
}


/* Convert all identifiers in form into a symbol. 
   This keeps linear history to avoid entering infinite loop if
   the given form is circular; but it doens't recover the shared
   substricture. */
static ScmObj unwrap_rec(ScmObj form, ScmObj history)
{
    ScmObj newh;
    
    if (!SCM_PTRP(form)) return form;
    if (!SCM_FALSEP(Scm_Memq(form, history))) return form;
    
    if (SCM_PAIRP(form)) {
        ScmObj ca, cd;
        newh = Scm_Cons(form, history);
        ca = unwrap_rec(SCM_CAR(form), newh);
        cd = unwrap_rec(SCM_CDR(form), newh);
        if (ca == SCM_CAR(form) && cd == SCM_CDR(form)) {
            return form;
        } else {
            return Scm_Cons(ca, cd);
        }
    }
    if (SCM_IDENTIFIERP(form)) {
        return SCM_OBJ(SCM_IDENTIFIER(form)->name);
    }
    if (SCM_VECTORP(form)) {
        int i, j, len = SCM_VECTOR_SIZE(form);
        ScmObj elt, *pelt = SCM_VECTOR_ELEMENTS(form);
        newh = Scm_Cons(form, history);
        for (i=0; i<len; i++, pelt++) {
            elt = unwrap_rec(*pelt, newh);
            if (elt != *pelt) {
                ScmObj newvec = Scm_MakeVector(len, SCM_FALSE);
                pelt = SCM_VECTOR_ELEMENTS(form);
                for (j=0; j<i; j++, pelt++) {
                    SCM_VECTOR_ELEMENT(newvec, j) = *pelt;
                }
                SCM_VECTOR_ELEMENT(newvec, i) = elt;
                for (; j<len; j++, pelt++) {
                    SCM_VECTOR_ELEMENT(newvec, j) = unwrap_rec(*pelt, newh);
                }
                return newvec;
            }
        }
        return form;
    }
    return form;
}

ScmObj Scm_UnwrapSyntax(ScmObj form)
{
    return unwrap_rec(form, SCM_NIL);
}

/*===================================================================
 * Initializer
 */

#define INIT_GLOC(gloc, name, mod)                                      \
    do {                                                                \
        gloc = Scm_FindBinding(mod, SCM_SYMBOL(SCM_INTERN(name)), TRUE); \
        if (gloc == NULL) {                                             \
            Scm_Panic("no " name " procedure in gauche.internal");      \
        }                                                               \
    } while (0)

void Scm__InitCompaux(void)
{
    ScmModule *g = Scm_GaucheModule();
    ScmModule *gi = Scm_GaucheInternalModule();

    Scm_InitStaticClass(SCM_CLASS_SYNTACTIC_CLOSURE, "<syntactic-closure>", g,
                        synclo_slots, 0);
    Scm_InitStaticClass(SCM_CLASS_IDENTIFIER, "<identifier>", g,
                        identifier_slots, 0);

    SCM_INTERNAL_MUTEX_INIT(compile_finish_mutex);

    /* Grab the entry points of compile.scm */
    INIT_GLOC(init_compiler_gloc,   "init-compiler", gi);
    INIT_GLOC(compile_gloc,         "compile",       gi);
    INIT_GLOC(compile_partial_gloc, "compile-partial", gi);
    INIT_GLOC(compile_finish_gloc,  "compile-finish",  gi);

    Scm_Apply(SCM_GLOC_GET(init_compiler_gloc), SCM_NIL);
}

