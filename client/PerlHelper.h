//

#ifndef __PerlHelper_h
#define __PerlHelper_h

#define HELPER_SCRIPT	"vchat.pl"

typedef struct interpreter PerlInterpreter;

class PerlHelper
{
public:
  PerlHelper(const char *script);
  ~PerlHelper();

  void serverMessage(const char *message, const char **retval);
  void userInput(const char *input, const char **retval);

private:
  PerlInterpreter *_interpreter;

  void callStringToStringPerlFunction(const char *function, 
				      const char *arg,
				      const char **retval);
};

#endif
