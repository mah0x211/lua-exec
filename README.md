# lua-exec

[![test](https://github.com/mah0x211/lua-exec/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-exec/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-exec/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-exec)

execute a file.


## Installation

```
luarocks install exec
```

## Error Handling

the following functions return the `error` object created by https://github.com/mah0x211/lua-errno module.


## p, err = exec.execl( path [, ...] )

execute the file pointed to the path.

**Parameters**

- `path:string`: absolute path of the file.
- `...:string`: arguments for the executable.

**Returns**

- `p:exec.process`: process object.
- `err:error`: error object.


## p, err = exec.execlp( path [, ...])

execute the file pointed to the path.

if the specified `path` does not contain a slash (`/`) character, `path` searches for the program using the value of `PATH` from the caller's environment.

**Parameters**

- `path:string`: path of the file.
- `envs:table<string, string|number|boolean>`: the environment variables for the executable.
- `...:string`: arguments for the executable.

**Returns**

- `p:exec.process`: process object.
- `err:error`: error object.


## p, err = exec.execle( path [, envs [, ...]])

execute the file pointed to the path.

**Parameters**

- `path:string`: absolute path of the file.
- `envs:table<string, string|number|boolean>`: the environment variables for the executable.
- `...:string`: arguments for the executable.

**Returns**

- `p:exec.process`: process object.
- `err:error`: error object.


## p, err = exec.execv( path [, argv [, pwd]] )

execute the file pointed to the path.

**Parameters**

- `path:string`: absolute path of the file.
- `argv:string[]`: arguments for the executable.
- `pwd:string`: change the process working directory to `pwd`.

**Returns**

- `p:exec.process`: process object.
- `err:error`: error object.


## p, err = exec.execve( path [, argv [, envs [, pwd]]])

execute the file pointed to the path.

**Parameters**

- `path:string`: absolute path of the file.
- `argv:string[]`: arguments for the executable.
- `envs:table<string, string|number|boolean>`: the environment variables for the executable.
- `pwd:string`: change the process working directory to `pwd`.

**Returns**

- `p:exec.process`: process object.
- `err:error`: error object.


## p, err = exec.execvp( path [, argv [, pwd]])

execute the file pointed to the path.

if the specified `path` does not contain a slash (`/`) character, `path` searches for the program using the value of `PATH` from the caller's environment, not from the envp argument.

**Parameters**

- `path:string`: path of the file.
- `argv:string[]`: arguments for the executable.
- `pwd:string`: change the process working directory to `pwd`.

**Returns**

- `p:exec.process`: process object.
- `err:error`: error object.


## Process Object

the `exec.exec*` function returns a process object `exec.process` if the child process is successfully created. this object can be used to communicates with executed program via files and signals.

**NOTE:** when this object is GC'd, it sends a `SIGKILL` signal to the associated process if it is still alive.


## pid = process:getpid()

returns the process-id of the child process.

**Returns**

- `pid:integer`: process-id.


## res, err, again = process:waitpid( ... )

this method suspends the execution of the calling process until the child process changes its state.

**Parameters**

- `...:string`: wait options;  
    - `'nohang'`: return immediately if no child has exited.
    - `'untraced'`: also return if a child has stopped.
    - `'continued'`: also return if a stopped child has been resumed by delivery of `SIGCONT`.

**Returns**

- `res:table`: the result table that contains the following fields.
  - `pid:integer`: target process-id.
  - `exit:integer`: exit status code if the process terminated normally.
  - `sigterm:integer`: the number of the signal if the process was terminated by signal.
    - **NOTE:** `exit` field is set to `128` + `the number of the signal`.
  - `coredump:boolean`: `true` if the process produced a core dump.
  - `sigstop:integer`: the number of the signal which caused the process to stop.
  - `sigcont:boolean`: `true` if the process was resumed by delivery of `SIGCONT`.
- `err:error`: error object.
- `again:boolean`: `true` if the `exec.WNOHANG` option specified and `waitpid` syscall returned `0`.


## ok, err = process:kill( [signo] )

send signal to a process and calling the waitpid method.

**Parameters**

- `signo:integer`: the signal number. (default: `SIGTERM`)

**Returns**

- `ok:boolean`: `true` on success.
- `err:any`: `nil` and `ok` is `false` on process not found, or error object on failure.


