--[[ Minimal assertion helpers shared by the test files. ]]

local H = {}

H.failures = 0
H.passed = 0

local function fmt(v)
	if type(v) == "table" then
		local parts = {}
		for i = 1, #v do
			parts[#parts + 1] = tostring(v[i])
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

function H.ok(condition, label)
	if condition then
		H.passed = H.passed + 1
		print("  ok   " .. label)
	else
		H.failures = H.failures + 1
		print("  FAIL " .. label)
	end
	return condition
end

function H.equal(actual, expected, label)
	local same = actual == expected
	if not same then
		print("  FAIL " .. label)
		print("       expected: " .. fmt(expected))
		print("       actual:   " .. fmt(actual))
		H.failures = H.failures + 1
	else
		H.passed = H.passed + 1
		print("  ok   " .. label)
	end
	return same
end

function H.contains(list, value, label)
	for i = 1, #list do
		if list[i] == value then
			H.passed = H.passed + 1
			print("  ok   " .. label)
			return true
		end
	end
	print("  FAIL " .. label)
	print("       " .. fmt(value) .. " not in " .. fmt(list))
	H.failures = H.failures + 1
	return false
end

function H.notContains(list, value, label)
	for i = 1, #list do
		if list[i] == value then
			print("  FAIL " .. label)
			print("       " .. fmt(value) .. " unexpectedly in " .. fmt(list))
			H.failures = H.failures + 1
			return false
		end
	end
	H.passed = H.passed + 1
	print("  ok   " .. label)
	return true
end

function H.section(name)
	print("-- " .. name)
end

function H.summary()
	print(string.format("  (%d passed, %d failed)", H.passed, H.failures))
	return H.failures
end

return H
