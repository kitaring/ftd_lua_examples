--[[
  主にロールとピッチアップで旋回する
  一般的な航空機を想定
  サンプルなのでPID等は使わず、操作の入力値はON/OFF制御
]]--
RollBaseTurn = {}

function RollBaseTurn.new()

  local this = {
    vehicle_controller = VehicleController:get_instance()
  }

  --[[
    target(TargetWrapper)へ向かって旋回する
  ]]--
  this.turn_to = function(self, I, target)
    local guidance = target:get_guidance(I)
    if target:is_target_ahead(I) then
      -- ターゲットが前方に存在する場合の操縦
      if guidance:in_center(I) then
        -- ターゲットを真正面に捉えている場合のみロールとピッチを水平に戻す。
        -- pid等で入力値を調整できればこのような処理は不要となる。
        self:roll_angle_to_flat(I)  
        self:pitch_angle_to_flat(I)  
      else
        -- ターゲットが真正面に来るように操縦する
        self:adjust_roll(I, target, true)
        self:adjust_pitch(I, target)
      end
      self:adjust_yaw(I, target)
    else
      -- ターゲットが後方の場合は単にロール方向を合わせつつ目一杯操縦桿を引く
      local guidance = target:get_guidance(I)
      self.vehicle_controller:pitch_up(I, 1.0)
      self:adjust_roll(I, target, false)
    end
    
  end

  --[[

    allow_inversion引数について。 目標が腹側にある場合に、キャノピー側に来るまで反転するかどうかを指示する。
    例えば水平飛行時に目標が真正面下方に存在する場合、
    allow_inversion=trueなら、背面飛行でキャノピーを目標に向ける
    allow_inversion=falseなら、そのまま水平飛行を続ける
  ]]--
  this.adjust_roll = function(self, I, target, allow_inversion)
    local guidance = target:get_guidance(I)
    if not allow_inversion then
      if guidance:get_desire_roll(I).right then
        self.vehicle_controller:roll_right(I, 1.0)
      else
        self.vehicle_controller:roll_left(I, 1.0)
      end
      return
    end

    if guidance:get_desire_pitch(I).up or guidance:get_desire_pitch(I).center then
      -- 目標が正面、もしくは上に見える場合はguidanceの指示通りに（距離の近い翼端側へ）ロール
      if guidance:get_desire_roll(I).right then
        self.vehicle_controller:roll_right(I, 1.0)
      else
        self.vehicle_controller:roll_left(I, 1.0)
      end
    else
      -- 目標が機体の腹側に見える場合はキャノピー側に来るまで全力でロールする
      if guidance:get_desire_roll(I).right then
        self.vehicle_controller:roll_left(I, 1.0)
      else
        self.vehicle_controller:roll_right(I, 1.0)
      end
    end
  end


  this.adjust_pitch = function(self, I, target)
    local guidance = target:get_guidance(I)
    if guidance:get_desire_pitch(I).up then
      self.vehicle_controller:pitch_up(I, 1.0)
    else
      self.vehicle_controller:pitch_down(I, 1.0)
    end
  end


  this.adjust_yaw = function(self, I, target)
    local guidance = target:get_guidance(I)
    if guidance:get_desire_yaw(I).right then
      self.vehicle_controller:yaw_right(I, 1.0)
    else
      self.vehicle_controller:yaw_left(I, 1.0)
    end
  end

  --[[
    ロールアングルをとありえず水平付近に戻す簡易実装。
    PIDで制御すれば不要となる。
  ]]--
  this.roll_angle_to_flat = function(self, I)
    local status = SelfAwareness:get_instance(I):get_status(I)
    if math.abs(status.roll) < 4.0 then
      return
    end
    if status.roll < 0 then
      self.vehicle_controller:roll_right(I, 1.0)
    else
      self.vehicle_controller:roll_left(I, 1.0)
    end
  end

  --[[
    ロールアングルをとありえず水平付近に戻す簡易実装。
    PIDで制御すれば不要となる。
  ]]--
  this.pitch_angle_to_flat = function(self, I)
    local status = SelfAwareness:get_instance(I):get_status(I)
    if math.abs(status.pitch) < 4.0 then
      return
    end
    local status = SelfAwareness:get_instance(I):get_status(I)
    if status.pitch < 0 then
      self.vehicle_controller:pitch_up(I, 1.0)
    else
      self.vehicle_controller:pitch_down(I, 1.0)
    end
  end


  return this
end
