--==== START ENVIRONMENT ====--
-- メインフレームのインデックス
MAIN_FRAME = 0

-- 旋回処理の実装。一般的な航空機用のロールとピッチアップでの旋回を選択
TURN_STRATEGY = 'roll_base'

--==== END ENVIRONMENT ====--

--==== START self_awareness.lua ====--
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
--==== END self_awareness.lua ====--
--==== START commons_functions.lua ====--
--[[ 
  汎用的な関数の定義
]]--


function sqr_distance(p1, p2)
  return (p1 - p2).sqrMagnitude
end
--==== END commons_functions.lua ====--
--==== START components.lua ====--
--[[
  I:Component～系の結果やBlockInfoをキャッシュする。キャッシュの生存期間は1ターン
]]--
Components = {
  block_info_store = {},
  component_count = {},
  updated_at = -1
}

function Components.update(self, I)
  local status = SelfAwareness:get_instance(I):get_status(I)
  if status.current_turn ~= self.updated_at then
    self.block_info_store = {}
    self.component_count = {}
    self.updated_at = status.current_turn
  end
end

function Components.find_by_name(self, I, type, name)
  self:update(I)
  local result = {}
  local component_count = self:get_component_count(I, type)
  for i=0, component_count-1 do
    local bi = self:get_block_info(I, type, i)
    if bi and bi.CustomName == name then
      result[#result+1] = i
    end
  end
  return result
end

function Components.get_component_count(self, I, type)
  self:update(I)
  local component_count = self.component_count[type]
  if not component_count then
    component_count = I:Component_GetCount(type)
    self.component_count[type] = component_count
  end
  return component_count
end


function Components.get_block_info(self, I, type, index)
  self:update(I)
  local store = self.block_info_store[type]
  if not store then
    store = {}
    self.block_info_store[type] = store
  end

  local bi = store[index]
  if not bi then
    bi = I:Component_GetBlockInfo(type, index)
    store[index] = bi
  end
  return bi
end


--==== END components.lua ====--
--==== START pilot_guidance.lua ====--
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
--==== END pilot_guidance.lua ====--
--==== START target_wrapper.lua ====--
--[[
  様々な目標地点（target）における、頻繁に参照する項目について、1ターン中に何度も計算する必要が無いように、本クラスのインスタンスに保持する。
  また、様々な目標の種類（任意の地点、敵ビークル、味方ビークル、敵ミサイル、味方のミサイル等）を同じインターフェースで扱えるようラップする。

  ※この実装はサンプルなので上記要件は満たしていない

]]--
TargetWrapper = {}

function TargetWrapper.new(target)
  local this = {
    guidance = nil,
  }
  this.entity = target

  this.get_guidance = function(self, I)
    if not self.guidance then
      local status = SelfAwareness:get_instance(I):get_status(I)
      self.guidance = PilotGuidance.new(status.com, self.entity)
    end
    return self.guidance
  end

  --[[
    ターゲットが前方ならtrueを返す
  ]]--
  this.is_target_ahead = function(self, I)
    local status = SelfAwareness:get_instance(I):get_status(I)

    --[[
      status.forward の元となる、I:GetConstructForwardVector() はビークルの前後ではなく、進行方向に対しての前方1ブロックを返す事に注意が必要
      つまり以下の実装では後退している場合は前後が逆に判定される。

      解決策としては、ビークルの重心よりも前方に名前付きのブロックを配置し、重心位置と同ブロックの位置関係でビークルの前側を識別できるようにする等
    ]]-- 
    return sqr_distance(self.entity, status.com + status.forward) < sqr_distance(self.entity, status.com - status.forward)
  end


  return this
end
--==== END target_wrapper.lua ====--
--==== START cruise.lua ====--
--[[
  サンプルの巡行フェーズ
  初期リソースゾーン付近と、そこから北に2000メートル付近の間を往復する
]]--
Cruise = {

  -- サンプルの巡行コース。初期リソースゾーン付近と同地点から北へ2キロ地点の往復。
  WAYPOINTS = {
    Vector3(0, 240, 0),
    Vector3(0, 240, 2000),
  }
}

function Cruise.new(I)
  local this = {
    pilot = Pilot:get_instance(),
    waypoints = {},
  }


  this.update = function(self, I)
    if self:is_crashed(I) then
      -- 墜落状態を検知したら離陸フェーズに戻る
      return Takeoff.new(I)
    end

    if #self.waypoints == 0 then
      -- ウェイポイントを一巡したらリストを初期化する
      self.waypoints = {unpack(Cruise.WAYPOINTS)}
    end
    local waypoint = self.waypoints[1]

    -- ウェイポイントに向かって旋回
    -- 例えば敵機を追いかける時は、ここに敵ビークルの位置を指定する。
    self.pilot:turn_to(I, TargetWrapper.new(waypoint))

    local status = SelfAwareness:get_instance(I):get_status(I)
    if sqr_distance(status.com, self.waypoints[1]) < 240*240 then
      -- ウェイポイントにある程度接近したら次のウェイポイントに切り替える
      table.remove(self.waypoints, 1)
    end
    
    return self
  end

  --[[
    墜落を検知した場合にtrueを返す。
    サンプルなので単に高度のみをチェックする。
  ]]--
  this.is_crashed = function(self, I)
    local status = SelfAwareness:get_instance(I):get_status(I)
    return status.com.y <= status.terrain_alt
  end

  
  return this
end
--==== END cruise.lua ====--
--==== START takeoff.lua ====--
--[[
  サンプルの離陸フェーズ
  単にバルーンを展開する
]]--
Takeoff = {}

function Takeoff.new(I)
  local this = {
    throttle = Throttle:get_instance()
  }

  this.update = function(self, I)

    local status = SelfAwareness:get_instance(I):get_status(I)

    -- サンプルなので単純に高度だけを見て離陸完了を判断する
    if status.com.y > 80 then
      -- 離陸が完了したら巡行フェーズへ移行
      I:SeverAllBalloons()
      return Cruise.new(I)
    end

    I:DeployAllBalloons()
    if status.pitch < 22.5 then
      -- 下向きに加速しないようピッチアングルが小さい場合はエンジンを止める
      self.throttle:set(I, 0)
    else
      self.throttle:set(I, 1.0)
    end

    -- 離陸処理を続行
    return self
  end

  return this
end
--==== END takeoff.lua ====--
--==== START throttle.lua ====--
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
--==== END throttle.lua ====--
--==== START vehicle_controller.lua ====--
VehicleController = {
  instance = nil
}

function VehicleController.get_instance(self)
  if not self.instance then
    self.instance = self.new()
  end
  return self.instance
end

function VehicleController.new()

  local this = {
  }
  

  this.pitch_up = function(self, I, force)
    for i=1, #SelfAwareness.CONTROL_MODES do
      I:RequestControl(SelfAwareness.CONTROL_MODES[i], 4, force)
    end
  end

  this.pitch_down = function(self, I, force)
    for i=1, #SelfAwareness.CONTROL_MODES do
      I:RequestControl(SelfAwareness.CONTROL_MODES[i], 5, force)
    end
  end

  this.up = function(self, I, force)
    EventDispachers:on(I, {name='set_thruster_angle_vertical_up', force=force})
  end

  this.down = function(self, I, force)
    EventDispachers:on(I, {name='set_thruster_angle_vertical_down', force=force})
  end



  this.yaw_right = function(self, I, force)
    for i=1, #SelfAwareness.CONTROL_MODES do
      I:RequestControl(SelfAwareness.CONTROL_MODES[i], 1, force)
    end
  end
  this.yaw_left = function(self, I, force)
    for i=1, #SelfAwareness.CONTROL_MODES do
      I:RequestControl(SelfAwareness.CONTROL_MODES[i], 0, force)
    end
  end

  this.roll_left = function(self, I, force)
    for i=1, #SelfAwareness.CONTROL_MODES do
      I:RequestControl(SelfAwareness.CONTROL_MODES[i], 2, force)
    end
  end

  this.roll_right = function(self, I, force)
    for i=1, #SelfAwareness.CONTROL_MODES do
      I:RequestControl(SelfAwareness.CONTROL_MODES[i], 3, force)
    end
  end



  return this
end
--==== END vehicle_controller.lua ====--
--==== START roll_base_turn.lua ====--
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
--==== END roll_base_turn.lua ====--
--==== START nop_turn.lua ====--
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
--==== END nop_turn.lua ====--
--==== START airplane_pilot.lua ====--
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
--==== END airplane_pilot.lua ====--
--==== START universal_behavior.lua ====--
--[[
  メイン処理から呼び出される行動の起点
  離陸 → 巡行 → 戦闘 → 着陸
  等のフェーズを処理する

  ※本サンプルでは離陸と巡行フェーズのみ実装
]]--
Behavior = {
  current_phase = nil,
}

function Behavior.update(self, I)

  local status = SelfAwareness:get_instance(I):get_status(I)
  if status.aimode == 'off' then
    return false
  end

  -- ビークルのロード直後は離陸フェーズから開始する
  if not self.current_phase then
    self.current_phase = Takeoff.new(I)
  end
  self.current_phase = self.current_phase:update(I)
  return true
end
--==== END universal_behavior.lua ====--


function Update(I)
  local self_awareness = SelfAwareness:get_instance(I)
  self_awareness:update(I)
  
  if Behavior:update(I) then
    I:TellAiThatWeAreTakingControl()
  end
end