//

#ifndef __Terminal_h
#define __Terminal_h

#include <iostream.h>
#include <fstream.h>

#include <map>
#include <string>

#include "TerminalCapability.h"

// Caution.  Only one terminal instance is allowed per process because
// of the way -ltermcap handles output.

using namespace std;

#ifdef lines
// some header files seem to #define this
#undef lines
#undef columns
#endif

class Terminal
: public 
#if defined(HPUX) || defined(HPUX11)
ofstream
#else
ostream
#endif
{
public:
  Terminal(const char *type);
  ~Terminal();

  int lines() const { return _lines; };
  int columns() const { return _columns; };

  const TerminalCapability &cap(const char *name);

  static TerminalCapability _untestedCapability;
  static TerminalCapability _unknownCapability;

  void put(const char *s, 
	   const TerminalCapability &attr = _unknownCapability);

  char *readline(const char *prompt = "");

  void eventHook(int (*function)());

  void getScreenSize();
  void drawStatusLine();

private:
  char *_entBuf;
  const char *_capArea;

  char *_capBuf;

  int _lines;
  int _columns;

  void setup();
  void reset();

  int _inReadline;

  map<string, TerminalCapability> _capabilities;

  map<string, string> _booleanNameMap;
  map<string, string> _numericNameMap;
  map<string, string> _stringNameMap;
};

// helper stuff for two-parameter manipulators

class twoIntManip {
  Terminal &(*_function)(Terminal &term, int a, int b);
  int _a;
  int _b;

public:
  twoIntManip(Terminal &(*function)(Terminal &term, int a, int b), int a, int b)
    : _function(function), _a(a), _b(b) {};
  friend Terminal &operator<<(Terminal &term, const twoIntManip &manip);
};


inline Terminal &
operator<<(Terminal &term, const twoIntManip &manip)
{
  return (*manip._function)(term, manip._a, manip._b);
}

extern Terminal &do_cursor_position(Terminal &term, int row, int col);

inline twoIntManip
cursor_position(int row, int col)
{
  return twoIntManip(do_cursor_position, row, col);
}

extern Terminal &do_change_scrolling_region(Terminal &term, int begin, int end);

inline twoIntManip
change_scrolling_region(int begin, int end)
{
  return twoIntManip(do_change_scrolling_region, begin, end);
}


#endif
