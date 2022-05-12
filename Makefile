SRCS=$(wildcard src/*.c)
SOBJ=$(SRCS:.c=.$(LIB_EXTENSION))
LUALIBS=$(wildcard lib/*.lua)
INSTALL?=install
ifdef EXEC_COVERAGE
COVFLAGS=--coverage
endif

.PHONY: all install

all: $(SOBJ)

%.o: %.c
	$(CC) $(CFLAGS) $(WARNINGS) $(COVFLAGS) $(CPPFLAGS) -o $@ -c $<

%.$(LIB_EXTENSION): %.o
	$(CC) -o $@ $^ $(LDFLAGS) $(LIBS) $(PLATFORM_LDFLAGS) $(COVFLAGS)


install: $(SOBJ)
	$(INSTALL) $(PACKAGE).lua $(INST_LUADIR)
	# $(INSTALL) -d $(INST_LIBDIR)
	# $(INSTALL) $(LUALIBS) $(INST_LIBDIR)
	$(INSTALL) -d $(INST_CLIBDIR)
	$(INSTALL) $(SOBJ) $(INST_CLIBDIR)
	rm -f ./src/*.o
	rm -f ./src/*.so
