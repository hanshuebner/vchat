PERLCORE = `exec perl -MConfig -e 'print "$$Config{archlib}/CORE"'`
LDLIBS=	-L$(PERLCORE) -L/usr/lib -lm -L/usr/local/lib -lreadline -lcurses -lperl -lcrypt -lsec
CFLAGS=	-Dperl -I$(PERLCORE) -I/usr/local/include -DHPUX11 -Ubool

#CXX=	aCC
CXX=	g++

.cc.o:
	$(CXX) -c $(CFLAGS) $<

SRCS=	vchat.cc \
	PerlHelper.cc Terminal.cc

OBJS=	$(SRCS:.cc=.o)

all: vchat

vchat:	$(OBJS)
	$(CXX) $(CFLAGS) -o $@ $(OBJS) $(LDLIBS)

clean:
	$(RM) *.o *.I vchat *~

Terminal.o: tcapNames.i

tcapNames.i: tcapNames make-tcaps.pl
	perl make-tcaps.pl < tcapNames > tcapNames.i

