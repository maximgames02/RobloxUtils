local Create = {}

Create.__index = Create

Create.E = function(eventName)
	return {__eventname = eventName}
end

local objectsById = {}

local function collectObjectsRecursive(item, parentId, list)
	list = list or {}

	if type(item) == "table" and type(item.Classname) == "string" then
		table.insert(list, {
			ID = item.ID or 0,
			Data = item,
			Classname = item.Classname,
			ParentId = parentId
		})

		if type(item.Children) == "table" then
			for _, child in ipairs(item.Children) do
				collectObjectsRecursive(child, item.ID, list)
			end
		end
	end

	return list
end

local function Create_PrivImpl(objectType)
	if type(objectType) ~= 'string' then
		error("Argument of Create must be a string", 2)
	end

	return function(dat)
		objectsById = {}

		local allObjects = collectObjectsRecursive(dat, nil)

		table.sort(allObjects, function(a, b)
			return a.ID < b.ID
		end)

		for _, entry in ipairs(allObjects) do
			local obj = nil
			local data = entry.Data
			local parent = nil
			local ctor = nil
			
			pcall(function() obj = Instance.new(entry.Classname) end)
			if obj ~= nil then
				for k, v in pairs(data) do
					if type(k) == 'string' then
						if k == "Parent" then
							parent = v
						elseif k == "Children" then
							--
						else
							pcall(function() obj[k] = v end)
						end
					elseif type(k) == 'number' then
					elseif type(k) == 'table' and k.__eventname then
						if type(v) ~= 'function' then
							error("Bad event entry: " .. tostring(k.__eventname))
						end
						pcall(function() obj[k.__eventname]:Connect(v) end)
					elseif k == Create then
						if type(v) ~= 'function' then
							error("Bad constructor entry")
						elseif ctor then
							error("Only one constructor allowed")
						end
						ctor = v
					else
						error("Unknown key in Create: " .. tostring(k))
					end
				end

				if ctor then
					ctor(obj)
				end

				objectsById[entry.ID] = {
					Object = obj,
					ParentId = entry.ParentId,
					ManualParent = parent
				}
				print(`Creating: [{entry.ID}] = {obj}`)
			end
		end

		for id, info in pairs(objectsById) do
			local obj = info.Object
			if obj ~= nil then
				local parent = info.ManualParent or (info.ParentId and objectsById[info.ParentId] and objectsById[info.ParentId].Object)

				if parent then
					obj.Parent = parent
				end
			end
		end

		return (objectsById[0] and objectsById[0].Object)
	end
end

setmetatable(Create, {
	__call = function(_, ...)
		return Create_PrivImpl(...)
	end
})

function Create.Init()
	return Create
end

return Create.Init()
