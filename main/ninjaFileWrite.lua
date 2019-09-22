local common = require('ntb.common');

local function ruleSorter(a, b)
	return a[1] < b[1];
end

return function(ninjaDetails, outputDirectory)
	local out = {};

	table.insert(out, "builddir = " .. outputDirectory .. "\n");

	-- Generate the rules.
	for _, pair in ipairs(ninjaDetails.rules) do
		local name = pair[1];
		local rule = pair[2];
		table.insert(out, "rule " .. name .. "\n");
		local pieces = {};
		for key, val in pairs(rule) do
			table.insert(pieces, {key, val});
		end
		table.sort(pieces, ruleSorter);
		for _, piece in ipairs(pieces) do
			table.insert(out, "  " .. piece[1] .. " = " .. piece[2] .. "\n");
		end
	end

	-- Generate the builds.
	for _, build in ipairs(ninjaDetails.builds) do
		table.insert(out, build);
	end

	-- Generate the 'defaults'
	if #ninjaDetails.defaults > 0 then
		table.insert(out, "default " .. common.ninjaEscapePaths(ninjaDetails.defaults) .. "\n");
	end

	-- Write the ninja file
	local ninjaString = table.concat(out, "");
	local outFile = path.join(outputDirectory, "build.ninja");
	
	dir.makepath(outputDirectory);
	local f = io.open(outFile, "w");
	f:write(ninjaString);
	f:close();
end;