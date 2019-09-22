#include "./api.h"

#include "../sublib2/api.h"

int lib2a(void) {
	return 124 - sublib2b();
}
