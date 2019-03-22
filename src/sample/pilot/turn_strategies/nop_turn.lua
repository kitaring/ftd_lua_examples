--[[
  何もしない旋回戦略
]]--
NopTurn = {}

function NopTurn.new()

  local this = {
  }

  --[[
    target(TargetWrapper)へ向かって旋回する
  ]]--
  this.turn_to = function(self, I, target)
  end

  return this
end
