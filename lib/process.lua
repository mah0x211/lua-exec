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
local Process = {}

--- init
--- @param ep exec.pid
--- @return exec.process
function Process:init(ep)
    self.ep = ep
    self.pid = ep:getpid()
    self.stdin, self.stdout, self.stderr = ep:getstdio()
    return self
end

--- close
--- @return boolean ok
--- @return any err
function Process:close()
    if self.ep:close() then
        self.pid, self.stdin, self.stdout, self.stderr = nil, nil, nil, nil
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

Process = require('metamodule').new(Process)

return Process
