CLEANFILES=*~*

all:
	@echo No default target, cd to "'client'" to make the client

dist:
	(cd .. ; tar cvfz vchat23-pre-alpha.tgz `awk -F/ '/^\// {print "vchat/" $$2}' < vchat/CVS/Entries`)

include bsd.prog.mk
include bsd.dep.mk
