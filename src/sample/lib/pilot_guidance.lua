PilotGuidance = {}

--[[
  目標への誘導
  target_positionに指定した位置へ機首を向けたい場合、  get_desire..() が指示する方向にエルロンやエレベーター、ラダーを動かす事で目標を正面に捉える事が出来る（目標が前方に存在する場合を想定）

  単に目標へ向かう場合は、my_vehicle_position は自機のCenterOfMassを指定する。
  例えば機銃掃射等で自機の重心位置ではなく、機体に取り付けられた特定の兵装の位置を基準としたい場合は、その兵装のWeaponInfo.GlobalFirePoint等を指定する。
    
  1目標に対して1インスタンスを作成し、オブジェクトの生存期間は1ターンの想定
]]--
function PilotGuidance.new(my_vehicle_position, target_position)
  local this = {
    -- ビークルの上下左右端から目標までの距離。都度計算する必要の無いようインスタンス変数に保持しておく。
    right_distance = -1,
    left_distance = -1,
    up_distance = -1,
    down_distance = -1,
    center_distance = -1,
    -- ビークルの中央から上下左右端とする位置までの距離。目標へ機首を合わせる際の正確さに影響する。
    span = 128,
  }
  this.my_vehicle_position = my_vehicle_position
  this.target_position = target_position

  -- 左右どちらにロールすべきか。.centerがtrueの場合は、ロール方向では概ね目標を中央に捉えている
  this.get_desire_roll = function(self, I)
    local roll = {}
    roll.right = self:get_right_distance(I) < self:get_left_distance(I)
    roll.center = self:get_center_distance(I) < math.min(self:get_right_distance(I), self:get_left_distance(I))
    return roll
  end

  -- ピッチアップとピッチダウン、どちらを行うべきか。.centerがtrueの場合は、ピッチ方向では概ね目標を中央に捉えている
  this.get_desire_pitch = function(self, I)
    local pitch = {}
    pitch.up = self:get_up_distance(I) < self:get_down_distance(I)
    pitch.center = self:get_center_distance(I) < math.min(self:get_up_distance(I), self:get_down_distance(I))
    return pitch
  end

  -- 左右どちらのラダーを蹴るべきか。.centerがtrueの場合は、ヨー方向では概ね目標を中央に捉えている
  this.get_desire_yaw = function(self, I)
    -- 現状ロールと同じ結果を返す
    return self:get_desire_roll(I)
  end

  -- trueの場合、ロール方向、ピッチ方向ともに概ね目標を中央に捉えている
  this.in_center = function(self, I)
    return self:get_desire_roll(I).center and self:get_desire_pitch(I).center
  end


  -- ビークルの右端と定義する位置
  this.get_right_wingtip = function(self, I)
    local status = SelfAwareness:get_instance():get_status(I)
    return self.my_vehicle_position + (status.right * self.span)
  end

  -- ビークルの左端と定義する位置
  this.get_left_wingtip = function(self, I)
    local status = SelfAwareness:get_instance():get_status(I)
    return self.my_vehicle_position + (-status.right * self.span)
  end

  -- ビークルの上端と定義する位置
  this.get_top = function(self, I)
    local status = SelfAwareness:get_instance():get_status(I)
    return self.my_vehicle_position + (status.up * self.span)
  end

  -- ビークルの下端と定義する位置
  this.get_bottom = function(self, I)
    local status = SelfAwareness:get_instance():get_status(I)
    return self.my_vehicle_position + (-status.up * self.span)
  end

  -- ビークルの中央から目標までの距離。都度計算する必要のないよう結果をキャッシュする
  this.get_center_distance = function(self, I)
    if self.center_distance < 0 then
      self.center_distance = sqr_distance(self.my_vehicle_position, self.target_position)
    end
    return self.center_distance
  end

  -- ビークルの右端から目標までの距離。都度計算する必要のないよう結果をキャッシュする
  this.get_right_distance = function(self, I)
    if self.right_distance < 0 then
      local status = SelfAwareness:get_instance():get_status(I)
      self.right_distance = sqr_distance(self.target_position, self.my_vehicle_position + status.right * self.span)
    end
    return self.right_distance
  end

  -- ビークルの左端から目標までの距離。都度計算する必要のないよう結果をキャッシュする
  this.get_left_distance = function(self, I)
    if self.left_distance < 0 then
      local status = SelfAwareness:get_instance():get_status(I)
      self.left_distance = sqr_distance(self.target_position, self.my_vehicle_position - status.right * self.span)
    end
    return self.left_distance
  end

  -- ビークルの上端から目標までの距離。都度計算する必要のないよう結果をキャッシュする
  this.get_up_distance = function(self, I)
    if self.up_distance < 0 then
      local status = SelfAwareness:get_instance():get_status(I)
      self.up_distance = sqr_distance(self.target_position, self.my_vehicle_position + status.up * self.span)
    end
    return self.up_distance
  end

  -- ビークルの下端から目標までの距離。都度計算する必要のないよう結果をキャッシュする
  this.get_down_distance = function(self, I)
    if self.down_distance < 0 then
      local status = SelfAwareness:get_instance():get_status(I)
      self.down_distance = sqr_distance(self.target_position, self.my_vehicle_position - status.up * self.span)
    end
    return self.down_distance
  end

  return this
end
