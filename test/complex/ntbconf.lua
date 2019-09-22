return {
	targets = {
		{
			name = "dbg";
			kind = "dbg";
			useForCompileCommands = true;
		},
		{
			name = "rel";
			kind = "rel";
			cflags = {
				"-Ofast",
				"-march=native",
				"-mtune=native",
			};
		},
	};
	projects = {
		"bin1",
		"bin2/build.ntb.lua",
	};
};
