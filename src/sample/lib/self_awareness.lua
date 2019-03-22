--[[
  主に自機の状態を表す
  オブジェクトの生存期間はビークルが実体化されている間、常に1つだけのインスタンスが存在する想定
]]--
SelfAwareness = {
  instance = nil,
  MAX_TURN = 65535,
  DEFAULT_CRUISE_ALTITUDE = 360,
  CONTROL_MODES = {0, 1, 2},
}

--[[
  シングルトンの簡易的な実装
]]
function SelfAwareness.get_instance(self, I)
  if not self.instance then
    self.instance = self.new(I)
  end
  return self.instance
end

function SelfAwareness.new(I)
  local this = {
    -- ビークルのロード直後に1回だけ取得する値
    id = I:GetUniqueId(),
    spawnpoint = I:GetConstructCenterOfMass(),
    vehicle_size = I:GetConstructMaxDimensions() - I:GetConstructMinDimensions(),

    -- ビークルがロードされてから現在までの経過ターン数。update()呼び出し毎に加算される。
    current_turn = -1,

    -- ターン事に更新されるビークルの状態
    -- パフォーマンスの観点から同一ターン内で何度もI:Get～メソッドを呼び出さずに済むよう値を保持する
    status = {},
  }

  --[[
    from_turn から現在までの経過ターン数を返す
  ]]
  this.elapsed = function(self, from_turn)
    if from_turn <= self.current_turn then
      return self.current_turn - from_turn
    else
      -- ターン数が最大値に達してリセットされている状況
      return (SelfAwareness.MAX_TURN - from_turn) + self.current_turn
    end
  end


  this.update = function(self, I)
    
    if self.current_turn < SelfAwareness.MAX_TURN then
      self.current_turn = self.current_turn + 1
    else
      self.current_turn = 0
    end
    self.aimode = I.AIMode
  end

  this.get_status = function(self, I)
    self:update_status(I)
    return self.status
  end

  this.update_status = function(self, I)
    -- 同一ターン内で1回だけ更新する
    if self.status.updated_at == self.current_turn then
      return
    end

    local status = {}
    status.spawnpoint = self.spawnpoint
    status.updated_at = self.current_turn
    status.aimode = self.aimode
    status.current_turn = self.current_turn
    status.vehicle_size = self.vehicle_size

    status.health_fraction = I:GetHealthFraction()
    status.ammo_fraction = I:GetAmmoFraction()
    status.fuel_fraction = I:GetFuelFraction()
    
    status.com = I:GetConstructCenterOfMass()
    status.velocity = I:GetVelocityVector()
    status.velocity_normalized = I:GetVelocityVectorNormalized()
    status.speed = I:GetForwardsVelocityMagnitude()
    
    status.forward = I:GetConstructForwardVector()
    status.up = I:GetConstructUpVector()
    status.right = I:GetConstructRightVector()
    status.is_inverted_flight = status.com.y > (status.com + status.up).y

    status.angular = I:GetLocalAngularVelocity()
    status.roll = self:simplify_angle(I:GetConstructRoll())
    status.pitch = self:simplify_angle(I:GetConstructPitch())
    
    status.sea_floor = I:GetTerrainAltitudeForLocalPosition(0, 0, 0)
    status.terrain_alt = math.max(0, status.sea_floor)
    self.status = status
  end

  -- 角度の表現を0から360ではなく-180から180で表現する
  -- 例えばピッチ角なら
  -- 水平時がゼロ、機首下げ状態は負、機首上げ状態を正の値となる
  this.simplify_angle = function(self, angle)
    local value = math.min(angle, math.abs(angle - 360))
    if angle < 180 then
      value = -value
    end
    return value
  end

  return this
end
