/**
 *  Copyright (C) 2022 Masatoshi Fukunaga
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a
 *  copy of this software and associated documentation files (the "Software"),
 *  to deal in the Software without restriction, including without limitation
 *  the rights to use, copy, modify, merge, publish, distribute, sublicense,
 *  and/or sell copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 *  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *  DEALINGS IN THE SOFTWARE.
 */

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <math.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
// lua
#include <lua_errno.h>

static void stdpipe_close(int fds[6])
{
    for (int i = 0; i < 6; i++) {
        if (fds[i]) {
            close(fds[i]);
        }
    }
}

static int stdpipe_create(int fds[6])
{
    int fd[6]        = {0};
    int *stdin_rdwr  = fd;
    int *stdout_rdwr = fd + 2;
    int *stderr_rdwr = fd + 4;

    // create pipes
    for (int i = 0; i <= 4; i += 2) {
        if (pipe(fd + i) == -1 || fcntl(fd[i], F_SETFD, FD_CLOEXEC) == -1 ||
            fcntl(fd[i + 1], F_SETFD, FD_CLOEXEC) == -1) {
            stdpipe_close(fd);
            return -1;
        }
    }
    // parent 0-2
    fds[0] = stdin_rdwr[1];
    fds[1] = stdout_rdwr[0];
    fds[2] = stderr_rdwr[0];
    // child 3-5
    fds[3] = stdin_rdwr[0];
    fds[4] = stdout_rdwr[1];
    fds[5] = stderr_rdwr[1];

    return 0;
}

static int stdpipe_to_stdio(int fds[6])
{
    // replace standard/io to pipe/io
    int ng = dup2(fds[3], STDIN_FILENO) == -1 ||
             dup2(fds[4], STDOUT_FILENO) == -1 ||
             dup2(fds[5], STDERR_FILENO) == -1;
    stdpipe_close(fds);
    return -ng;
}

static int isinteger(lua_State *L, int idx)
{
#if LUA_VERSION_NUM >= 503
    return lua_isinteger(L, idx);
#else
    return (lua_type(L, idx) == LUA_TNUMBER && isfinite(lua_tonumber(L, idx)) &&
            lua_tonumber(L, idx) == (lua_Number)lua_tointeger(L, idx));
#endif
}

#define EXEC_PROC_MT "exec.process"

static lua_Integer checkflags(lua_State *L, int idx)
{
    const int argc  = lua_gettop(L);
    lua_Integer flg = 0;

    for (; idx <= argc; idx++) {
        if (!lua_isnoneornil(L, idx)) {
            if (!isinteger(L, idx)) {
                const char *msg = lua_pushfstring(L, "integer expected, got %s",
                                                  luaL_typename(L, idx));
                return luaL_argerror(L, idx, msg);
            }
            flg |= lua_tointeger(L, idx);
        }
    }

    return flg;
}

static pid_t getfield_pid(lua_State *L, int idx)
{
    lua_getfield(L, idx, "pid");
    if (isinteger(L, -1)) {
        pid_t pid = (pid_t)lua_tointeger(L, -1);
        lua_pop(L, 1);
        return pid;
    }
    // pid field does not exists
    return -1;
}

static void checkmetatable(lua_State *L, int idx)
{
    int rc = 0;

    // idx value has specified metatable
    if (lua_getmetatable(L, idx)) {
        // get metatable from registry
        lua_pushstring(L, EXEC_PROC_MT);
        lua_rawget(L, LUA_REGISTRYINDEX);
        rc = lua_rawequal(L, -1, -2);
        lua_pop(L, 2);
    }

    if (!rc) {
        const char *msg = lua_pushfstring(L, EXEC_PROC_MT " expected, got %s",
                                          lua_type(L, idx));
        luaL_argerror(L, idx, msg);
    }
}

static int waitpid_lua(lua_State *L)
{
    int opts  = (int)checkflags(L, 2);
    pid_t pid = 0;
    int rc    = 0;

    checkmetatable(L, 1);
    pid = getfield_pid(L, 1);
    // pid field does not exists
    if (pid == -1) {
        lua_pushnil(L);
        errno = ECHILD;
        lua_errno_new(L, errno, "waitpid");
        return 2;
    }

    pid = waitpid(pid, &rc, opts);
    if (pid == 0) {
        // WNOHANG
        lua_pushnil(L);
        lua_pushnil(L);
        lua_pushboolean(L, 1);
        return 3;
    } else if (pid == -1) {
        if (errno == ECHILD) {
            // remove pid field if process does not exist
            lua_pushnil(L);
            lua_setfield(L, 1, "pid");
        }

        // got error
        lua_pushnil(L);
        lua_errno_new(L, errno, "waitpid");
        return 2;
    }

    // push result
    lua_createtable(L, 0, 5);
    lauxh_pushint2tbl(L, "pid", pid);
    if (WIFSTOPPED(rc)) {
        // stopped by signal
        lauxh_pushint2tbl(L, "sigstop", WSTOPSIG(rc));
        return 1;
    } else if (WIFCONTINUED(rc)) {
        // continued by signal
        lauxh_pushbool2tbl(L, "sigcont", 1);
        return 1;
    }

    // remove pid field
    lua_pushnil(L);
    lua_setfield(L, 1, "pid");
    // exit status
    if (WIFEXITED(rc)) {
        lauxh_pushint2tbl(L, "exit", WEXITSTATUS(rc));
    }
    // exit by signal
    if (WIFSIGNALED(rc)) {
        int signo = WTERMSIG(rc);
        lauxh_pushint2tbl(L, "exit", 128 + signo);
        lauxh_pushint2tbl(L, "sigterm", signo);
#ifdef WCOREDUMP
        if (WCOREDUMP(rc)) {
            lauxh_pushbool2tbl(L, "coredump", 1);
        }
#endif
    }

    return 1;
}

static int kill_lua(lua_State *L)
{
    int signo = (int)luaL_optinteger(L, 2, SIGTERM);
    pid_t pid = 0;

    checkmetatable(L, 1);
    pid = getfield_pid(L, 1);
    // pid field does not exists
    if (pid == -1) {
        errno = ESRCH;
        lua_pushboolean(L, 0);
        return 1;
    }

    if (kill(pid, signo) == 0) {
        lua_pushboolean(L, 1);
        return 1;
    } else if (errno == ESRCH) {
        // remove pid field if process does not exist
        lua_pushnil(L);
        lua_setfield(L, 1, "pid");
        lua_pushboolean(L, 0);
        return 1;
    }

    // got error
    lua_pushboolean(L, 0);
    lua_errno_new(L, errno, "kill");
    return 2;
}

static int tostring_lua(lua_State *L)
{
    checkmetatable(L, 1);
    lua_pushfstring(L, EXEC_PROC_MT ": %p", lua_topointer(L, 1));
    return 1;
}

static int gc_lua(lua_State *L)
{
    pid_t pid = getfield_pid(L, 1);

    // kill associated process
    if (pid != -1) {
        if (waitpid(pid, NULL, WNOHANG | WUNTRACED) == 0 &&
            kill(pid, SIGKILL) == 0) {
            waitpid(pid, NULL, WNOHANG | WUNTRACED);
        }
    }

    return 0;
}

static int fd2file(lua_State *L, int fd, const char *mode)
{
    errno = 0;
    fd    = dup(fd);
    if (fd == -1) {
        // failed to duplicate a fd
        return -1;
    } else if (lauxh_tofile(L, fd, mode, NULL) == NULL) {
        close(fd);
        return -1;
    }

    return 1;
}

static int new_exec_proc(lua_State *L, int fd[3])
{
    int top = lua_gettop(L);

    // create process table
    lua_createtable(L, 0, 4);

#define setfile(fd, name, mode)                                                \
    do {                                                                       \
        if (fd2file(L, fd, mode) == -1) {                                      \
            lua_settop(L, top);                                                \
            return -1;                                                         \
        }                                                                      \
        lua_setfield(L, -2, name);                                             \
    } while (0)

    setfile(fd[0], "stdin", "w");
    setfile(fd[1], "stdout", "r");
    setfile(fd[2], "stderr", "r");

#undef setfile

    luaL_getmetatable(L, EXEC_PROC_MT);
    lua_setmetatable(L, -2);

    return top + 1;
}

typedef int (*checkktype)(lua_State *L, int idx);

// key-value pair
static int tbl2stack(lua_State *th, lua_State *L, int idx, checkktype checktype,
                     const char *kerr, int kvp)
{
    int n = 0;

    luaL_checktype(L, idx, LUA_TTABLE);
    lua_pushnil(L);
    while (lua_next(L, idx)) {
        n++;
        if (!lua_checkstack(th, n)) {
            // cannot increase stack size
            return -1;
        }

        // check key type
        if (!checktype(L, -2)) {
            luaL_argerror(L, idx, kerr);
            return -1;
        }

        // check val type
        switch (lua_type(L, -1)) {
        case LUA_TSTRING:
        case LUA_TNUMBER:
        case LUA_TBOOLEAN:
            break;
        default:
            luaL_argerror(L, idx, "value must be string, number or boolean");
            return -1;
        }

        if (kvp) {
            // format to key/value string pair
            lua_pushfstring(th, "%s=%s", lua_tostring(L, -2),
                            lua_tostring(L, -1));
        } else {
            // format to value string
            lua_pushfstring(th, "%s", lua_tostring(L, -1));
        }

        lua_pop(L, 1);
    }
    lua_pop(L, 1);

    return n;
}

extern char **environ;

static int resetenv(void)
{
    char **env    = environ;
    char *buf     = malloc(0);
    size_t buflen = 0;

    while (*env) {
        size_t len = strcspn(*env, "=");
        if (len) {
            // increase buffer size
            if (buflen < len) {
                void *m = realloc(buf, len + 1);
                if (!m) {
                    free(buf);
                    return -1;
                }
                buf    = m;
                buflen = len;
            }

            memcpy(buf, *env, len);
            buf[len] = 0;
            if (unsetenv(buf) != 0) {
                free(buf);
                return -1;
            }
        }
        env++;
    }
    free(buf);

    return 0;
}

static int exec(lua_State *L, int search, const char *path, char **argv,
                char **envp, const char *pwd)
{
    int pidx   = 0;
    pid_t pid  = 0;
    int fds[6] = {0};

    // create io/pipe
    if (stdpipe_create(fds) == -1) {
        lua_pushnil(L);
        lua_errno_new(L, errno, "stdpipe_create");
        return 2;
    }
    // create process table
    pidx = new_exec_proc(L, fds);
    if (pidx == -1) {
        lua_pushnil(L);
        lua_errno_new(L, errno, "new_exec_proc");
        stdpipe_close(fds);
        return 2;
    }

    // create child process
    pid = fork();
    switch (pid) {
    case 0:
        // do execve in child process
        // set stdpipe to stdio
        if (stdpipe_to_stdio(fds) != 0) {
            perror("failed to stdpipe_to_stdio()");
            _exit(errno);
        }
        // set process-working-directory
        if (pwd != NULL && chdir(pwd) == -1) {
            perror("failed to chdir()");
            _exit(errno);
        }

        if (search) {
            // replace env
            if (envp) {
                resetenv();
                for (char **env = envp; *env; env++) {
                    if (putenv(*env)) {
                        perror("failed to putenv()");
                        _exit(errno);
                    }
                }
            }
            execvp(path, argv);
            perror("failed to execvp()");
        } else if (envp) {
            execve(path, argv, envp);
            perror("failed to execve()");
        } else {
            execv(path, argv);
            perror("failed to execv()");
        }
        _exit(errno);

    case -1:
        // got error
        lua_pushnil(L);
        lua_errno_new(L, errno, "fork");
        stdpipe_close(fds);
        return 2;

    default:
        lua_pushinteger(L, pid);
        lua_setfield(L, pidx, "pid");
        // close read-stdin, write-stdout
        stdpipe_close(fds);
        return 1;
    }
}

static int exec_lua(lua_State *L)
{
    const char *path      = lauxh_checkstring(L, 1);
    char *default_argv[2] = {
        (char *)path,
        NULL,
    };
    int search      = lauxh_optboolean(L, 4, 0);
    const char *pwd = lauxh_optstring(L, 5, NULL);
    lua_State *th   = NULL;
    char **argv     = default_argv;
    char **envp     = NULL;

    // manipulate arg length
    lua_settop(L, 5);

    // prealloc of required data
    th = lua_newthread(L);

    // check args
    // argv
    if (!lua_isnoneornil(L, 2)) {
        int top = lua_gettop(th);
        int n   = tbl2stack(th, L, 2, isinteger, "index must be integer", 0);

        if (n == -1) {
            lua_pushnil(L);
            errno = ENOMEM;
            lua_errno_new(L, errno, "exec");
            return 2;
        } else if (n > _POSIX_ARG_MAX) {
            // too many arguments
            const char *msg =
                lua_pushfstring(L, "argv must be less than %d", _POSIX_ARG_MAX);
            return luaL_argerror(L, 2, msg);
        }

        // create argv with addtional null pointer
        argv = (char **)lua_newuserdata(L, sizeof(char *) * (n + 2));
        for (int i = 1; i <= n; i++) {
            argv[i] = (char *)lua_tostring(th, i + top);
        }
        argv[0]     = (char *)path;
        argv[n + 1] = NULL;
    }
    // envp
    if (!lua_isnoneornil(L, 3)) {
        int top = lua_gettop(th);
        int n   = tbl2stack(th, L, 3, lua_isstring, "name must be string", 1);

        if (n == -1) {
            lua_pushnil(L);
            errno = ENOMEM;
            lua_errno_new(L, errno, "exec");
            return 2;
        }

        // create envp with addtional null pointer
        envp = (char **)lua_newuserdata(L, sizeof(char *) * (n + 1));
        for (int i = 1; i <= n; i++) {
            envp[i - 1] = (char *)lua_tostring(th, top + i);
        }
        envp[n] = NULL;
    }
    // TODO: io redirection

    return exec(L, search, path, argv, envp, pwd);
}

LUALIB_API int luaopen_exec_syscall(lua_State *L)
{
    lua_errno_loadlib(L);

    lua_createtable(L, 0, 5);
    // export functions
    lua_pushcfunction(L, exec_lua);
    lua_setfield(L, -2, "exec");
    // export constants
    lua_pushinteger(L, WNOHANG);
    lua_setfield(L, -2, "WNOHANG");
    lua_pushinteger(L, WNOWAIT);
    lua_setfield(L, -2, "WNOWAIT");
#ifdef WCONTINUED
    lua_pushinteger(L, WCONTINUED);
    lua_setfield(L, -2, "WCONTINUED");
#endif

    // create metatable
    if (luaL_newmetatable(L, EXEC_PROC_MT)) {
        struct luaL_Reg mmethod[] = {
            {"__gc",       gc_lua      },
            {"__tostring", tostring_lua},
            {NULL,         NULL        }
        };
        struct luaL_Reg method[] = {
            {"kill",    kill_lua   },
            {"waitpid", waitpid_lua},
            {NULL,      NULL       }
        };

        // metamethods
        for (struct luaL_Reg *ptr = mmethod; ptr->name; ptr++) {
            lua_pushcfunction(L, ptr->func);
            lua_setfield(L, -2, ptr->name);
        }
        // methods
        lua_newtable(L);
        for (struct luaL_Reg *ptr = method; ptr->name; ptr++) {
            lua_pushcfunction(L, ptr->func);
            lua_setfield(L, -2, ptr->name);
        }
        lua_setfield(L, -2, "__index");
        lua_pop(L, 1);
    }

    return 1;
}
