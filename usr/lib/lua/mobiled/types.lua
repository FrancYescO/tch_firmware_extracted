local M = {}

function M.constant(result)
	return function(path, value)
		return true, result
	end
end

function M.invalid()
	return function(path, value)
		if value ~= nil then
			return false, string.format("%s should not exist", path)
		end
		return true, nil
	end
end

function M.string(pattern)
	return function(path, value)
		if type(value) ~= "string" then
			return false, string.format("%s is not a string", path)
		end
		if pattern and not value:match(pattern) then
			return false, string.format("%s does not match '%s'", path, pattern)
		end
		return true, value
	end
end

function M.integer(minimum_value, maximum_value)
	return function(path, value)
		if type(value) ~= "number" then
			return false, string.format("%s is not a number", path)
		end
		if value % 1 ~= 0 then
			return false, string.format("%s is not an integer", path)
		end
		if minimum_value and minimum_value > value or maximum_value and maximum_value < value then
			return false, string.format("%s is out-of-range", path)
		end
		return true, value
	end
end

function M.real(minimum_value, maximum_value)
	return function(path, value)
		if type(value) ~= "number" then
			return false, string.format("%s is not a number", path)
		end
		if minimum_value and minimum_value > value or maximum_value and maximum_value < value then
			return false, string.format("%s is out-of-range", path)
		end
		return true, value
	end
end

function M.number_string(number_type, base)
	return function(path, value)
		if type(value) == "string" then
			value = tonumber(value, base or 10)
			if not value then
				return false, string.format("%s is not a number", path)
			end
		end
		return number_type(path, value)
	end
end

function M.boolean()
	return function(path, value)
		if type(value) ~= "boolean" then
			return false, string.format("%s is not a boolean", path)
		end
		return true, value
	end
end

function M.truth()
	return function(path, value)
		return true, not not value
	end
end

function M.boolean_string()
	return function(path, value)
		if type(value) == "string" then
			local lower_value = value:match("^%s*(.-)%s*$"):lower()
			if lower_value == "true" or  lower_value == "yes" or lower_value == "1" then
				return true, true
			elseif lower_value == "false" or lower_value == "no" or lower_value == "0" then
				return true, false
			end
		elseif value == 0 or value == false then
			return true, false
		elseif value == 1 or value == true then
			return true, true
		end
		return false, string.format("%s is not a boolean string", path)
	end
end

function M.choice(options)
	return function(path, value)
		local chosen_option = options[value]
		if not chosen_option then
			return false, string.format("%s is not a valid choice", path)
		end
		return true, chosen_option
	end
end

function M.optional(optional_type, default_value)
	return function(path, value)
		if value == nil then
			return true, default_value
		end
		return optional_type(path, value)
	end
end

function M.protected(protected_type, error_result)
	return function(path, value)
		local success, result = protected_type(path, value)
		if not success then
			result = error_result
		end
		return true, result
	end
end

function M.either(...)
	local possible_types = {...}

	return function(path, value)
		local error_messages = {}
		for _, possible_type in ipairs(possible_types) do
			local success, result = possible_type(path, value)
			if success then
				return true, result
			end
			table.insert(error_messages, result)
		end
		return false, table.concat(error_messages, " and ")
	end
end

function M.transformed(transform, transformed_type)
	return function(path, value)
		local success, result = transformed_type(path, value)
		if not success then
			return false, result
		end
		return true, transform(result)
	end
end

function M.dictionary(member_types)
	return function(path, value)
		if type(value) ~= "table" then
			return false, string.format("%s is not a table", path)
		end

		local result = {}
		for member_key, member_type in pairs(member_types) do
			local member_value = value[member_key]
			local member_success, member_result = member_type(string.format("member %s of %s", tostring(member_key), path), member_value)
			if not member_success then
				return false, member_result
			end
			result[member_key] = member_result
		end

		return true, result
	end
end

function M.list(element_type)
	return function(path, value)
		if type(value) ~= "table" then
			return false, string.format("%s is not a table", path)
		end

		local result = {}
		for element_index, element_value in pairs(value) do
			local element_success, element_result = element_type(string.format("element %s of %s", tostring(element_index), path), element_value)
			if not element_success then
				return false, element_result
			end
			result[element_index] = element_result
		end

		return true, result
	end
end

return M
