rockspec_format = "3.0"
package = "exec"
version = "scm-1"
source = {
    url = "git+https://github.com/mah0x211/lua-exec.git"
}
description = {
    summary = "execute a file",
    homepage = "https://github.com/mah0x211/lua-exec",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga"
}
dependencies = {
    "lua >= 5.1",
}
build = {
    type = 'builtin',
    build_variables = {
        WARNINGS        = "-Wall -Wno-trigraphs -Wmissing-field-initializers -Wreturn-type -Wmissing-braces -Wparentheses -Wno-switch -Wunused-function -Wunused-label -Wunused-parameter -Wunused-variable -Wunused-value -Wuninitialized -Wunknown-pragmas -Wshadow -Wsign-compare",
    },
    modules = {
        ['exec'] = 'lib/exec.lua',
        ['exec.syscall'] = {
            sources = { 'src/syscall.c' }
        },
    }
}
