#pragma once

#include <windows.h>
#include <flutter/encodable_value.h>
#include <string>

#include "record_config.h"

namespace record_windows {
namespace AudioDevice {

HRESULT ListInputDevices(flutter::EncodableList& devices);
HRESULT IsEncoderSupported(const std::string& encoderName, bool* supported);
HRESULT AdjustConfigToDeviceCaps(RecordConfig& config);
HRESULT AdjustConfigToCodecCaps(RecordConfig& config);
void    WarmCodecCapsAsync();

} // namespace AudioDevice
} // namespace record_windows
