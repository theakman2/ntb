local function ninjaEscape(str)
	return (string.gsub(str, "[$: ]", "$%1"));
end

local function ninjaEscapePaths(filePaths)
	local ret = {};
	for _, fp in ipairs(filePaths) do
		table.insert(ret, ninjaEscape(fp));
	end
	return table.concat(ret, " ");
end

local function ins(tbl, items)
	if not items then
		return;
	end
	if type(items) ~= "table" then
		items = {items};
	end
	for _, item in ipairs(items) do
		if item and item ~= "" then
			table.insert(tbl, item);
		end
	end
end

local function flattenRaw(tbl, into)
	if type(tbl) == "nil" then
		return;
	end
	if type(tbl) ~= "table" then
		table.insert(into, tbl);
		return;
	end
	for _, item in ipairs(tbl) do
		flattenRaw(item, into);
	end
end

local function flatten(tbl)
	local ret = {};
	flattenRaw(tbl, ret);
	return ret;
end

local function reverseUniq(items, into)
	local dedup = {};
	local map = {};
	for i = #items, 1, -1 do
		local item = items[i];
		if not map[item] then
			map[item] = true;
			table.insert(dedup, item);
		end
	end
	for i = #dedup, 1, -1 do
		table.insert(into, dedup[i]);
	end
end

local function stringifyItemRaw(item, into)
	local kind = type(item);
	if kind == "table" then
		table.insert(into, '\001');
		local kvs = {};
		for k, v in pairs(item) do
			table.insert(kvs, {k, v});
		end
		table.sort(kvs, function(a, b) return tostring(a[1]) < tostring(b[1]); end);
		for _, kv in ipairs(kvs) do
			table.insert(into, '\002');
			stringifyItemRaw(kv[1], into);
			table.insert(into, '\003');
			stringifyItemRaw(kv[2], into);
			table.insert(into, '\004');
		end
		table.insert(into, '\005');
	else
		table.insert(into, '\006' .. kind .. '\007' .. tostring(item) .. '\008');
	end
end

local function stringifyItem(item)
	local parts = {};
	stringifyItemRaw(item, parts);
	return table.concat(parts, '');
end

local function hashItem(item)
	return hash(stringifyItem(item));
end

local function getOutputPath(inputFile, subDir)
	local rel;
	if inputFile:sub(1, 1) == "/" then
		rel = inputFile:sub(2);
	elseif inputFile:match("^%a:\\") then
		rel = inputFile:sub(4);
	end
	return path.join(ntb.buildDirectory, subDir, rel);
end

return {
	ninjaEscape = ninjaEscape;
	ninjaEscapePaths = ninjaEscapePaths;
	ins = ins;
	flatten = flatten;
	reverseUniq = reverseUniq;
	hashItem = hashItem;
	getOutputPath = getOutputPath;
};