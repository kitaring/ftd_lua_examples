Throttle = {
  instance = nil
}

-- 簡易的なシングルトン
function Throttle.get_instance(self)
  if not self.instance then
    self.instance = self.new()
  end
  return self.instance
end


function Throttle.new()
  local this = {
  }

  this.set = function(self, I, drive)
    -- 9：propulsion
    local count = Components:get_component_count(I, 9)
    for index=0, count-1 do
      local bi = Components:get_block_info(I, 9, index)
      self:set_drive(I, index, drive)
    end
  end

  this.set_drive = function(self, I, index, force)
    -- 手動入力分のAirDriveやWaterDriveが存在すると勝手に加速してしまう問題の対応
    local current_force = I:Component_GetFloatLogic_1(9, index, 1)
    
    -- 手動入力分を減算した上で、AIによる入力分を加算する
    I:Component_SetFloatLogic_1(9, index, 1, -current_force)
    I:Component_SetFloatLogic_1(9, index, 1, force)
  end

  return this
end