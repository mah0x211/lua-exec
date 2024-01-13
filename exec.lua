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
local new_process = require('exec.process')

--- @class exec.pid
--- @field pid fun(self:exec.pid):(integer)
--- @field stdin fun(self:exec.pid):(file*)
--- @field stdout fun(self:exec.pid):(file*)
--- @field stderr fun(self:exec.pid):(file*)
--- @field kill fun(self:exec.pid, sig:number):(ok:boolean, err:any)
--- @field waitpid fun(self:exec.pid, ...:string):(res:table|nil, err:any, again:boolean)
--- @type fun( path:string, argv:string[]?, envs:table<string, string|number|boolean>?, search:boolean?, pwd:string? ):(pid:exec.pid, err:any)
local syscall = require('exec.syscall')

--- do_exec
--- @param path string
--- @param argv string[]?
--- @param envs table<string, string|number|boolean>?
--- @param search boolean?
--- @param pwd string?
--- @return exec.process
--- @return any err
local function do_exec(path, argv, envs, search, pwd)
    local ep, err = syscall(path, argv, envs, search, pwd)
    if not ep then
        return nil, err
    end
    return new_process(ep)
end

--- execve
--- @param path string
--- @param argv string[]
--- @param envs table<string, string|number|boolean>
--- @param pwd string
--- @return exec.process
--- @return any err
local function execve(path, argv, envs, pwd)
    return do_exec(path, argv, envs or {}, nil, pwd)
end

--- execvp
--- @param path string
--- @param argv string[]
--- @param pwd string
--- @return exec.process
--- @return any err
local function execvp(path, argv, pwd)
    return do_exec(path, argv, nil, true, pwd)
end

--- execv
--- @param path string
--- @param argv string[]
--- @param pwd string
--- @return exec.process
--- @return any err
local function execv(path, argv, pwd)
    return do_exec(path, argv, nil, nil, pwd)
end

--- execle
--- @param path string
--- @param envs table<string, string|number|boolean>
--- @param ... string
--- @return exec.process
--- @return any err
local function execle(path, envs, ...)
    return do_exec(path, {
        ...,
    }, envs)
end

--- execlp
--- @param path string
--- @param ... string
--- @return exec.process
--- @return any err
local function execlp(path, ...)
    return do_exec(path, {
        ...,
    })
end

--- execl
--- @param path string
--- @param ... string
--- @return exec.process
--- @return any err
local function execl(path, ...)
    return do_exec(path, {
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
}
