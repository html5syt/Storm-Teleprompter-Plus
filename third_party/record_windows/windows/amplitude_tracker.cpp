#include "amplitude_tracker.h"

#include <cmath>
#include <cstdint>
#include <vector>

namespace record_windows {

void AmplitudeTracker::update(const BYTE* chunk, DWORD size) {
	std::vector<int16_t> samples(size / 2);
	CopyMemory(samples.data(), chunk, size);

	int maxSample = 0;
	for (auto s : samples) {
		int v = std::abs((int)s);
		if (v > maxSample) maxSample = v;
	}

	current = 20.0 * std::log10(maxSample / 32767.0);
	if (current > peak) peak = current;
}

void AmplitudeTracker::reset() {
	current = -160.0;
	peak    = -160.0;
}

} // namespace record_windows
