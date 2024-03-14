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
local wait_readable = require('gpoll').wait_readable
local wait_writable = require('gpoll').wait_writable
local unwait_readable = require('gpoll').unwait_readable
local unwait_writable = require('gpoll').unwait_writable
local is_error = require('error.is')
local waitpid = require('waitpid')
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

--- @class exec.pid
--- @field getpid fun(self:exec.pid):(integer)
--- @field getstdio fun(self:exec.pid):(in:file*?, out:file*?, err:file*?, fds:integer[]?)
--- @field close fun(self:exec.pid)
--- @field kill fun(self:exec.pid, sig:number?):(ok:boolean, err:any)
--- @field waitpid fun(self:exec.pid, ...:string):(res:table|nil, err:any, again:boolean)

--- @class exec.process
--- @field private ep exec.pid
--- @field pid integer?
--- @field stdin file*?
--- @field stdout file*?
--- @field stderr file*?
--- @field private stdfds integer[]
local Process = {}

--- init
--- @param ep exec.pid
--- @return exec.process
function Process:init(ep)
    self.ep = ep
    self.pid = ep:getpid()
    self.stdin, self.stdout, self.stderr, self.stdfds = ep:getstdio()
    return self
end

--- do_waitpid_and_kill if waitpid returns again=true, then send a specified
--- signal to the process and wait again.
--- @param pid integer
--- @param sec? number
--- @param ... string|integer signal names or numbers
--- @return table? res
--- @return any err
--- @return boolean? again
local function do_waitpid_and_kill(pid, sec, ...)
    local signals = {
        ...,
    }
    local nsig = select('#', ...)
    for i = 0, nsig do
        local sig = signals[i + 1]
        local res, err, again = waitpid(pid, sec)
        if not again or not sig then
            return res, err
        end
        kill(sig, pid)
    end
end

--- close
--- @param sec number?
--- @return table? res
--- @return any err
function Process:close(sec)
    assert(sec == nil or type(sec) == 'number', 'sec must be number')

    -- close and release stdio references
    if self.ep then
        local pid = self.ep:getpid()
        local res, err
        if pid > 0 then
            -- wait process termination
            res, err = do_waitpid_and_kill(pid, sec, signal.SIGTERM,
                                           signal.SIGKILL)
        end
        self.pid = -pid

        if self.ep:close() then
            for i, fd in pairs(self.stdfds) do
                if i == 0 then
                    unwait_writable(fd)
                else
                    unwait_readable(fd)
                end
            end
            self.stdin:close()
            self.stdout:close()
            self.stderr:close()
            self.stdfds = nil
            self.stdin, self.stdout, self.stderr = nil, nil, nil
            self.ep = nil
        end

        return res, err
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

    if not self.ep then
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
--- @return file*? f
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
--- @return file*? f
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
