require('luacov')
local concat = table.concat
local testcase = require('testcase')
local gettime = require('time.clock').gettime
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
    -- test that wait process termination and close associated file descriptors
    local t = gettime()
    local p = assert(exec.execl('/bin/sh', '-c', 'sleep 1'))
    local pid = p.pid
    local res, err = p:close()
    t = gettime() - t
    assert.is_nil(err)
    assert.equal(p.pid, -pid)
    assert.is_nil(p.stdin)
    assert.is_nil(p.stdout)
    assert.is_nil(p.stderr)
    assert.equal(res, {
        pid = pid,
        exit = 0,
    })
    assert(t >= 1 and t < 1.2)

    -- test that can be called multiple times
    res, err = p:close()
    assert.is_nil(err)
    assert.is_nil(res)

    -- test that send SIGTERM after timeout
    t = gettime()
    p = assert(exec.execl('/bin/sh', '-c', 'sleep 1'))
    pid = p.pid
    res, err = p:close(0.5)
    t = gettime() - t
    assert.is_nil(err)
    assert.equal(p.pid, -pid)
    assert.greater(t, 0.5)
    assert.less(t, 0.6)
    assert.is_nil(p.stdin)
    assert.is_nil(p.stdout)
    assert.is_nil(p.stderr)
    assert.equal(res, {
        pid = pid,
        exit = 128 + signal.SIGTERM,
        sigterm = signal.SIGTERM,
    })
end

function testcase.kill()
    local p = assert(exec.execl('./example.sh', 'hello'))
    local pid = p.pid

    -- test that EINVAL error
    local ok, err = p:kill(4096)
    assert.is_false(ok)
    assert.equal(err.type, errno.EINVAL)

    -- test that exit by sigterm
    ok, err = p:kill('SIGTERM')
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that wait process termination
    local res = assert(p:close())
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
    local res, err = p:close()
    assert.is_nil(err)
    assert.equal(res, {
        pid = pid,
        exit = 0,
    })
end

function testcase.wait_writable()
    local p = assert(exec.execl('./example.sh', 'read_stdin'))
    local pid = p.pid

    -- test that write message to stdin
    do
        local f, err, timeout, hup = p:wait_writable()
        assert.match(f, '^file ', false)
        assert.is_nil(err)
        assert.is_nil(timeout)
        assert.is_nil(hup)
        assert.equal(f, p.stdin)
        assert(f:write('message1 from stdin\n'))
        assert(f:write('message2 from stdin\n'))
    end

    -- test that wait readable file
    local files = {
        [p.stdout] = true,
        [p.stderr] = true,
    }
    local compare = {
        [p.stdout] = {
            'read_stdin',
            'message1 from stdin',
            'message2 from stdin',
            'EOF',
        },
        [p.stderr] = {
            'error message',
        },
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

        local messages = compare[f]
        while compare[f] do
            local msg
            msg, err = f:read()
            if not msg then
                assert.match(err, errno.EAGAIN.message)
                break
            end
            assert.equal(msg, messages[1])
            table.remove(messages, 1)
            if #messages == 0 then
                compare[f] = nil
            end
        end
    end
    assert.is_nil(next(compare))

    -- test that failed to write to stdin after child process is terminated
    do
        local f, err, timeout = p:wait_writable()
        assert.equal(f, p.stdin)
        assert.is_nil(err)
        assert.is_nil(timeout)
        assert.equal(f, p.stdin)

        local _
        _, err = f:write('message from stdin\n')
        assert.match(err, errno.EPIPE.message)
    end

    -- test that return result value
    local res, err = p:close()
    assert.is_nil(err)
    assert.equal(res, {
        pid = pid,
        exit = 0,
    })
end

