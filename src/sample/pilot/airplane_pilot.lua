Pilot = {
  instance = nil,
}

-- 簡易的なシングルトン
function Pilot.get_instance(self)
  if not self.instance then
    self.instance = self.new()
  end
  return self.instance
end

function Pilot.new() 
  local this = {
    throttle = Throttle:get_instance(),
    vehicle_controller = VehicleController:get_instance(),
    turn_strategies = {}
  }
  this.turn_strategies = {}
  this.turn_strategies['roll_base'] = RollBaseTurn.new()
  this.turn_strategies['nop'] = NopTurn.new()
  
  --[[
    TURN_STRATEGYで設定した旋回戦略を用いて
    target（TargetWrapper）に向かって旋回する
  ]]--
  this.turn_to = function(self, I, target)
    local turn_strategy = self.turn_strategies[TURN_STRATEGY]
    turn_strategy:turn_to(I, target)
    self.throttle:set(I, 1.0)
  end

  return this
end