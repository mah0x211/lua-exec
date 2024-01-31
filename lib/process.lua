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
local wait_readable = require('gpoll').wait_readable
local wait_writable = require('gpoll').wait_writable
local unwait_readable = require('gpoll').unwait_readable
local unwait_writable = require('gpoll').unwait_writable

--- @class exec.pid
--- @field getpid fun(self:exec.pid):(integer)
--- @field getstdio fun(self:exec.pid):(in:file*?, out:file*?, err:file*?, fds:integer[]?)
--- @field close fun(self:exec.pid)
--- @field kill fun(self:exec.pid, sig:number?):(ok:boolean, err:any)
--- @field waitpid fun(self:exec.pid, ...:string):(res:table|nil, err:any, again:boolean)

--- @class gcfn
--- @field enable fun(self:gcfn)
--- @field disable fun(self:gcfn)
--- @type fun(fn:function, ...:any):gcfn
local gcfn = require('gcfn')

--- @class exec.process
--- @field private ep exec.pid
--- @field pid integer?
--- @field stdin file*?
--- @field stdout file*?
--- @field stderr file*?
--- @field private stdfds integer[]
--- @field private gco gcfn
local Process = {}

--- unwait_fds
--- @param fds integer[]
local function unwait_fds(fds)
    if fds then
        for i, fd in pairs(fds) do
            if i == 0 then
                unwait_writable(fd)
            else
                unwait_readable(fd)
            end
        end
    end
end

--- init
--- @param ep exec.pid
--- @return exec.process
function Process:init(ep)
    self.ep = ep
    self.pid = ep:getpid()
    self.stdin, self.stdout, self.stderr, self.stdfds = ep:getstdio()
    self.gco = gcfn(function(stdfds)
        unwait_fds(stdfds)
    end, self.stdfds)
    return self
end

--- close
--- @return boolean ok
--- @return any err
function Process:close()
    unwait_fds(self.stdfds)
    if self.gco then
        self.gco:disable()
        self.gco = nil
    end

    if self.ep:close() then
        self.pid, self.stdin, self.stdout, self.stderr = nil, nil, nil, nil
        self.stdfds = nil
        return self:kill()
    end
    -- already closed
    return false
end

--- kill
--- @param sig number?
--- @return boolean ok
--- @return any err
function Process:kill(sig)
    return self.ep:kill(sig)
end

--- waitpid
--- @param ... string
--- @return table|nil res
--- @return any err
--- @return boolean again
function Process:waitpid(...)
    return self.ep:waitpid(...)
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
