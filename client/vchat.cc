// -*- C++ -*-

// vchat.cc	Simple chat client

// $Header: /Users/hans/Downloads/cvsroot/vchat/client/vchat.cc,v 1.1 2003/04/08 15:45:28 erdgeist Exp $

// $Log: vchat.cc,v $
// Revision 1.1  2003/04/08 15:45:28  erdgeist
// Initial import
//
// Revision 1.1.1.1  2003/04/08 11:58:15  chef
// initial import
//
// Revision 1.25  2001/10/20 19:57:39  hans
// Ported to HP-UX 11i with gcc 3.0.1
//
// Revision 1.24  2001/10/16 07:09:14  hans
// Fix for HP-UX 10.20:  Handle chatserver spec parsing differently.
//
// Revision 1.23  2001/10/13 06:24:57  hans
// Fixes for HP-UX + HP ANSI C++
//
// Revision 1.22  2001/08/30 13:39:01  hans
// War nix
//
// Revision 1.21  2001/08/30 13:33:51  hans
// compile for -current
//
// Revision 1.20  2001/07/15 09:46:34  hans
// .s und .t nach dem Login geloescht.  Die Userliste ist regelmaessig so lang,
// dass motd-Announcements vollkommen untergehen.
//
// Revision 1.19  2001/01/14 21:01:22  hans
// Ported to Red Hat Linux 7.0
// Linux backup.so36.net 2.2.16-22 #1 Tue Aug 22 16:49:06 EDT 2000 i686 unknown
//
// Revision 1.18  1999/07/19 20:13:51  hans
// *** empty log message ***
//
// Revision 1.17  1999/07/19 02:37:41  hans
// Consider a message sent by the server as "server message" iff it starts
// with three digits and a space.  The previous implementation was too
// simple minded and could be exploited to confuse chatters.
//
// Revision 1.16  1999/02/18 13:40:44  hans
// CHATFORWARDER environment variable introduced.  If set, the command
// line defined in that variable is executed in the background before an
// attempt to connect to the chat server is made.  To give the forwarder
// some time to start, a four second sleep is performed before the
// connection is attempted.
//
// This is meant to be used together with ssh's port forwarding feature.
// Set CHATFORWARDER to something like "ssh -i ~/.ssh/vchat-key -p 2299
// -x -L 2323:195.21.255.248:2323 vchat@berlin.ccc.de pause", leave
// CHATSERVER undefined and your client will connect through the ssh
// tunnel.
//
// Revision 1.15  1999/02/15 19:18:32  hans
// Send .t again after log in.  .s no longer shows channel topics.
//
// Revision 1.14  1999/02/15 18:35:49  hans
// Handle CTRL-L und CTRL-C more sensible.
// Handle Window size changes (by clearing the screen and reinitializing the
// terhminal).
//
// Revision 1.13  1999/02/07 20:40:13  hans
// Kleinere Cleanups nach der STL-Konversion
//
// Revision 1.12  1999/02/06 21:42:33  hans
// Ported to STL.  Mainstream, here I am.
//
// Revision 1.11  1998/10/21 21:17:43  hans
// No longer send .t after login.  .s shows this.
//
// Revision 1.10  1998/10/21 21:13:58  hans
// Idle beep implementiert.
// Mit dem Client-Befehl %i kann der idle-beep-timer auf eine beliebige
// Anzahl von Sekunden gesetzt werden.  Der Client piept dann, wenn der
// User eine Nachricht eingegeben hat, und die naechste Nachricht, die
// vom Chatserver kommt, laenger als die eingestellte Zeit nach der
// letzten eigenen Eingabe kam.  Der Piep wird als zwei BELs mit einem
// Abstand von 0,4 Sekunden erzeugt, und ist dadurch auf manchen
// Mehrschirmkonsolen gut zu identifizieren.
//
// Man setzt den Timer sinnvollerweise auf ca. 5 Sekunden, und kann dann
// die Konsole mit dem Chat wegschalten.  Wenn dann wieder jemand was
// sagt, kriegt man es mit, ohne dass man permanent nachgucken muss.
//
// Revision 1.9  1998/07/31 23:07:46  hans
// Add userInput routine in vchat.pl.  This routine is being called to
// process the user's input before it is sent to the server.
//
// Revision 1.8  1998/07/04 16:38:17  hans
// Send .t command after log in.
//
// Revision 1.7  1998/07/04 00:13:41  hans
// Send .s command directly after log in.
//
// Revision 1.6  1998/05/30 22:29:30  hans
// Implement word wrapping of long lines.
//
// Revision 1.5  1998/04/13 21:40:39  hans
// moving to cvs
//
// Revision 1.4  1998/03/08 21:23:18  hans
// Perl added.  All server messages are now processed by the perl script
// defined by the environment variable CHATHELPERL.  The script must
// define a subroutine 'serverMessage' taking one string argument
// containing the server messages to be parsed.  It should return the
// formatted messages.  This can be used, for example, to translate the
// server messages into different languages.  In the future, vchat's API
// could be extended to allow for richer interactions with the perl
// backend.
//
// Revision 1.3  1998/03/07 22:01:11  hans
// Structural changes.
//

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/param.h>

#include <iostream.h>
#include <strstream.h>

#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <netdb.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include <signal.h>

#include <netinet/in.h>
extern "C" {
#include <readline/readline.h>
};

#include "Terminal.h"
#include "TerminalCapability.h"
#if defined(perl)
#include "PerlHelper.h"
#endif

#define DEFAULT_SERVER "localhost:2323";


// termcap variables
Terminal *terminal;

// global quit flag - set to true if termination of main loop is desired
bool quit = false;

#if defined(perl)
PerlHelper *perlHelper;
#endif

// wrapTalk 	Wrap long line into multiple shorter line.  Continuation
//		lines are indented by four spaces.

// This function is dedicated to Tim, who requested it in May 98.
// It is believed to have (non-fatal) bugs.

static void 
wrapTalk(const char *const str, ostream &os)
{
  unsigned width = terminal->columns();
  const unsigned indent = 4;
  if (width <= (indent * 2)) {
    // cerr << "|terminal too narrow|";
    os.write(str, strlen(str));
    return;	// fail.  no space to wrap
  }

  const char *left = str;
  bool firstLine = true;	// width is lowered by indent after
  				// the first line has been printed
  for (;;) {
    // skip leading spaces
    while (*left && *left == ' ') {
      left++;
    }
    // terminate if string left to print shorter than width
    if (width >= strlen(left)) {
      // cerr << "|printing rest|";
      os.write(left, strlen(left));
      // cerr << endl;
      break;
    }
    // set up right to point to the last character to print
    const char *right = left + width;
    // scan for space until beginning of string
    while (right > left) {
      if (*right-- == ' ') {
	break;
      }
    }
    if (right > left) {
      // space found -> print string up to (not including) the found space
      // cerr << "|wrapping at " << right - left << "|";
      right++;	// adjust to point to space
      os.write(left, right - left);
      // and continue at the first character after the space
      left = right + 1;
    } else {
      // no space found -> cut hard
      // cerr << "|no space found, cutting hard" << "|";
      os.write(left, width);
      left += width;
    }

    os << "\r\n";

    if (firstLine) {
      // first line is not indented.
      // cerr << "|adjust|";
      width -= indent;
      firstLine = false;
    }
    // spit out indentation
    // cerr << "|indent|";
    for (int i=0; i<indent; i++) {
      os << ' ';
    }
  } 
}   

// server socket descriptor
int server;

void
processInput(const char *buf)
{
  if (terminal->cap("change_scroll_region")) {
    terminal->put(buf, terminal->cap("enter_bold_mode"));
  }

  ostrstream os;
  os << buf << "\r\n";

  if (::write(server, os.str(), os.pcount()) != os.pcount()) {
    cerr << "could not write to server" << endl;
    quit = true;
  }
  delete [] os.str();
}

void
interpretServerData(const char *buf)
{
#if defined(perl)
  const char *retval;
  //  cerr << "sending \"" << buf << "\" to perl" << endl;
  perlHelper->serverMessage(buf, &retval);
  // cerr << "perl returned \"" << retval << "\"" << endl;
  istrstream is(retval);
#else
  istrstream is(buf);
#endif
  while (!is.eof()) {
    char code[4];
    char delim1, delim2;
    char message[1024];

    is.getline(message, sizeof message, '\r');
    is.read(&delim2, 1);

    bool isServerMessage = false;
    if ((strlen(message) >= 4)
	&& (strspn(message, "0123456789") == 3)
	&& (message[3] == ' ' || message[3] == '-')) {
	isServerMessage = true;
    }
    if (is.good()) {
      ostrstream os;
      if (isServerMessage) {
	os << "* " << (message + 4) << '\0';
      } else {
	wrapTalk(message, os);
	os << '\0';
      }
      terminal->put(os.str());
      delete [] os.str();
    }
  }
#if defined(perl)
  delete [] retval;
#endif
}

bool windowHasChanged = false;

void
noteWindowChange(int)
{
  windowHasChanged = true;
}

int
eventHook()
{
  if (windowHasChanged) {
    terminal->getScreenSize();
    terminal->drawStatusLine();
    windowHasChanged = 0;
  }

  static char buf[16384];
  static int count = 0;
  int len = ::read(server, buf + count, sizeof(buf) - count);
//    if (len != -1) {
//      cerr << "read " << len << " bytes" << endl;
//    }
  if (len <= 0) {
    if (len < 0 && errno == EAGAIN) {
      return 0;
    }
    ostrstream os;
    if (len < 0) {
      os << "* Server closed connection (" << strerror(errno) << ")" << '\0';
    } else {
      os << "* Server closed connection" << '\0';
    }
    terminal->put(os.str());
    delete [] os.str();
    quit = true;
    terminal->eventHook(0);
    return 0;
  }

//    {
//      cout << "read: >>";
//      for (int x=0; x<len; x++) {
//        if (isprint(buf[count + x])) {
//  	cout << buf[count + x];
//        } else {
//  	cout << "[" << (int) buf[count + x] << "]";
//        }
//      }
//      cout << "<<" << endl;
//      cout << "atend: " << (int) buf[len + count - 1] << endl;
//    }

  buf[len + count] = 0;
  if (buf[len + count - 1] == '\n') {
      // cout << "detect server message" << endl;
    interpretServerData(buf);
    count = 0;
  } else {
    count += len;
    if (count >= sizeof(buf)) {
      terminal->put("* Server sent bad message (no trailing nl) - exiting");
      quit = true;
      terminal->eventHook(0);
      return 0;
    }
  }

  return 0;
}

int
connectToServer(const char *serverName, short portNumber, const char *nick)
{
  if (getenv("CHATFORWARDER")) {
    ostrstream os;
    os << "Starting SSH forwarder" << '\0';
    terminal->put(os.str());
    delete [] os.str();

    ostrstream cmd;
    cmd << getenv("CHATFORWARDER") << " &" << '\0';
    system(cmd.str());
    sleep(4);
    delete [] cmd.str();
  }

  {
    ostrstream os;
    os << "Connecting to chat server on host " << serverName
	 << " port " << portNumber << '\0';
    terminal->put(os.str());
    delete [] os.str();
  }

  server = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);

  if (server < 0) {
    ostrstream os;
    os << "Could not create socket (" << strerror(errno) << ")" << '\0';
    terminal->put(os.str());
    delete [] os.str();
    return 0;
  }

  struct hostent *he = gethostbyname(serverName);

  if (!he) {
    ostrstream os;
    os << "Could not resolve server host name " << serverName << '\0';
    terminal->put(os.str());
    delete [] os.str();
    return 0;
  }

  sockaddr_in serverAddress;
  memset((char *) &serverAddress, 0, sizeof(serverAddress));

  serverAddress.sin_family = AF_INET;
  serverAddress.sin_port = htons(portNumber);
  memcpy(&serverAddress.sin_addr, he->h_addr, sizeof(struct in_addr));
  
  if (connect(server,
	      (struct sockaddr *) &serverAddress,
	      sizeof(serverAddress)) < 0) {

    ostrstream os;
    os << "Could not connect to remote: " << strerror(errno) << '\0';
    terminal->put(os.str());
    delete [] os.str();
    return 0;
  }

  int flags = fcntl(server, F_GETFL, 0);
#if defined(HPUX) || defined(HPUX11)
  fcntl(server, F_SETFL, flags | O_NONBLOCK);
#else
  fcntl(server, F_SETFL, flags | FNDELAY);
#endif

  return 1;
}

void
gracefullyExit(int = 0)
{

#if defined(perl)
  delete perlHelper;
#endif

  delete terminal;
  terminal = 0;

  cerr << endl << "Good bye." << endl << endl;
  sleep(1);
  exit(1);
  return;
}

int
clearScreen()
{
  terminal->drawStatusLine();
  return 1;
}

int 
main(int argc, char *argv[])
{
  char *nick = getenv("CHATNICK");
  char *terminalType = getenv("TERM");
  char *from = getenv("FROM");
  char *chatserver = getenv("CHATSERVER");

  terminal = new Terminal(terminalType);

  signal(SIGWINCH, noteWindowChange);
  //signal(SIGINT, gracefullyExit);
  signal(SIGINT,  noteWindowChange);

#if defined(perl)
  char *helperScript = getenv("CHATHELPERL");

  if (!helperScript) {
    helperScript = HELPER_SCRIPT;
  }

  perlHelper = new PerlHelper(helperScript);
#endif

  if (!chatserver) {
    chatserver = DEFAULT_SERVER;
  }

  istrstream is(chatserver);

  char chatHost[200];
  short chatPort = -1;
  char c;
  is.getline(chatHost, sizeof chatHost, ':');
  is >> chatPort;

  if (chatPort == -1) {
    cerr << "bad chat server specification: " << chatserver << endl;
    exit(1);
  }

  
  while (!nick) {
    nick = terminal->readline("Enter nick name: ");
    if (!*nick) {
      free(nick);
      nick = 0;
    }
  }

  rl_bind_key('L' - '@', clearScreen);

  if (!from) {		// set up 'from' specification

    ostrstream os;
    char hostname[MAXHOSTNAMELEN+1]; hostname[MAXHOSTNAMELEN] = 0;
    gethostname(hostname, MAXHOSTNAMELEN);
    os << getlogin() << '@' << hostname << '\0';

    from = os.str();
  }

  if (connectToServer(chatHost, chatPort, nick)) {

    ostrstream os;
    os << ".l " << nick << " " << (from ? from : "somewhere") << "\n";
    write(server, os.str(), os.pcount());
    delete [] os.str();

    terminal->eventHook(eventHook);
    while (!quit) {
      char *buf = terminal->readline("");
#if defined(perl)
      const char *retval;
      //  cerr << "sending \"" << buf << "\" to perl" << endl;
      perlHelper->userInput(buf, &retval);
      //  cerr << "perl returned \"" << retval << "\"" << endl;
      if (*retval) {
	processInput(retval);
	delete [] retval;
      }
#else
      if (*buf) {
	processInput(buf);
      }
#endif
      free(buf);
      (*terminal) << terminal->cap("clr_eol");
      terminal->flush();
    }
  }

  gracefullyExit();
}

