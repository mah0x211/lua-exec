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
local pairs = pairs
local find = string.find
local type = type
local wait_readable = require('gpoll').wait_readable
local wait_writable = require('gpoll').wait_writable
local unwait_readable = require('gpoll').unwait_readable
local unwait_writable = require('gpoll').unwait_writable
local is_error = require('error.is')
local waitpid = require('waitpid')
local new_reader = require('io.reader').new
local new_writer = require('io.writer').new
local close = require('io.close')
local signal = require('signal')
local kill = signal.kill
--- constants
local EINVAL = require('errno').EINVAL
local ESRCH = require('errno').ESRCH
local SIGTERM = signal.SIGTERM
local VALID_SIGNALS = {}
for k, v in pairs(signal) do
    if find(k, '^SIG%w+$') then
        VALID_SIGNALS[k], VALID_SIGNALS[v] = v, v
    end
end

--- @class exec.result
--- @field pid integer
--- @field stdin integer
--- @field stdout integer
--- @field stderr integer

--- @class io.writer
--- @field getfd fun(self:io.writer):(fd:integer)
--- @field close fun(self:io.writer):(ok:boolean, err:any)
--- @field write fun(self:io.writer, data:string, ...):(n:integer, err:any)

--- @class io.reader
--- @field getfd fun(self:io.reader):(fd:integer)
--- @field close fun(self:io.reader):(ok:boolean, err:any)
--- @field read fun(self:io.reader, fmt?:integer|string):(data:string, err:any)

--- @class exec.process
--- @field pid integer
--- @field stdin io.writer?
--- @field stdout io.reader?
--- @field stderr io.reader?
--- @field private stdfds integer[]
local Process = {}

--- init
--- @param result exec.result
--- @return exec.process
--- @return any err
function Process:init(result)
    local stdfds = {}
    local err

    -- wrap stdio file descriptors with io.reader/io.writer
    for i, k in ipairs({
        'stdin',
        'stdout',
        'stderr',
    }) do
        local fd = result[k]
        if not err then
            local f
            if k == 'stdin' then
                f, err = new_writer(fd)
            else
                f, err = new_reader(fd)
            end

            if not err then
                self[k] = f
                stdfds[i - 1] = f:getfd()
            end
        end
        close(fd)
    end

    if err then
        return nil, err
    end

    self.pid = result.pid
    self.stdfds = stdfds
    return self
end

--- close
--- @param sec number?
--- @return table? res
--- @return any err
function Process:close(sec)
    assert(sec == nil or type(sec) == 'number', 'sec must be number')

    -- close and release stdio references
    if self.pid > 0 then
        unwait_writable(self.stdin:getfd())
        unwait_readable(self.stdout:getfd())
        unwait_readable(self.stderr:getfd())
        self.stdin:close()
        self.stdout:close()
        self.stderr:close()
        self.stdin, self.stdout, self.stderr = nil, nil, nil

        local pid = self.pid
        self.pid = -pid

        -- wait process termination
        local res, err, again = waitpid(pid, sec)
        if not again then
            return res, err
        end

        -- kill the process with SIGTERM and wait again
        kill(signal.SIGTERM, pid)
        res, err, again = waitpid(pid, sec)
        if not again then
            return res, err
        end

        -- kill the process with SIGKILL and wait again
        kill(signal.SIGKILL, pid)
        return waitpid(pid)
    end
end

--- kill
--- @param sig? string|integer
--- @return boolean ok
--- @return any err
function Process:kill(sig)
    assert(sig == nil or type(sig) == 'string' or type(sig) == 'number',
           'sig must be string or integer')

    local signo = SIGTERM
    if sig then
        signo = sig == '0' and 0 or VALID_SIGNALS[sig]
        if not signo then
            return false, EINVAL:new('invalid signal')
        end
    end

    if self.pid < 0 then
        -- context already closed
        return false
    end

    local ok, err = kill(signo, self.pid)
    if is_error(err, ESRCH) then
        err = nil
    end
    return ok, err
end

--- wait_readable
--- @param sec number?
--- @return io.reader? r
--- @return any err
--- @return boolean? timeout
--- @return boolean? hup
function Process:wait_readable(sec)
    local stdfds = self.stdfds
    local fd, err, timeout, hup = wait_readable(stdfds[1], sec, stdfds[2])
    if not fd then
        return nil, err, timeout
    elseif fd == stdfds[1] then
        if hup then
            stdfds[1] = nil
        end
        return self.stdout, nil, nil, hup
    elseif hup then
        stdfds[2] = nil
    end
    return self.stderr, nil, nil, hup
end

--- wait_writable
--- @param sec number?
--- @return io.writer? w
--- @return any err
--- @return boolean? timeout
--- @return boolean? hup
function Process:wait_writable(sec)
    local stdfds = self.stdfds
    local fd, err, timeout, hup = wait_writable(stdfds[0], sec)
    if not fd then
        return nil, err, timeout
    elseif hup then
        stdfds[0] = nil
    end
    return self.stdin, nil, nil, hup
end

Process = require('metamodule').new(Process)

return Process
