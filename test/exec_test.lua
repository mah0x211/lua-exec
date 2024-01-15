require('luacov')
local concat = table.concat
local testcase = require('testcase')
local assert = require('assert')
local errno = require('errno')
local setenv = require('setenv')
local signal = require('signal')
local exec = require('exec')

local PATH = os.getenv('PATH')

function testcase.after_each()
    assert(setenv('PATH', PATH, true))
end

function testcase.execl()
    -- test that exec command
    local p = assert(exec.execl('./example.sh', 'hello', 'execl'))
    assert.match(p, '^exec.process: ', false)

    -- test that non-blocking read output of command
    local res, err, errnum = p.stdout:read('*a')
    assert.is_nil(res)
    assert.match(err, 'unavailable')
    assert.equal(errnum, errno.EAGAIN.code)

    -- test that read output of command
    local stdout = assert(p:wait_readable())
    assert.equal(assert(stdout:read()), 'hello execl')
end

function testcase.execlp()
    local pathenv = concat({
        '.',
        os.getenv('PATH'),
    }, ':')
    assert(setenv('PATH', pathenv, true))

    -- test that exec command
    local p = assert(exec.execlp('example.sh', 'hello', 'execlp'))
    local stdout = assert(p:wait_readable())
    assert.equal(assert(stdout:read()), 'hello execlp')
end

function testcase.execle()
    -- test that exec command
    local p = assert(exec.execle('./example.sh', {
        TEST_ENV = 'HELLO_TEST_ENV',
    }, 'hello', 'execle'))
    local stdout = assert(p:wait_readable())
    assert.equal(assert(stdout:read()), 'hello execle HELLO_TEST_ENV')
end

function testcase.execv()
    -- test that exec command
    local p = assert(exec.execv('./example.sh', {
        'hello',
        'execv',
    }))
    local stdout = assert(p:wait_readable())
    assert.equal(assert(stdout:read()), 'hello execv')
end

function testcase.execve()
    -- test that exec command
    local p = assert(exec.execve('./example.sh', {
        'hello',
        'execve',
    }, {
        TEST_ENV = 'HELLO_TEST_ENV',
    }))
    local stdout = assert(p:wait_readable())
    assert.equal(assert(stdout:read()), 'hello execve HELLO_TEST_ENV')
end

function testcase.execvp()
    local pathenv = concat({
        '.',
        os.getenv('PATH'),
    }, ':')
    assert(setenv('PATH', pathenv, true))

    -- test that exec command
    local p = assert(exec.execvp('example.sh', {
        'hello',
        'execvp',
    }))
    local stdout = assert(p:wait_readable())
    assert.equal(assert(stdout:read()), 'hello execvp')
end

function testcase.close()
    local p = assert(exec.execl('./example.sh', 'hello'))

    -- test that close all file descriptors
    local ok, err = p:close()
    assert.is_true(ok)
    assert.is_nil(err)
    assert.is_nil(p.pid)
    assert.is_nil(p.stdin)
    assert.is_nil(p.stdout)
    assert.is_nil(p.stderr)

    -- test that can be called multiple times
    ok, err = p:close()
    assert.is_false(ok)
    assert.is_nil(err)
end

function testcase.waitpid()
    local p = assert(exec.execl('./example.sh', 'hello'))
    local pid = p.pid

    -- test that returns immediately with again=true
    local res, err, again = p:waitpid('nohang', 'untraced', 'continued')
    assert.is_nil(res)
    assert.is_nil(err)
    assert.is_true(again)

    -- test that return result value
    res, err, again = p:waitpid()
    assert.is_nil(err)
    assert.is_nil(again)
    assert.is_table(res)
    assert.equal(res, {
        pid = pid,
        exit = 0,
    })

    -- test that return error object
    res, err = p:waitpid()
    assert(res == nil, 'no error')
    assert.equal(err.op, 'waitpid')
    assert.equal(err.code, errno.ECHILD.code)

    -- test that throws an error if option arguments is invalid
    err = assert.throws(p.waitpid, p, 'hello')
    assert.match(err, 'invalid option')
end

function testcase.kill()
    local p = assert(exec.execl('./example.sh', 'hello'))
    local pid = p.pid

    -- test that EINVAL error
    local ok, err = p:kill(4096)
    assert.is_false(ok)
    assert.equal(err.type, errno.EINVAL)

    -- test that exit by sigterm
    ok, err = p:kill(signal.SIGTERM)
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that return again=true
    local res = assert(p:waitpid())
    assert.equal(res, {
        pid = pid,
        exit = 128 + signal.SIGTERM,
        sigterm = signal.SIGTERM,
    })

    -- test that ESRCH error
    ok, err = p:kill()
    assert.is_false(ok)
    assert.is_nil(err)
end

function testcase.wait_readable()
    local p = assert(exec.execl('./example.sh', 'hello'))
    local pid = p.pid

    -- test that wait readable file
    local files = {
        [p.stdout] = true,
        [p.stderr] = true,
    }
    local compare = {
        [p.stdout] = 'hello',
        [p.stderr] = 'error message',
    }
    while next(files) do
        local f, err, timeout, hup = p:wait_readable()
        assert.match(f, '^file ', false)
        assert.is_nil(err)
        assert.is_nil(timeout)
        assert(files[f])
        if hup then
            files[f] = nil
        end

        if compare[f] then
            assert.equal(assert(f:read()), compare[f])
            compare[f] = nil
        end
    end
    assert.is_nil(next(compare))

    -- test that return all nil if child process is terminated
    do
        local f, err, timeout, hup = p:wait_readable()
        assert.is_nil(f)
        assert.is_nil(err)
        assert.is_nil(timeout)
        assert.is_nil(hup)
    end

    -- test that return result value
    local res, err = p:waitpid()
    assert.is_nil(err)
    assert.equal(res, {
        pid = pid,
        exit = 0,
    })
end

