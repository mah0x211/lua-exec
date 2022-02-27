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
    "error >= 0.6.2",
    "lauxhlib >= 0.3.0",
}
build = {
    type = 'builtin',
    modules = {
        ['exec'] = 'lib/exec.lua',
        ['exec.syscall'] = {
            sources = { 'src/syscall.c' }
        },
    }
}
