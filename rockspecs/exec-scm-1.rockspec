package = "exec"
version = "scm-1"
source = {
    url = "git+https://github.com/mah0x211/lua-exec.git",
}
description = {
    summary = "execute a file",
    homepage = "https://github.com/mah0x211/lua-exec",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
    "lauxhlib >= 0.3.0",
    "errno >= 0.5.0",
    "gcfn >= 0.3",
    "gpoll >= 0.9",
    "signal >= 1.6.1",
    "waitpid >= 0.3.2",
}
build = {
    type = 'make',
    build_variables = {
        PACKAGE = "exec",
        LIB_EXTENSION = "$(LIB_EXTENSION)",
        CFLAGS = "$(CFLAGS)",
        WARNINGS = "-Wall -Wno-trigraphs -Wmissing-field-initializers -Wreturn-type -Wmissing-braces -Wparentheses -Wno-switch -Wunused-function -Wunused-label -Wunused-parameter -Wunused-variable -Wunused-value -Wuninitialized -Wunknown-pragmas -Wshadow -Wsign-compare",
        CPPFLAGS = "-I$(LUA_INCDIR)",
        LDFLAGS = "$(LIBFLAG)",
        EXEC_COVERAGE = "$(EXEC_COVERAGE)",
    },
    install_variables = {
        PACKAGE = "exec",
        LIB_EXTENSION = "$(LIB_EXTENSION)",
        INST_LUADIR = "$(LUADIR)",
        INST_LIBDIR = "$(LUADIR)/exec/",
        INST_CLIBDIR = "$(LIBDIR)/exec/",
        LUA_INCDIR = '$(LUA_INCDIR)',
    },
}
