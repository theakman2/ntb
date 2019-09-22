cppbinary(
	"foo",
	{
		ccompile("foo.c"),
		cppcompile("bar.cpp"),
	}
);