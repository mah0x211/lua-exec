require('luacov')
local concat = table.concat
local testcase = require('testcase')
local setenv = require('setenv')
local exec = require('exec')

local PATH = os.getenv('PATH')

function testcase.after_each()
    assert(setenv('PATH', PATH, true))
end

function testcase.execl()
    -- test that exec command
    local p = assert(exec.execl('./example.sh', 'hello', 'execl'))
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
    local p = assert(exec.execv('example.sh', {
        'hello',
        'execvp',
    }))
    local res = p.stdout:read('*a')
    assert.equal(res, 'hello execvp\n')
end

