#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif


MODULE = Safe::Hole		PACKAGE = Safe::Hole		

void
_hole_call_sv(stashref, codesv, argvref)
    SV *	stashref
    SV *	codesv
    SV *	argvref
PPCODE:
    /*** This code is copied from Opcode::_safe_call_sv and modified ***/
    GV *gv;
    AV *av;
    I32 j,ac;

    ENTER;

    save_aptr(&PL_endav);
    PL_endav = (AV*)sv_2mortal((SV*)newAV()); /* ignore END blocks for now	*/

    save_hptr(&PL_defstash);		/* save current default stack	*/
    save_hptr(&PL_globalstash);		/* save current global stash	*/
    /* the assignment to global defstash changes our sense of 'main'	*/
    if( !SvROK(stashref) || SvTYPE(SvRV(stashref)) != SVt_PVHV )
    	croak("stash reference required");
    PL_defstash = (HV*)SvRV(stashref);
    PL_globalstash = GvHV(gv_fetchpv("CORE::GLOBAL::", GV_ADDWARN, SVt_PVHV));

    /* defstash must itself contain a main:: so we'll add that now	*/
    /* take care with the ref counts (was cause of long standing bug)	*/
    /* XXX I'm still not sure if this is right, GV_ADDWARN should warn!	*/
    gv = gv_fetchpv("main::", GV_ADDWARN, SVt_PVHV);
    sv_free((SV*)GvHV(gv));
    GvHV(gv) = (HV*)SvREFCNT_inc(PL_defstash);

    PUSHMARK(SP);
    if( argvref ) {
    	if( !SvROK(argvref) || SvTYPE(SvRV(argvref)) != SVt_PVAV )
    		croak("array reference required");
    	av = (AV*)SvRV(argvref);
    	ac = av_len(av);
    	for( j = 0; j <= ac; j++ ) {
    		XPUSHs(*(av_fetch(av,j,0)));
    	}
    }
    PUTBACK;
    perl_call_sv(codesv, GIMME);
    SPAGAIN; /* for the PUTBACK added by xsubpp */
    LEAVE;

