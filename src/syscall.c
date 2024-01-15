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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
// lua
#include <lua_errno.h>

#define EXEC_PID_MT "exec.pid"

typedef struct {
    pid_t pid;
    FILE *stdin;
    FILE *stdout;
    FILE *stderr;
    int stdin_ref;
    int stdout_ref;
    int stderr_ref;
} exec_pid_t;

static inline int checkoptions(lua_State *L, int index)
{
    static const char *const options[] = {
        "nohang",
        "untraced",
        "continued",
        NULL,
    };
    int top  = lua_gettop(L);
    int opts = 0;

    for (; index <= top; index++) {
        switch (luaL_checkoption(L, index, NULL, options)) {
        case 0:
            opts |= WNOHANG;
            break;

        case 1:
            opts |= WUNTRACED;
            break;

        default:
#ifdef WCONTINUED
            opts |= WCONTINUED;
#endif
            break;
        }
    }

    return opts;
}

static int waitpid_lua(lua_State *L)
{
    exec_pid_t *ep = luaL_checkudata(L, 1, EXEC_PID_MT);
    int opts       = checkoptions(L, 2);
    pid_t pid      = 0;
    int status     = 0;

    // pid field does not exists
    if (ep->pid == -1) {
        lua_pushnil(L);
        errno = ECHILD;
        lua_errno_new(L, errno, "waitpid");
        return 2;
    }

    pid = waitpid(ep->pid, &status, opts);
    if (pid == 0) {
        // WNOHANG
        lua_pushnil(L);
        lua_pushnil(L);
        lua_pushboolean(L, 1);
        return 3;
    } else if (pid == -1) {
        // got error
        if (errno == ECHILD) {
            // process does not exist
            ep->pid = -1;
        }
        lua_pushnil(L);
        lua_errno_new(L, errno, "waitpid");
        return 2;
    }

    // push result
    lua_createtable(L, 0, 5);
    lauxh_pushint2tbl(L, "pid", pid);
    if (WIFSTOPPED(status)) {
        // stopped by signal
        lauxh_pushint2tbl(L, "sigstop", WSTOPSIG(status));
        return 1;
    } else if (WIFCONTINUED(status)) {
        // continued by signal
        lauxh_pushbool2tbl(L, "sigcont", 1);
        return 1;
    }

    // process exited
    ep->pid = -1;
    // exit status
    if (WIFEXITED(status)) {
        lauxh_pushint2tbl(L, "exit", WEXITSTATUS(status));
    }
    // exit by signal
    if (WIFSIGNALED(status)) {
        int signo = WTERMSIG(status);
        lauxh_pushint2tbl(L, "exit", 128 + signo);
        lauxh_pushint2tbl(L, "sigterm", signo);
#ifdef WCOREDUMP
        if (WCOREDUMP(status)) {
            lauxh_pushbool2tbl(L, "coredump", 1);
        }
#endif
    }

    return 1;
}

static int kill_lua(lua_State *L)
{
    exec_pid_t *ep = luaL_checkudata(L, 1, EXEC_PID_MT);
    int signo      = (int)luaL_optinteger(L, 2, SIGTERM);

    // pid field does not exists
    if (ep->pid == -1) {
        errno = ESRCH;
        lua_pushboolean(L, 0);
        return 1;
    }

    if (kill(ep->pid, signo) == 0) {
        lua_pushboolean(L, 1);
        return 1;
    } else if (errno == ESRCH) {
        // process does not exist
        ep->pid = -1;
        lua_pushboolean(L, 0);
        return 1;
    }

    // got error
    lua_pushboolean(L, 0);
    lua_errno_new(L, errno, "kill");
    return 2;
}

static int close_lua(lua_State *L)
{
    exec_pid_t *ep = luaL_checkudata(L, 1, EXEC_PID_MT);

    if (ep->stdin) {
        switch (luaL_loadstring(L, "for _, f in ipairs({...}) do"
                                   "  f:close()"
                                   "end")) {
        case 0:
            lauxh_pushref(L, ep->stdin_ref);
            lauxh_pushref(L, ep->stdout_ref);
            lauxh_pushref(L, ep->stderr_ref);
            lua_call(L, 3, 0);
            ep->stdin = ep->stdout = ep->stderr = NULL;
            break;

        case LUA_ERRMEM:
            // delegate to lua vm
            break;

        default:
            // something wrong
            return lua_error(L);
        }
        ep->stdin_ref  = lauxh_unref(L, ep->stdin_ref);
        ep->stdout_ref = lauxh_unref(L, ep->stdout_ref);
        ep->stderr_ref = lauxh_unref(L, ep->stderr_ref);
        lua_pushboolean(L, 1);
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

static int getstdio_lua(lua_State *L)
{
    exec_pid_t *ep = luaL_checkudata(L, 1, EXEC_PID_MT);

    if (ep->stdin) {
        lauxh_pushref(L, ep->stdin_ref);
        lauxh_pushref(L, ep->stdout_ref);
        lauxh_pushref(L, ep->stderr_ref);
        lua_createtable(L, 3, 0);
        lua_pushinteger(L, fileno(ep->stdin));
        lua_rawseti(L, -2, 0);
        lua_pushinteger(L, fileno(ep->stdout));
        lua_rawseti(L, -2, 1);
        lua_pushinteger(L, fileno(ep->stderr));
        lua_rawseti(L, -2, 2);
        return 4;
    }
    return 0;
}

static int getpid_lua(lua_State *L)
{
    exec_pid_t *ep = luaL_checkudata(L, 1, EXEC_PID_MT);
    lua_pushinteger(L, ep->pid);
    return 1;
}

static int tostring_lua(lua_State *L)
{
    exec_pid_t *ep = luaL_checkudata(L, 1, EXEC_PID_MT);
    lua_pushfstring(L, EXEC_PID_MT ": %p", ep);
    return 1;
}

static int gc_lua(lua_State *L)
{
    exec_pid_t *ep = luaL_checkudata(L, 1, EXEC_PID_MT);

    // kill associated process
    if (ep->pid != -1) {
        if (waitpid(ep->pid, NULL, WNOHANG | WUNTRACED) == 0 &&
            kill(ep->pid, SIGKILL) == 0) {
            waitpid(ep->pid, NULL, WNOHANG | WUNTRACED);
        }
    }

    // release file descriptor reference
    if (ep->stdin) {
        lauxh_unref(L, ep->stdin_ref);
        lauxh_unref(L, ep->stdout_ref);
        lauxh_unref(L, ep->stderr_ref);
    }

    return 0;
}

static void stdpipe_close(int fds[6])
{
    for (int i = 0; i < 6; i++) {
        if (fds[i]) {
            close(fds[i]);
        }
    }
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

extern char **environ;

static void do_exec(int fds[6], int search, const char *path, char **argv,
                    char **envp, const char *pwd)
{
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
            // clear environment variables
            char **env     = environ;
            char *name     = malloc(0);
            size_t namelen = 0;

            while (*env) {
                size_t len = strcspn(*env, "=");
                if (len) {
                    // increase buffer size
                    if (namelen < len) {
                        void *m = realloc(name, len + 1);
                        if (!m) {
                            free(name);
                            perror("failed to relloc()");
                            _exit(errno);
                        }
                        name    = m;
                        namelen = len;
                    }

                    memcpy(name, *env, len);
                    name[len] = 0;
                    if (unsetenv(name) != 0) {
                        free(name);
                        perror("failed to unsetenv()");
                        _exit(errno);
                    }
                }
                env++;
            }
            free(name);

            // set user defined environment variables
            for (env = envp; *env; env++) {
                if (putenv(*env)) {
                    perror("failed to putenv()");
                    _exit(errno);
                }
            }
        }
        setvbuf(stdin, NULL, _IOLBF, 0);
        setvbuf(stdout, NULL, _IOLBF, 0);
        setvbuf(stderr, NULL, _IONBF, 0);
        execvp(path, argv);
        perror("failed to execvp()");
    } else if (envp) {
        execve(path, argv, envp);
        perror("failed to execve()");
    } else {
        execv(path, argv);
        perror("failed to execv()");
    }
}

static inline FILE *fd2file(lua_State *L, int fd, const char *mode, int bufmode)
{
    FILE *fp = NULL;

    errno = 0;
    fd    = dup(fd);
    if (fd == -1) {
        // failed to duplicate a fd
        return NULL;
    }

    fp = lauxh_tofile(L, fd, mode, NULL);
    if (fp == NULL) {
        close(fd);
        return NULL;
    }
    setvbuf(fp, NULL, bufmode, 0);

    return fp;
}

static int stdpipe_create(lua_State *L, exec_pid_t *ep, int fds[6])
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

    // set O_NONBLOCK to parent fds
    if (fcntl(stdin_rdwr[1], F_SETFL, O_NONBLOCK) == -1 ||
        fcntl(stdout_rdwr[0], F_SETFL, O_NONBLOCK) == -1 ||
        fcntl(stderr_rdwr[0], F_SETFL, O_NONBLOCK) == -1) {
        stdpipe_close(fd);
        return -1;
    }

    // create stdin, stdout and stderr FILE streams
    if (!(ep->stdin = fd2file(L, stdin_rdwr[1], "w", _IOLBF)) ||
        !(ep->stdout = fd2file(L, stdout_rdwr[0], "r", _IOLBF)) ||
        !(ep->stderr = fd2file(L, stderr_rdwr[0], "r", _IONBF))) {
        stdpipe_close(fds);
        return -1;
    }
    // retain file descriptor reference
    ep->stderr_ref = lauxh_ref(L);
    ep->stdout_ref = lauxh_ref(L);
    ep->stdin_ref  = lauxh_ref(L);

    return 0;
}

static int exec(lua_State *L, int search, const char *path, char **argv,
                char **envp, const char *pwd)
{
    exec_pid_t *ep = lua_newuserdata(L, sizeof(exec_pid_t));
    int fds[6]     = {0};

    // create io/pipe
    if (stdpipe_create(L, ep, fds) == -1) {
        lua_pushnil(L);
        lua_errno_new(L, errno, "stdpipe_create");
        return 2;
    }

    // create child process
    ep->pid = fork();
    switch (ep->pid) {
    case 0:
        do_exec(fds, search, path, argv, envp, pwd);
        _exit(errno);

    case -1:
        // got error
        lua_pushnil(L);
        lua_errno_new(L, errno, "fork");
        stdpipe_close(fds);
        return 2;

    default:
        // close read-stdin, write-stdout
        stdpipe_close(fds);
        lauxh_setmetatable(L, EXEC_PID_MT);
        return 1;
    }
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

static int isinteger(lua_State *L, int idx)
{
#if LUA_VERSION_NUM >= 503
    return lua_isinteger(L, idx);
#else
    return (lua_type(L, idx) == LUA_TNUMBER && isfinite(lua_tonumber(L, idx)) &&
            lua_tonumber(L, idx) == (lua_Number)lua_tointeger(L, idx));
#endif
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
    // create metatable
    if (luaL_newmetatable(L, EXEC_PID_MT)) {
        struct luaL_Reg mmethod[] = {
            {"__gc",       gc_lua      },
            {"__tostring", tostring_lua},
            {NULL,         NULL        }
        };
        struct luaL_Reg method[] = {
            {"getpid",   getpid_lua  },
            {"getstdio", getstdio_lua},
            {"close",    close_lua   },
            {"kill",     kill_lua    },
            {"waitpid",  waitpid_lua },
            {NULL,       NULL        }
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

    lua_errno_loadlib(L);
    // export functions
    lua_pushcfunction(L, exec_lua);
    return 1;
}
