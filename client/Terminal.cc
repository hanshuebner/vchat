//

#include <sys/ioctl.h>

#if defined(HPUX) || defined(HPUX11)
#include <curses.h>
#undef clear
#undef erase
#undef move
#include <sys/termio.h>
#endif
#include <string.h>
#include <term.h>
#include <errno.h>
#include <fstream.h>

#include <stdio.h>

extern "C" 
{
#include <readline/readline.h>
#include <readline/history.h>
};

#include "Terminal.h"
#include "TerminalCapability.h"

TerminalCapability Terminal::_unknownCapability;
TerminalCapability Terminal::_untestedCapability;

extern Terminal *terminal;

int
putcharTputs(
#ifdef HPUX
	     char
#else
	     int
#endif
	     c)
{
  (*terminal) << (char) c;

  return c;
}

Terminal &
do_cursor_position(Terminal &term, int row, int col)
{
  tputs(tgoto(term.cap("cursor_address").str(), row, col), 1, putcharTputs);

  return term;
}

Terminal &
do_change_scrolling_region(Terminal &term, int begin, int end)
{
#if !defined(HPUX11)
  char *buf = tparm(term.cap("change_scroll_region").str(), begin, end);
#else
  char *buf = tparm(term.cap("change_scroll_region").str(), begin, end,
				0, 0, 0, 0, 0, 0, 0);
#endif
  tputs(buf, 1, putcharTputs);

  return term;
}

Terminal &
operator <<(Terminal &term, const TerminalCapability &cap)
{
  if (cap) {
    ::tputs(cap.str(), 1, putcharTputs);
  }

  return term;
}

bool
TerminalCapability::operator ==(const TerminalCapability &tc) const
{
  return !strcmp(_cap, tc._cap);
}

void
Terminal::getScreenSize()
{
  struct winsize ws;

  _lines = tgetnum("li");
  _columns = tgetnum("co");
  if (ioctl(0, TIOCGWINSZ, &ws) < 0) {
    cerr << "ioctl(TIOCGWINSZ) failed: " << strerror(errno) << endl;
  } else {
    if (ws.ws_row && ws.ws_col) {
      _lines = ws.ws_row;
      _columns = ws.ws_col;
    }
  }
}

Terminal::Terminal(const char *type)
  :
#if defined(HPUX) || defined(HPUX11)
  ofstream("/dev/tty")
#else
  ostream(cout.ostreambuf())
#endif
{

  terminal = this; // hack - needs a fix!

#include "tcapNames.i"

  _entBuf = new char[1024];
  _capArea = _capBuf = new char[1024];
  if (tgetent(_entBuf, (char *) type) < 0) {
      cerr << "Can't get termcap entry for terminal type " << type << endl;
      exit(1);
  }
  cerr << "Terminal type is " << type << endl;

  getScreenSize();
  setup();
}

Terminal::~Terminal()
{
  reset();

  delete [] _entBuf;
  delete [] _capArea;
}

const TerminalCapability &
Terminal::cap(const char *capName) 
{
  if (_stringNameMap.find(capName) == _stringNameMap.end()) {
    cerr << "Bad terminal capability name \"" << capName << "\"" << endl;
    return _unknownCapability;
  }
  string name = _stringNameMap[capName];

//   cerr << "looking for capability \"" << capName << "\" (" << name << "): ";

  if (_capabilities[name] == _untestedCapability) {

    const char *tmp = tgetstr((char *)name.c_str(), &_capBuf);

    TerminalCapability *retval = &_unknownCapability;

    if (tmp) {
      retval = new TerminalCapability;

      retval->_cap = tmp;
    }

    _capabilities[name] = *retval;
  }

  return _capabilities[name];
}

void
Terminal::put(const char *s, 
	      const TerminalCapability &attr)
{
  if (cap("change_scroll_region") != _unknownCapability) {
    (*this) << cap("save_cursor")
	    << cursor_position(0, lines()-3)
	    << endl;
    if (attr) {
      (*this) << attr;
    }
    (*this) << s;
    if (attr) {
      (*this) << cap("exit_attribute_mode");
    }
    (*this) << cap("restore_cursor");
    flush();
  } else {
    (*this) << "\r";
    (*this) << cap("clr_eol") << s << endl;

    if (_inReadline) {
      rl_refresh_line(0, 0);
    }
  }
}

char *
Terminal::readline(const char *prompt)
{
  _inReadline = 1;
//    cout << "calling readline, prompt \"" << prompt << "\"" << endl;
  char *retval = ::readline((char *)prompt);
//    cout << "readline returned, retval = " << (void *) retval
//         << " content = \"" << retval << "\"" << endl;
  if (*retval) {
    add_history(retval);
  }
  _inReadline = 0;
  (*this) << "\r";
  (*this) << cap("clr_eol"); 
  flush();

  return retval;
}


void
Terminal::setup()
{
  if (!cap("clr_eol")) {
    cerr << "Warning, unsupported terminal" << endl;
  }

  rl_unbind_key('L'-'@'); // unbind control-l

  if (cap("change_scroll_region")) {

    drawStatusLine();
#if defined(__FreeBSD__) && __FreeBSD__ < 3
    rl_redisplay();
#endif
  }
}

void
Terminal::reset()
{
  if (cap("change_scroll_region")) {
    (*this) << change_scrolling_region(0, lines()-1)
	    << cursor_position(0, lines()-1) << endl;
    flush();
  }
}

void
Terminal::eventHook(int (*function)())
{
  rl_event_hook = function;

  if (_inReadline && !function) {
    rl_done = 1;
  }
}


void
Terminal::drawStatusLine()
{
  char *status_line = new char [columns()+1];
  sprintf(status_line, "%-*.*s", columns(), columns(),
	  "-=- VChat V0.1 -=- type .h for help -=-");


  (*this) << cap("clear_screen")
	  << change_scrolling_region(0, lines() - 3)
	  << cursor_position(0, lines()-2)
	  << cap("enter_reverse_mode");
  (*this) << status_line;
  (*this) << cap("exit_attribute_mode")
	  << cursor_position(0, lines()-1);
  flush();
  delete [] status_line;
}

