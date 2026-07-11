#pragma once

#include <windows.h>
#include <mfidl.h>
#include <mfapi.h>
#include <mferror.h>
#include <string>

#include "record_config.h"

namespace record_windows {
namespace MediaType {

HRESULT CreateInputProfile(const RecordConfig& config, IMFMediaType** ppType);
HRESULT CreateOutputProfile(const RecordConfig& config, IMFMediaType** ppType);
HRESULT FillWavHeader(const std::wstring& path, IMFMediaType* pMediaType, DWORD dataWritten);

} // namespace MediaType
} // namespace record_windows
