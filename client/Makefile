PERLCORE != perl -MConfig -e 'print "$$Config{archlib}/CORE"'
LDADD=	-lreadline -ltermcap -lstdc++ -L$(PERLCORE) -lperl -lm -lcrypt
CFLAGS=	-g -Dperl -I$(PERLCORE) -D_STREAM_COMPAT
CC = cc
CXX = c++

SRCS=	vchat.cc \
	PerlHelper.cc Terminal.cc

CLEANFILES=*~* tcapNames.i

PROG=	vchat

all: $(PROG)

beforedepend: tcapNames.i

Terminal.o: tcapNames.i

tcapNames.i: tcapNames make-tcaps.pl
	perl make-tcaps.pl < tcapNames > tcapNames.i

dist:
	(cd .. ; tar cvfz vchat23-pre-alpha.tgz `awk -F/ '/^\// {print "vchat/" $$2}' < vchat/CVS/Entries`)

include bsd.prog.mk
include bsd.dep.mk
