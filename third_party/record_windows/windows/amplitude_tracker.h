#pragma once

#include <windows.h>

namespace record_windows {

struct AmplitudeTracker {
	double current = -160.0;
	double peak    = -160.0;

	void update(const BYTE* chunk, DWORD size);
	void reset();
};

} // namespace record_windows
