local lpeg = require'lpeg'

local Q = lpeg.P('"')
local SP = lpeg.S(' \t')

local A = lpeg.P(1)-Q-SP
local SNODE = A^1
local QNODE = Q*(A+SP)^0*Q
local NODE = SNODE + QNODE

local Pattern = SP^0 * (lpeg.C(NODE) * SP^0)^0

local function parse (line)
  return Pattern:match(line)
end

return parse
