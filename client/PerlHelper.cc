//

#include "PerlHelper.h"

#include <iostream.h>

extern "C"
{
#undef RETURN // perl #defines that
#include <sys/types.h>
#include <EXTERN.h>
#include <perl.h>
};


PerlHelper::PerlHelper(const char *script)
{
  _interpreter = perl_alloc();
  perl_construct(_interpreter);

  char *args[] = { "ChatHelper", (char *) script };

  if (perl_parse(_interpreter, 0, 2, args, 0)) {
    cerr << "Could not parse chat helper perl script " << script << endl;
    exit(1);
  }

  perl_run(_interpreter);
}

PerlHelper::~PerlHelper()
{
  perl_destruct(_interpreter);
  perl_free(_interpreter);
}

void
PerlHelper::callStringToStringPerlFunction(const char *function,
					   const char *arg,
					   const char **retval)
{
  // see perlembed man page for documentation

  dSP;                            /* initialize stack pointer      */
  ENTER;                          /* everything created after here */
  SAVETMPS;                       /* ...is a temporary variable.   */
  PUSHMARK(sp);                   /* remember the stack pointer    */
  XPUSHs(sv_2mortal(newSVpv((char *)arg, strlen(arg))));
                                  /* push the arg onto the stack  */
  PUTBACK;                        /* make local stack pointer global */
  perl_call_pv((char *)function,
	       G_SCALAR);         /* call the function             */
  SPAGAIN;                        /* refresh stack pointer         */

  /* pop the return value from stack */
  char *perlRv = POPp;

  int rvLen = strlen(perlRv);
//    cout << "returned from perl, length " << rvLen << " [" << perlRv << "]" << endl;
  char *tmp = new char[rvLen+1];
  tmp[rvLen] = 0;
  memcpy(tmp, perlRv, rvLen);
  *retval = tmp;
  
  PUTBACK;
  FREETMPS;                       /* free that return value        */
  LEAVE;                          /* ...and the XPUSHed "mortal" args.*/
}

void
PerlHelper::serverMessage(const char *message, const char **retval)
{
  callStringToStringPerlFunction("serverMessage", message, retval);
}

void
PerlHelper::userInput(const char *message, const char **retval)
{
  callStringToStringPerlFunction("userInput", message, retval);
}

