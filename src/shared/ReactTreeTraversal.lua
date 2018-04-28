local ReactTypeOfWork = require "ReactTypeOfWork"
local HostComponent = ReactTypeOfWork.HostComponent

local function getParent(inst)
  repeat
    inst = inst["return"]
    -- TODO: If this is a HostRoot we might want to bail out.
    -- That is depending on if we want nested subtrees (layers) to bubble
    -- events to their parent. We could also go through parentNode on the
    -- host node but that wouldn't work for React Native and doesn't let us
    -- do the portal feature.
  until not (inst and inst.tag ~= HostComponent)
  if inst then
    return inst
  end
  return nil
end

-- Return the lowest common ancestor of A and B, or null if they are in
-- different trees.
local function getLowestCommonAncestor(instA, instB)
  local depthA = 0
  local tempA = instA
  while tempA do
    depthA = depthA + 1
    tempA = getParent(tempA)
  end

  local depthB = 0
  local tempB = instB
  while tempB do
    depthB = depthB + 1
    tempB = getParent(tempB)
  end

  -- If A is deeper, crawl up
  while depthA - depthB > 0 do
    instA = getParent(instA)
    depthA = depthA - 1
  end

  -- If B is deeper, crawl up
  while depthB - depthA > 0 do
    instB = getParent(instB)
    depthB = depthB - 1
  end

  -- Walk in lockstep until we find a match
  local depth = depthA
  while depth > 0 do
    if instA == instB or instA == instB.alternate then
      return instA
    end
    instA = getParent(instA)
    instB = getParent(instB)
  end

  return nil

end

-- Return if A is an ancestor of B
local function isAncestor(instA, instB)
  while instB do
    if instA == instB or instA == instB.alternate then
      return true
    end
    instB = getParent(instB)
  end
  return false
end

-- Return the parent instance of the passed-in instance
local function getParentInstance(inst)
  return getParent(inst)
end

-- Simulates the traversal of a two-phase, capture/bubble event dispatch
local function traverseTwoPhase(inst, fn, arg)
  local path = {}
  while inst do
    table.insert(path, inst)
    inst = getParent(inst)
  end
  local i = #path
  while i > 0 do
    fn(path[i], "captured", arg)
    i = i - 1
  end
  i = 1
  while i <= path.length do
    fn(path[i], "bubbled", arg)
    i = i + 1
  end
end

-- Traverses the ID hierarchy and invokes the supplied `cb` on any IDs that
-- should would receive a `mouseEnter` or `mouseLeave` event.
-- 
-- Does not invoke the callback on the nearest common ancestor because nothing
-- "entered" or "left" that element.
local function traverseEnterLeave(from, to, fn, argFrom, argTo)
  local common = from and to and getLowestCommonAncestor(from, to) or nil
  local pathFrom = {}
  while true do
    if not from then
      break
    end
    if from == common then
      break
    end
    local alternate = from.alternate
    if alternate ~= nil and alternate == common then
      break
    end
    table.insert(pathFrom, from)
    from = getParent(from)
  end

  local pathTo = {}
  while true do
    if not to then
      break
    end
    if to == common then
      break
    end
    local alternate = to.alternate
    if alternate ~= nil and alternate == common then
      break
    end
    table.insert(pathTo, to)
    to = getParent(to)
  end

  for i, item in ipairs(pathFrom) do
    fn(item, "bubbled", argFrom)
  end
  local i = #pathTo
  while i > 0 do
    fn(pathTo[i], "captured", argTo)
    i = i - 1
  end
end

return {
  traverseEnterLeave = traverseEnterLeave,
  getLowestCommonAncestor = getLowestCommonAncestor,
  isAncestor = isAncestor,
  getParentInstance = getParentInstance,
  traverseTwoPhase = traverseTwoPhase
}