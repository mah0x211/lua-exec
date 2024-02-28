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
- `err:any`: error object.


## p, err = exec.execlp( path [, ...])

execute the file pointed to the path.

if the specified `path` does not contain a slash (`/`) character, `path` searches for the program using the value of `PATH` from the caller's environment.

**Parameters**

- `path:string`: path of the file.
- `envs:table<string, string|number|boolean>`: the environment variables for the executable.
- `...:string`: arguments for the executable.

**Returns**

- `p:exec.process`: process object.
- `err:any`: error object.


## p, err = exec.execle( path [, envs [, ...]])

execute the file pointed to the path.

**Parameters**

- `path:string`: absolute path of the file.
- `envs:table<string, string|number|boolean>`: the environment variables for the executable.
- `...:string`: arguments for the executable.

**Returns**

- `p:exec.process`: process object.
- `err:any`: error object.


## p, err = exec.execv( path [, argv [, pwd]] )

execute the file pointed to the path.

**Parameters**

- `path:string`: absolute path of the file.
- `argv:string[]`: arguments for the executable.
- `pwd:string`: change the process working directory to `pwd`.

**Returns**

- `p:exec.process`: process object.
- `err:any`: error object.


## p, err = exec.execve( path [, argv [, envs [, pwd]]])

execute the file pointed to the path.

**Parameters**

- `path:string`: absolute path of the file.
- `argv:string[]`: arguments for the executable.
- `envs:table<string, string|number|boolean>`: the environment variables for the executable.
- `pwd:string`: change the process working directory to `pwd`.

**Returns**

- `p:exec.process`: process object.
- `err:any`: error object.


## p, err = exec.execvp( path [, argv [, pwd]])

execute the file pointed to the path.

if the specified `path` does not contain a slash (`/`) character, `path` searches for the program using the value of `PATH` from the caller's environment, not from the envp argument.

**Parameters**

- `path:string`: path of the file.
- `argv:string[]`: arguments for the executable.
- `pwd:string`: change the process working directory to `pwd`.

**Returns**

- `p:exec.process`: process object.
- `err:any`: error object.


## Process Object

the `exec.exec*` function returns a process object `exec.process` if the child process is successfully created. this object can be used to communicates with executed program via files and signals.

**NOTE:** when this object is GC'd, it sends a `SIGKILL` signal to the associated process if it is still alive.

this object contains the following fields;

- `pid:integer`: process id.
- `stdin:file*`: write-only file for stdin. (line-buffered)
- `stdout:file*`: read-only file for stdout. (line-buffered)
- `stdout:file*`: read-only file for stderr. (non-buffered)

the above files (`stdin`, `stdout` and `stderr`) operates in `non-blocking` mode. if you want to process synchronously, use the `wait_readable` and `wait_writable` methods.

it also has the following methods;


## ok, err = process:close()

close the associated files and call a `self:kill()` method.

**Returns**

same as `process:kill()` method.


## res, err, again = process:waitpid( [sec [, ...]] )

wait for process termination by https://github.com/mah0x211/lua-waitpid module.

**Parameters**

- `sec:number`: timeout seconds. (`nil` or `<0` means wait forever)
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
- `err:any`: error object.
- `again:boolean`: `true` if the `exec.WNOHANG` option specified and `waitpid` syscall returned `0`.


## ok, err = process:kill( [sig] )

send signal to a process and calling the waitpid method.

**Parameters**

- `sig:integer|string`: the signal number or signal name. (default: `SIGTERM`)

**Returns**

- `ok:boolean`: `true` on success.
- `err:any`: `nil` and `ok` is `false` on process not found, or error object on failure.

**Example**

```lua
local dump = require('dump')
local exec = require('exec')

local p = assert(exec.execl('/bin/sh', '-c', 'sleep 30'))
-- specify signal by name
print(p:kill('SIGTERM')) -- true nil

-- it can also be specified by signal number as follows;
-- local signal = require('signal')
-- print(p:kill(signal.SIGTERM))
print(dump(p:waitpid()))
-- {
--     exit = 143,
--     pid = 12862,
--     sigterm = 15
-- }
```



## fp, err, timeout, hup = process:wait_readable( [sec] )

waits until the process `stdout` or `stderr` becomes readable.

**NOTE** 

this behavior is depends on the https://github.com/mah0x211/lua-gpoll module.  

**Parameters**

- `sec:number`: timeout seconds. (default: `nil`)

**Returns**

- `fp:io.file`: file object of `stdout` or `stderr`.
- `err:any`: error object.
- `timeout:boolean`: `true` if timeout.
- `hup:boolean`: `true` if the peer of `stdout` or `stderr` has been closed.


## fp, err, timeout, hup = process:wait_writable( [sec] )

waits until the process `stdin` becomes writable.

**NOTE** 

this behavior is depends on the https://github.com/mah0x211/lua-gpoll module.  

**Parameters**

- `sec:number`: timeout seconds. (default: `nil`)

**Returns**

- `fp:io.file`: file object of `stdin`.
- `err:any`: error object.
- `timeout:boolean`: `true` if timeout.
- `hup:boolean`: `true` if the peer of `stdin` has been closed.

