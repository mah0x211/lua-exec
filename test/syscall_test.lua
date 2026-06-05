require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local syscall = require('exec.syscall')
local new_process = require('exec.process')

function testcase.invalid_argv_key()
    -- test that throw error if argv contains a non-integer key
    local err = assert.throws(syscall, './example.sh', {
        foo = 'bar',
    })
    assert.match(err, 'index must be integer')
end

function testcase.invalid_argv_value()
    -- test that throw error if argv contains a non-scalar value
    local err = assert.throws(syscall, './example.sh', {
        {},
    })
    assert.match(err, 'value must be string, number or boolean')
end

function testcase.invalid_env_key()
    -- test that throw error if env contains a non-string key
    local err = assert.throws(syscall, './example.sh', {
        'hello',
    }, {
        [true] = 'x',
    })
    assert.match(err, 'name must be string')
end

function testcase.invalid_env_value()
    -- test that throw error if env contains a non-scalar value
    local err = assert.throws(syscall, './example.sh', {
        'hello',
    }, {
        TEST_ENV = {},
    })
    assert.match(err, 'value must be string, number or boolean')
end

function testcase.search_with_env()
    -- test that search and custom env clears the environment before exec.
    -- this exercises the env-clearing path in the child process. PATH is
    -- passed so the script interpreter can still be resolved after the
    -- environment is cleared.
    local result = assert(syscall('./example.sh', {
        'hello',
        'searchenv',
    }, {
        PATH = os.getenv('PATH'),
        TEST_ENV = 'HELLO_TEST_ENV',
    }, true))
    local p = assert(new_process(result))
    assert.equal(assert(p.stdout:read()), 'hello searchenv HELLO_TEST_ENV')
    assert(p:close())
end
