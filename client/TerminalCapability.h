//

#ifndef __TerminalCapability_h
#define __TerminalCapability_h

class Terminal;

class TerminalCapability
{
public:
  TerminalCapability() : _cap("") {};

  operator const bool() const { return _cap && *_cap; };
  bool operator ==(const TerminalCapability &cap) const;

  //  char *str() const { return const_cast<char *> (_cap); };
  char *str() const { return (char *) (_cap); };

  friend Terminal &
  operator<<(Terminal &term, const TerminalCapability &tc);

private:
  friend class Terminal;

  static int putcharTputs(int c);

  const char *_cap;
};

#endif
