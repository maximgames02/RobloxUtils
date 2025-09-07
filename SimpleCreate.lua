local Create = {}

Create.__index = Create

Create.E = function(eventName)
	return {__eventname = eventName}
end

local objectsById = {}
local pendingIdLinks = {}

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

local function Create_PrivImpl(DebugMode)
	--
	return function(dat)
		objectsById = {}
		pendingIdLinks = {}

		local allObjects = collectObjectsRecursive(dat, nil)

		table.sort(allObjects, function(a, b)
			return a.ID < b.ID
		end)

		for _, entry in ipairs(allObjects) do
			local obj:Object = nil
			local data = entry.Data
			local parent = nil
			local ctor = nil

			pcall(function() obj = Instance.new(entry.Classname) end)

			if obj ~= nil then
				for k, v in pairs(data) do
					if type(k) == 'string' then
						if k == "Parent" then
							parent = v
						elseif k == "Tags" then
							for _, tag in ipairs(v) do
								game:GetService("CollectionService"):AddTag(obj, tostring(tag))
							end
						elseif k == "Attributes" then
							for attrName, attrValue in pairs(v) do
								obj:SetAttribute(attrName, attrValue)
							end
						elseif k == "Children" then
							--
						else
							if type(v) == "string" and v:match("^PathID:%d+$") then
								local id = tonumber(v:match("%d+"))
								if id then
									pendingIdLinks[obj] = pendingIdLinks[obj] or {}
									pendingIdLinks[obj][k] = id
								end
							else
								pcall(function()
									obj[k] = v
								end)
							end
						end
					elseif type(k) == 'number' then
						--
					elseif type(k) == 'table' and k.__eventname then
						if type(v) ~= 'function' then
							error("Bad entry in Create body: Key `[Create.E\'"..k.__eventname.."\']` must have a function value\
							got: "..tostring(v), 2)
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
					if obj:IsA("LocalScript") then
						if k == "Source" then
							local ok, err = pcall(function()
								loadstring(v)
							end)
							if not ok then
								print(err)
							end
						end
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
				if DebugMode then
					print(string.format("Creating: [%d] = %s", entry.ID, tostring(obj)))
				end
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

		for obj, props in pairs(pendingIdLinks) do
			for propName, refId in pairs(props) do
				local ref = objectsById[refId]
				if ref and ref.Object then
					pcall(function()
						obj[propName] = ref.Object
					end)
				else
					warn("[Create] Объект с ID " .. tostring(refId) .. " не найден для свойства \"" .. tostring(propName) .. "\"")
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

return Create
