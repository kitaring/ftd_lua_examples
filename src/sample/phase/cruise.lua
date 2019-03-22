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
