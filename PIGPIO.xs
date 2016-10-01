#include <stdlib.h>
#include <stdint.h>

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "pigpiod_if2.h"

#define PERL_NO_GET_CONTEXT

/*#include "c_methods.h"*/

/* Global Data */

/* #define MY_CXT_KEY "RPi::PIGPIO::_gpio_callbacks_mapping" XS_VERSION */

#if __GNUC__ >= 3
# define expect(expr,value)         __builtin_expect ((expr), (value))
# define INLINE                     static inline
#else
# define expect(expr,value)         (expr)
# define INLINE                     static
#endif

PerlInterpreter *mine;

HV *callbacks_table;


void callback_proxy(int pi, unsigned user_gpio, unsigned level, uint32_t tick) 
{
    PERL_SET_CONTEXT(mine);
    
    /* Get the name of the method we are suposed to call */
    char * key_name = (char *)malloc(32*sizeof(char));
    sprintf(key_name,"%d",pi);
    
    if ( ! hv_exists_ent(callbacks_table, newSVpv(key_name, strlen(key_name)), 0) ) {
        printf("Callback is not defined for PI:%d GPIO:%d . This should not have happened!",pi,user_gpio);
        return;
    }
    
    HE * hash_entry = hv_fetch_ent(callbacks_table,newSVpv(key_name, strlen(key_name)),0,0);
    
    AV * av = (AV *)SvRV( hv_iterval(callbacks_table,hash_entry) );
    
    SV **method_name_ref = av_fetch (av, user_gpio, 0);
    
    dSP;                            /* initialize stack pointer         */
    ENTER;                          /* everything created after here    */
    SAVETMPS;                       /* ...is a temporary variable.      */
    PUSHMARK(SP);                   /* remember the stack pointer       */

    /* push the arguments for the perl method onto the stack     */
    XPUSHs(sv_2mortal(newSViv(pi)));        
    XPUSHs(sv_2mortal(newSViv(user_gpio))); 
    XPUSHs(sv_2mortal(newSViv(level)));
    XPUSHs(sv_2mortal(newSVnv(tick)));

    PUTBACK;                        /* make local stack pointer global  */
    
    call_pv(SvPV_nolen(*method_name_ref), G_SCALAR);      /* call the function */    
    
    SPAGAIN;                        /* refresh stack pointer            */

    POPi;                           /* pop the return value from stack (you could print it or whatever) */

    PUTBACK;

    FREETMPS;                       /* free that return value           */
    LEAVE;                          /* ...and the XPUSHed "mortal" args */
}


/* XS interface functions */

MODULE = RPi::PIGPIO    PACKAGE = RPi::PIGPIO
    
    
BOOT:
{   
    callbacks_table = newHV();
}


# XS code
int 
xs_connect(SV *addr,SV *port)
	CODE: 
	{
        mine = Perl_get_context();
		const int pi = pigpio_start(SvPV_nolen(addr), SvPV_nolen(port));
        
        char * key_name = (char *)malloc(32*sizeof(char));
        sprintf(key_name,"%d",pi);
        
        hv_delete_ent(callbacks_table,newSVpv(key_name, strlen(key_name)), G_DISCARD, 0);
        hv_store_ent(callbacks_table,newSVpv(key_name, strlen(key_name)),newRV_noinc ((SV *)(newAV())),0);
        
		RETVAL = SvIV(newSViv(pi));
	}
	
	OUTPUT: RETVAL

void
xs_disconnect(int pi)
	CODE:
    {
		pigpio_stop(pi);

        char * key_name = (char *)malloc(32*sizeof(char));
        sprintf(key_name,"%d",pi);
        
        hv_delete_ent(callbacks_table,newSVpv(key_name, strlen(key_name)), G_DISCARD, 0);
    }

int 
xs_get_mode(int pi, unsigned gpio)
	CODE: 
	{
		const int pin_mode = get_mode(pi, gpio);
		RETVAL = pin_mode;
	}
	OUTPUT: RETVAL


int
xs_set_mode(int pi, unsigned gpio, unsigned pin_mode)
	CODE:
	{
		const int rv = set_mode(pi,gpio,pin_mode);
		RETVAL = rv;
	}
	OUTPUT: RETVAL


int
xs_gpio_write(int pi, unsigned gpio, unsigned level)
	CODE:
	{
		const int rv = gpio_write(pi,gpio,level);
		RETVAL = rv;
	}
	OUTPUT: RETVAL

int
xs_callback(int pi, unsigned user_gpio, unsigned edge, CV *callback_ref)
	CODE:
	{
        const GV *const gv = CvGV(callback_ref);
        const char *const gvname = GvNAME(gv);
        const HV *const stash = GvSTASH(gv);
        const char *const hvname = stash ? HvNAME(stash) : NULL;

        char * method_name;

        if (hvname) {
            method_name = (char *)malloc((strlen(hvname)+strlen(gvname)+3)*sizeof(char));
            strcpy(method_name,hvname);
            strcat(method_name,"::");
            strcat(method_name,gvname);
        }
        else {
            method_name = (char *)malloc((strlen(gvname)+1)*sizeof(char));
            strcat(method_name,gvname);
        }
        
        char * key_name = (char *)malloc(32*sizeof(char));
        sprintf(key_name,"%d",pi);
        
        HE * hash_entry = hv_fetch_ent(callbacks_table,newSVpv(key_name, strlen(key_name)),0,0);
        
        AV * av = (AV *)SvRV( hv_iterval(callbacks_table,hash_entry) );
        
        av_store( av, user_gpio, newSVpv(method_name, strlen(method_name)) );
        
		const int rv = callback(pi,user_gpio,edge,callback_proxy);
        
		RETVAL = rv;	
	}
	OUTPUT: RETVAL

SV *        
xs_get_callbacks_table()
        CODE:
        {
            RETVAL = sv_2mortal(newRV_inc((SV *)callbacks_table));
        }
        OUTPUT: RETVAL