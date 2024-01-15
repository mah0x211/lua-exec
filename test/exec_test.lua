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

    -- test that read output of command
    local res = p.stdout:read('*a')
    assert.equal(res, 'hello execl\n')
end

function testcase.execlp()
    local pathenv = concat({
        '.',
        os.getenv('PATH'),
    }, ':')
    assert(setenv('PATH', pathenv, true))

    -- test that exec command
    local p = assert(exec.execlp('example.sh', 'hello', 'execlp'))
    local res = p.stdout:read('*a')
    assert.equal(res, 'hello execlp\n')
end

function testcase.execle()
    -- test that exec command
    local p = assert(exec.execle('./example.sh', {
        TEST_ENV = 'HELLO_TEST_ENV',
    }, 'hello', 'execle'))
    local res = p.stdout:read('*a')
    assert.equal(res, 'hello execle HELLO_TEST_ENV\n')
end

function testcase.execv()
    -- test that exec command
    local p = assert(exec.execv('./example.sh', {
        'hello',
        'execv',
    }))
    local res = p.stdout:read('*a')
    assert.equal(res, 'hello execv\n')
end

function testcase.execve()
    -- test that exec command
    local p = assert(exec.execve('./example.sh', {
        'hello',
        'execve',
    }, {
        TEST_ENV = 'HELLO_TEST_ENV',
    }))
    local res = p.stdout:read('*a')
    assert.equal(res, 'hello execve HELLO_TEST_ENV\n')
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
    local res = p.stdout:read('*a')
    assert.equal(res, 'hello execvp\n')
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

