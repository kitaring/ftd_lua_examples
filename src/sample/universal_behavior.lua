Behavior = {
  current_phase = nil,
}

function Behavior.update(self, I)

  local status = SelfAwareness:get_instance(I):get_status(I)
  if status.aimode == 'off' then
    return false
  end

  if not self.current_phase then
    self.current_phase = Takeoff.new(I)
  end
  self.current_phase = self.current_phase:update(I)
  return true
end
