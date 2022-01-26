# lua-exec

[![test](https://github.com/mah0x211/lua-exec/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-exec/actions/workflows/test.yml)
[![Coverage Status](https://coveralls.io/repos/github/mah0x211/lua-exec/badge.svg?branch=master)](https://coveralls.io/github/mah0x211/lua-exec?branch=master)

execute a file.


## Installation

```
luarocks install exec
```


## p, err = execl( path [, ...] )

execute the file pointed to the path.

**Parameters**

- `path:string`: absolute path of the file.
- `...:string`: arguments for the executable.

**Returns**

- `p:exec.process`: process object.
- `err:string`: error message.


## p, err = execlp( path [, ...])

execute the file pointed to the path.

if the specified `path` does not contain a slash (`/`) character, `path` searches for the program using the value of `PATH` from the caller's environment.

**Parameters**

- `path:string`: path of the file.
- `envs:table<string, string|number|boolean>`: the environment variables for the executable.
- `...:string`: arguments for the executable.

**Returns**

- `p:exec.process`: process object.
- `err:string`: error message.


## p, err = execle( path [, envs [, ...]])

execute the file pointed to the path.

**Parameters**

- `path:string`: absolute path of the file.
- `envs:table<string, string|number|boolean>`: the environment variables for the executable.
- `...:string`: arguments for the executable.

**Returns**

- `p:exec.process`: process object.
- `err:string`: error message.


## p, err = execv( path [, argv [, pwd]] )

execute the file pointed to the path.

**Parameters**

- `path:string`: absolute path of the file.
- `argv:string[]`: arguments for the executable.
- `pwd:string`: change the process working directory to `pwd`.

**Returns**

- `p:exec.process`: process object.
- `err:string`: error message.


## p, err = execve( path [, argv [, envs [, pwd]]])

execute the file pointed to the path.

**Parameters**

- `path:string`: absolute path of the file.
- `argv:string[]`: arguments for the executable.
- `envs:table<string, string|number|boolean>`: the environment variables for the executable.
- `pwd:string`: change the process working directory to `pwd`.

**Returns**

- `p:exec.process`: process object.
- `err:string`: error message.


## p, err = execvp( path [, argv [, pwd]])

execute the file pointed to the path.

if the specified `path` does not contain a slash (`/`) character, `path` searches for the program using the value of `PATH` from the caller's environment, not from the envp argument.

**Parameters**

- `path:string`: path of the file.
- `argv:string[]`: arguments for the executable.
- `pwd:string`: change the process working directory to `pwd`.

**Returns**

- `p:exec.process`: process object.
- `err:string`: error message.

***

## `exec.process` object

the `exec.exec*` function returns an `exec.process` object if the child process is successfully created. this object can be used to communicates with executed program via files and signals.

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
- `err:string`: error message.


### res, err = p:kill( signo [, ...] )

send signal to a process and calling the waitpid method.

**Parameters**

- `signo:integer`: the signal number.
- `...:integer`: options for `waitpid` method.

**Returns**

same as the return values of the `waitpid` method.

