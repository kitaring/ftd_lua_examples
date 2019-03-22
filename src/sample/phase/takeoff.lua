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