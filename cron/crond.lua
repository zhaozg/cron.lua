
----parse crontab config file----
------------------------0. fields
--|---------------------1. minute	0-59
--|  |------------------2. hour	0-23
--|  |  |---------------3. day of month	0-31
--|  |  |  |------------4. month	0-12 (or names, see below)
--|  |  |  |  |---------5. day of week,0-7 (0 or 7 is Sun, or use names)
--|  |  |  |  |       |-6. command, the rest of line are specifies the command with arg to be run
--|  |  |  |  |       |
--*  *  *  *  *       cmd_with_args

-----format of field----
--Lists are allowed.  A list is a set of numbers (or ranges)
--separated by commas.  Examples: ``1,2,5,9'', ``0-4,8-12''.
--
--Step values can be used in conjunction with ranges.  Following
--a range with ``/<number>'' specifies skips of the number's value
--through the range.  For example, ``0-23/2'' can be used in the hours
--field to specify command execution every other hour (the alternative
--in the V7 standard is ``0,2,4,6,8,10,12,14,16,18,20,22'').  Steps are
--also permitted after an asterisk, so if you want to say ``every two
--hours'', just use ``*/2''.
--
--Names can also be used for the ``month'' and ``day of week''
--fields.  Use the first three letters of the particular
--day or month (case doesn't matter).  Ranges or
--lists of names are not allowed.
--
--The ``sixth'' field (the rest of the line) specifies the command to be

local spawn = require('childprocess').spawn
local Emitter = require('core').Emitter
local timer = require('timer')
local parse_command = require'./command'

local function inrange(v, range)
        if(range=='*') then return true end
        local rag = {}
        local ret,_,b,e,s = string.find(range, '(%d+)-(%d+)/(%d+)')
        if not ret then
                s = 1
                ret,_,b,e= string.find(range, '(%d+)-(%d+)')
                if not ret then
                        ret,_,s= string.find(range, '%*/(%d+)')
                        if ret then
                                b,e = 0,61
                        end
                end
        end
        if ret then
                for i=b,e,s do
                        rag[i] = true
                end
        else
                string.gsub(range,'%d+',function(n) rag[tonumber(n)]=true end)
        end
        return rag[v]
end

local function check(entry,now)
        local  min, hour, day, month, wday,cmd,line = unpack(entry)
        return  inrange(now.min,min)
                and inrange(now.hour,hour)
                and inrange(now.day,day)
                and inrange(now.month,month)
                and inrange(now.wday,wday)
end

local function fire(command,_debug)
        local arguments = {parse_command(command)}
        local progname = table.remove(arguments, 1)


        local child = spawn(progname,arguments)
        if _debug then
                local function onExit (code, signal)
                        p(progname,arguments)
                        p('exit',code,signal)
                end
                local function onClose (code, signal)
                        p(progname,arguments)
                        p('close',code,signal)
                end
                child:on('exit', onExit)
                child:on('close', onClose)
        end
        child:on('error', function (err)
                print('ERROR',err)
        end)
end

local function loadtab(crontab,_debug)
        if _debug then
                print(string.format('%-10s %-10s %-10s %-10s %-10s %s',
                        'Minutes', 'Hours', 'DayOfMon', 'Months', 'DayOfWeek', 'Process/Command'))
        end
        local function parse_entry(line)
                local pattern = '(.-)%s+(.-)%s+(.-)%s+(.-)%s+(.-)%s+(.+)';

                local ret,_, min, hour, day, month, wday,cmd = string.find(line,pattern)
                if ret then
                        return  { min, hour, day, month, wday,cmd,line}
                end
                return nil
        end

        local f = assert(io.open(crontab,'r'))
        local entries = {}
        for l in f:lines() do
                entry = parse_entry(l:gsub('#.*',''))
                if entry then
                        entries[#entries+1] = entry
                else
                        print('!!!Invalid:',l)
                end
        end
        f:close()
        return entries
end

local Crond = Emitter:extend()
function Crond:initialize(options)
        options = options or {}
        options.interval = options.interval or 10
        options.crontab = options.crontab or '/etc/crontab'
        options.debug = true
        self.debug = options.debug

        self.tasks = loadtab(options.crontab,options.debug)
        self.options = options
end

function Crond:start()
        self.interval = timer.setInterval(self.options.interval * 1000, function(entries)
                local now = os.time()
                local _t = os.date('*t',now)
                _t.sec = nil
                local _ = os.time(_t)
                if self._tick == _ then
                        return
                end
                self._tick = _
                for _,v in ipairs(entries) do
                        if check(v, _t) then
                                fire(v[6], self.debug)
                        end
                end
        end,self.tasks)
end

function Crond:stop(cb)
        self.interval:destroy(cb)
end

function Crond:status()
end


local M = {}
M.start = function(options)
        local crond = Crond:new(options)
        crond:start()
        return crond
end

M.stop = function(crond)
        assert(crond)
        crond:stop()
end

M.restart = function(crond)
        crond:stop(function()
                crond:start()
        end)
end

M.new = function(options)
        local crond = Crond:new(options)
end

return M
