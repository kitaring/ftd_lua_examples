--{{ENVIRONMENT}}

--{{self_awareness}}
--{{commons_functions}}
--{{components}}
--{{pilot_guidance}}
--{{target_wrapper}}
--{{cruise}}
--{{takeoff}}
--{{throttle}}
--{{vehicle_controller}}
--{{roll_base_turn}}
--{{nop_turn}}
--{{airplane_pilot}}
--{{universal_behavior}}


function Update(I)
  local self_awareness = SelfAwareness:get_instance(I)
  self_awareness:update(I)
  
  if Behavior:update(I) then
    I:TellAiThatWeAreTakingControl()
  end
end
