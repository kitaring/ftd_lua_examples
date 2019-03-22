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


