-- Keeps track of the current owner.
--
-- The current owner is the component who should own any components
-- that are currently being constructed
do
  local ReactCurrentOwner = {
    current = nil
  }
  return ReactCurrentOwner
end
