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