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
