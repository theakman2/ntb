return cbinary(
	"bin2",
	{
		ccompile{"main.c"},
		import("lib1"),
		import("lib2"),
		import("sublib1"),
		import("sublib1/nested"),
		import("sublib2"),
	}
);