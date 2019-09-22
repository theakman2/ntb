local common = require('ntb.common');

local ninjaFileBuilderMt = {};

local function getNinjaBuildCmd_(explicitOutputs, rule, inputs, implicitDependencies, orderOnlyDependencies, implicitOutputs, vars)
	local into = {};
	table.insert(into, "build " .. common.ninjaEscapePaths(explicitOutputs));

	if implicitOutputs and #implicitOutputs > 0 then
		table.insert(into, " | " .. common.ninjaEscapePaths(implicitOutputs));
	end
	
	table.insert(into, ": " .. rule);

	if inputs and #inputs > 0 then
		table.insert(into, " " .. common.ninjaEscapePaths(inputs));
	end

	if implicitDependencies and #implicitDependencies > 0 then -- Implicit dependencies
		table.insert(into, " | " .. common.ninjaEscapePaths(implicitDependencies));
	end
	
	if orderOnlyDependencies and #orderOnlyDependencies > 0 then -- Order-only dependencies
		table.insert(into, " || " .. common.ninjaEscapePaths(orderOnlyDependencies));
	end

	table.insert(into, "\n");

	if vars and #vars > 0 then
		for _, kv in ipairs(vars) do
			table.insert(into, '  ' .. kv[1] .. ' = ' .. kv[2] .. '\n');
		end
	end

	return table.concat(into, '');
end

ninjaFileBuilderMt.rule = function(self, spec)
	if type(spec) == "string" then
		spec = {
			command = spec;
		};
	end
	if type(spec) ~= "table" then
		error("rule must be a string or table");
	end
	if type(spec.command) ~= "string" then
		error("rule command must be a string");
	end
	local existingRule = self.rulesByCommand[spec.command];
	if existingRule then
		return existingRule[1];
	end
	local name = 'r' .. self.rulesCounter;
	self.rulesCounter = self.rulesCounter + 1;
	local r = {name, spec};
	self.rulesByCommand[spec.command] = r;
	self.rulesByName[name] = r;
	table.insert(self.rules, r);
	return name;
end;

local function getNinjaBuildCmd_(explicitOutputs, rule, inputs, implicitDependencies, orderOnlyDependencies, implicitOutputs, vars)
	local into = {};
	table.insert(into, "build " .. common.ninjaEscapePaths(explicitOutputs));

	if implicitOutputs and #implicitOutputs > 0 then
		table.insert(into, " | " .. common.ninjaEscapePaths(implicitOutputs));
	end
	
	table.insert(into, ": " .. rule);

	if inputs and #inputs > 0 then
		table.insert(into, " " .. common.ninjaEscapePaths(inputs));
	end

	if implicitDependencies and #implicitDependencies > 0 then -- Implicit dependencies
		table.insert(into, " | " .. common.ninjaEscapePaths(implicitDependencies));
	end
	
	if orderOnlyDependencies and #orderOnlyDependencies > 0 then -- Order-only dependencies
		table.insert(into, " || " .. common.ninjaEscapePaths(orderOnlyDependencies));
	end

	table.insert(into, "\n");

	if vars and #vars > 0 then
		for _, kv in ipairs(vars) do
			table.insert(into, '  ' .. kv[1] .. ' = ' .. kv[2] .. '\n');
		end
	end

	return table.concat(into, '');
end

local function build_(self, output, rule, input, deps, odeps, implicitOutputs, vars)
	if not output then
		error("output not provided");
	end
	if type(output) ~= "string" and type(output) ~= "table" then
		error("output must be a string or table of strings (" .. type(output) .. " provided)");
	end
	if type(output) == "string" then
		output = { output };
	end
	table.sort(output);

	if not rule then
		error("rule not provided");
	end
	if type(rule) ~= "string" then
		error("rule must be a string");
	end

	if not input then
		input = {};
	end
	if type(input) ~= "string" and type(input) ~= "table" then
		error("input must be a string or table of strings (" .. type(input) .. " provided)");
	end
	if type(input) == "string" then
		input = { input };
	end
	table.sort(input);

	if deps then
		if type(deps) ~= "string" and type(deps) ~= "table" then
			error("dependencies must be a string or table of strings (" .. type(deps) .. " provided)");
		end
		if type(deps) == "string" then
			deps = { deps };
		end
		table.sort(deps);
	end

	if odeps then
		if type(odeps) ~= "string" and type(odeps) ~= "table" then
			error("order-only dependencies must be a string or table of strings (" .. type(odeps) .. " provided)");
		end
		if type(odeps) == "string" then
			odeps = { odeps };
		end
		table.sort(odeps);
	end

	if implicitOutputs then
		if type(implicitOutputs) ~= "string" and type(implicitOutputs) ~= "table" then
			error("implicit outputs must be a string or table of strings (" .. type(implicitOutputs) .. " provided)");
		end
		if type(implicitOutputs) == "string" then
			implicitOutputs = { implicitOutputs };
		end
		table.sort(implicitOutputs);
	end

	local buildCmd = getNinjaBuildCmd_(output, rule, input, deps, odeps, implicitOutputs, vars);

	local insert = true;
	for _, out in ipairs(output) do
		local existing = self.buildsByOutput[out];
		if existing then
			if existing.buildCmd ~= buildCmd then
				error("duplicate build rule detected - attempting to build '" .. out .. "' in [" .. tostring(ntb.scriptPath) .. "] but already built this output in [" .. tostring(existing.location) .. "]");
			end
			insert = false;
		else
			self.buildsByOutput[out] = {
				location = ntb.scriptPath;
				buildCmd = buildCmd;
			};
		end
	end

	if insert then
		table.insert(self.builds, buildCmd);
	end
end

ninjaFileBuilderMt.build = function(self, output, rule, input, deps, odeps, implicitOutputs, vars)
	if rule ~= "phony" and not self.rulesByName[rule] then
		error("rule '" .. tostring(rule) .. "' not found");
	end
	build_(self, output, rule, input, deps, odeps, implicitOutputs, vars);
end;

ninjaFileBuilderMt.phony = function(self, output, input, deps, odeps, implicitOutputs)
	build_(self, output, "phony", input, deps, odeps, implicitOutputs);
end

ninjaFileBuilderMt.default = function(self, targets)
	if not targets then
		error("targets not provided");
	end
	if type(targets) ~= "string" and type(targets) ~= "table" then
		error("targets must be a string or table of strings (" .. type(targets) .. " provided)");
	end
	if type(targets) == "string" then
		targets = { targets };
	end
	for _, target in ipairs(targets) do
		table.insert(self.defaults, target);
	end
end

ninjaFileBuilderMt.registerGlobals = function(self)
	_G.rule = func.bind1(self.rule, self);
	_G.build = func.bind1(self.build, self);
	_G.phony = func.bind1(self.phony, self);
	_G.default = func.bind1(self.default, self);
end;

local function ninjaFileBuilderCreate()
	return setmetatable(
		{
			rules = {};
			rulesByName = {};
			rulesByCommand = {};
			rulesCounter = 1;
			builds = {};
			buildsByOutput = {};
			defaults = {};
		},
		{
			__index = ninjaFileBuilderMt;
		}
	);
end

return ninjaFileBuilderCreate;