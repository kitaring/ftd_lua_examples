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
