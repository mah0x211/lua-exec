--
-- Copyright (C) 2022 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
local syscall = require('exec.syscall')
--- @type fun( path:string, argv:nil|string[], envs:nil|table<string, string|number|boolean>, search:nil|boolean, pwd:nil|string )
local exec = syscall.exec

--- @class exec.process

--- execve
--- @param path string
--- @param argv string[]
--- @param envs table<string, string|number|boolean>
--- @param pwd string
--- @return exec.process
--- @return string err
local function execve(path, argv, envs, pwd)
    return exec(path, argv, envs or {}, nil, pwd)
end

--- execvp
--- @param path string
--- @param argv string[]
--- @param pwd string
--- @return exec.process
--- @return string err
local function execvp(path, argv, pwd)
    return exec(path, argv, nil, true, pwd)
end

--- execv
--- @param path string
--- @param argv string[]
--- @param pwd string
--- @return exec.process
--- @return string err
local function execv(path, argv, pwd)
    return exec(path, argv, nil, nil, pwd)
end

--- execle
--- @param path string
--- @param envs table<string, string|number|boolean>
--- @vararg string
--- @return exec.process
--- @return string err
local function execle(path, envs, ...)
    return execve(path, {
        ...,
    }, envs)
end

--- execlp
--- @param path string
--- @vararg string
--- @return exec.process
--- @return string err
local function execlp(path, ...)
    return execvp(path, {
        ...,
    })
end

--- execl
--- @param path string
--- @vararg string
--- @return exec.process
--- @return string err
local function execl(path, ...)
    return execv(path, {
        ...,
    })
end

return {
    execl = execl,
    execlp = execlp,
    execle = execle,
    execv = execv,
    execvp = execvp,
    execve = execve,
    WNOHANG = syscall.WNOHANG,
    WNOWAIT = syscall.WNOWAIT,
    WCONTINUED = syscall.WCONTINUED,
}
