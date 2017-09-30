local cron = require './cron'
local utils = require('utils')
local dump = utils.dump
local strip = utils.strip

require('tap')(function (test)

  local counter
  local function count(amount)
    amount = amount or 1
    counter = counter + amount
  end
  local countable = setmetatable({}, {__call = count})

  test('clock :update', function()
    counter = 0
    local clock = cron.every(1, count)
    assert(not pcall(function() clock:update() end))
    assert(not pcall(function() clock:update(-1) end))
    assert(pcall(function() clock:update(1) end))
  end)

  test('clock :reset defaults to 0', function()
    counter = 0
    local clock = cron.every(1, count)
    clock:update(1)
    clock:reset(0)
    assert(clock.running == 0)
  end)

  test('clock :reset throws an error if dt is not positive', function()
    counter = 0
    local clock = cron.every(1, count)
    assert(not pcall(function() clock:reset(-1) end))
    assert(not pcall(function() clock:reset('foo') end))
    assert(pcall(function() clock:reset() end))
    assert(pcall(function() clock:reset(1) end))
  end)

  test('clock .after checks parameters', function()
    counter = 0
    assert(not pcall(function() cron.after('error', count) end))
    assert(not pcall(function() cron.after(2, 'error') end))
    assert(not pcall(function() cron.after(-2, count) end))
    assert(not pcall(function() cron.after(2, {}) end))
    assert(pcall(function() cron.after(2, count) end))
    assert(pcall(function() cron.after(2, countable) end))
  end)

  test('clock .after produces a clock that executes actions only once, at the right time', function()
    counter = 0
    local c1 = cron.after(2, count)
    local c2 = cron.after(4, count)

    -- 1
    c1:update(1)
    assert(counter == 0)
    c2:update(1)
    assert(counter == 0)

    -- 2
    c1:update(1)
    assert(counter == 1)
    c2:update(1)
    assert(counter == 1)

    -- 3
    c1:update(1)
    assert(counter == 1)
    c2:update(1)
    assert(counter == 1)

    -- 4
    c1:update(1)
    assert(counter == 1)
    c2:update(1)
    assert(counter == 2)
  end)

  test('clock .after produces a clock that can be expired', function()
    counter = 0
    local c1 = cron.after(2, count)
    assert(false == c1:update(1))
    assert(true == c1:update(1))
    assert(true == c1:update(1))
  end)

  test('clock .after Passes on parameters to the callback', function()
    counter = 0
    local c1 = cron.after(1, count, 2)
    c1:update(1)
    assert(counter == 2)
  end)

  test('clock .every checks parameters', function()
    counter = 0
    assert(not pcall(function() cron.every('error', count) end))
    assert(not pcall(function() cron.every(2, 'error') end))
    assert(not pcall(function() cron.every(-2, count) end))
    assert(not pcall(function() cron.every(-2, {}) end))
    assert(pcall(function() cron.every(2, count) end))
    assert(pcall(function() cron.every(2, countable) end))
  end)

  test('clock .every Invokes callback periodically', function()
    counter = 0
    local c = cron.every(3, count)

    c:update(1)
    assert(counter == 0)

    c:update(2)
    assert(counter == 1)

    c:update(2)
    assert(counter == 1)

    c:update(1)
    assert(counter == 2)
  end)

  test('clock .every Executes the same action multiple times on a single update if appropiate', function()
    counter = 0
    local c = cron.every(1, count)
    c:update(2)
    assert(counter == 2)
  end)

  test('clock .every Respects parameters', function()
    counter = 0
    local c = cron.every(1, count, 2)
    c:update(2)
    assert(counter == 4)
  end)

end)
