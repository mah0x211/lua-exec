# lua-exec

[![test](https://github.com/mah0x211/lua-exec/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-exec/actions/workflows/test.yml)
[![Coverage Status](https://coveralls.io/repos/github/mah0x211/lua-exec/badge.svg?branch=master)](https://coveralls.io/github/mah0x211/lua-exec?branch=master)

execute a file.


## Installation

```
luarocks install exec
```


## p, err = exec.execl( path [, ...] )

execute the file pointed to the path.

**Parameters**

- `path:string`: absolute path of the file.
- `...:string`: arguments for the executable.

**Returns**

- `p:exec.process`: process object.
- `err:exec.error`: error object.


## p, err = exec.execlp( path [, ...])

execute the file pointed to the path.

if the specified `path` does not contain a slash (`/`) character, `path` searches for the program using the value of `PATH` from the caller's environment.

**Parameters**

- `path:string`: path of the file.
- `envs:table<string, string|number|boolean>`: the environment variables for the executable.
- `...:string`: arguments for the executable.

**Returns**

- `p:exec.process`: process object.
- `err:exec.error`: error object.


## p, err = exec.execle( path [, envs [, ...]])

execute the file pointed to the path.

**Parameters**

- `path:string`: absolute path of the file.
- `envs:table<string, string|number|boolean>`: the environment variables for the executable.
- `...:string`: arguments for the executable.

**Returns**

- `p:exec.process`: process object.
- `err:exec.error`: error object.


## p, err = exec.execv( path [, argv [, pwd]] )

execute the file pointed to the path.

**Parameters**

- `path:string`: absolute path of the file.
- `argv:string[]`: arguments for the executable.
- `pwd:string`: change the process working directory to `pwd`.

**Returns**

- `p:exec.process`: process object.
- `err:exec.error`: error object.


## p, err = exec.execve( path [, argv [, envs [, pwd]]])

execute the file pointed to the path.

**Parameters**

- `path:string`: absolute path of the file.
- `argv:string[]`: arguments for the executable.
- `envs:table<string, string|number|boolean>`: the environment variables for the executable.
- `pwd:string`: change the process working directory to `pwd`.

**Returns**

- `p:exec.process`: process object.
- `err:exec.error`: error object.


## p, err = exec.execvp( path [, argv [, pwd]])

execute the file pointed to the path.

if the specified `path` does not contain a slash (`/`) character, `path` searches for the program using the value of `PATH` from the caller's environment, not from the envp argument.

**Parameters**

- `path:string`: path of the file.
- `argv:string[]`: arguments for the executable.
- `pwd:string`: change the process working directory to `pwd`.

**Returns**

- `p:exec.process`: process object.
- `err:exec.error`: error object.


## Error Handling

above functions return the error object `exec.error` that created by https://github.com/mah0x211/lua-error module.


### msg = exec.is_error(err)

if type of `err` is the `exec.error`, extract the error message.

**Parameters**

- `err:error`: an error object.

**Returns**

- `msg:table`: an error message or `nil`.

the value of the `code` field of the error message will be set to the number of last error `errno`.


## Process Object

the `exec.exec*` function returns a process object `exec.process` if the child process is successfully created. this object can be used to communicates with executed program via files and signals.

**NOTE:** when this object is GC'd, it sends a `SIGKILL` signal to the associated process if it is still alive.

this object contains the following fields;

- `pid:integer`: process id.
- `stdin:file*`: write-only file for stdin.
- `stdout:file*`: read-only file for stdout.
- `stdout:file*`: read-only file for stderr.

it also has the following methods;

### res, err = p:waitpid( ... )

this method suspends the execution of the calling process until the child process changes its state.

**Parameters**

- `...:integer`: the following options can be specifed.  
   please refer to `man 2 waitpid` for more details.
  - `exec.WNOHANG`
  - `exec.WNOWAIT`
  - `exec.WCONTINUED`

**Returns**

- `res:table`: the result table that contains the following fields.
  - `pid:integer`: target process-id.
  - `exit:integer`: exit status code if the process terminated normally.
  - `sigterm:integer`: the number of the signal if the process was terminated by signal.
  - `coredump:boolean`: `true` if the process produced a core dump.
  - `sigstop:integer`: the number of the signal which caused the process to stop.
  - `sigcont:boolean`: `true` if the process was resumed by delivery of `SIGCONT`.
- `err:exec.error`: error object.


### res, err = p:kill( signo [, ...] )

send signal to a process and calling the waitpid method.

**Parameters**

- `signo:integer`: the signal number.
- `...:integer`: options for `waitpid` method.

**Returns**

same as the return values of the `waitpid` method.

