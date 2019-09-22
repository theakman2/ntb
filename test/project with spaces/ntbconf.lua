return {
	targets = {
		{
			name = "t1";
			kind = "dbg";
		},
		{
			name = "t2";
			kind = "rel";
		},
	};
	projects = {
		"a/build.ntb.lua",
		"this is b/build.ntb.lua",
		"c/entry.ntb.lua",
	};
};
