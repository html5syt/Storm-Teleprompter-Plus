#include "record_mediatype.h"
#include "utils.h"

#pragma warning(disable: 4201)
#include <aviriff.h>

namespace record_windows {
namespace MediaType {

static HRESULT CreateAACProfile(const RecordConfig& config, IMFMediaType* pType)
{
	HRESULT hr = pType->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_AAC);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, config.sampleRate);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, config.numChannels);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AVG_BITRATE, config.bitRate);
	return hr;
}

static HRESULT CreateFlacProfile(const RecordConfig& config, IMFMediaType* pType)
{
	HRESULT hr = pType->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_FLAC);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, config.sampleRate);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, config.numChannels);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AVG_BITRATE, config.bitRate);
	return hr;
}

static HRESULT CreateAmrNbProfile(IMFMediaType* pType)
{
	HRESULT hr = pType->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_AMR_NB);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
	return hr;
}

static HRESULT CreateAmrWbProfile(IMFMediaType* pType)
{
	HRESULT hr = pType->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_AMR_WB);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
	return hr;
}

static HRESULT CreatePcmProfile(const RecordConfig& config, IMFMediaType* pType)
{
	const UINT32 bitsPerSample = 16;
	HRESULT hr = pType->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, bitsPerSample);

	UINT32 blockAlign     = config.numChannels * (bitsPerSample / 8);
	UINT32 bytesPerSecond = blockAlign * config.sampleRate;

	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, config.numChannels);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, config.sampleRate);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AUDIO_BLOCK_ALIGNMENT, blockAlign);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND, bytesPerSecond);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_ALL_SAMPLES_INDEPENDENT, TRUE);
	return hr;
}

HRESULT CreateInputProfile(const RecordConfig& config, IMFMediaType** ppType)
{
	IMFMediaType* pType = NULL;
	HRESULT hr = MFCreateMediaType(&pType);

	if (SUCCEEDED(hr)) hr = pType->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
	if (SUCCEEDED(hr)) hr = pType->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, config.sampleRate);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, config.numChannels);
	if (SUCCEEDED(hr)) hr = pType->SetUINT32(MF_MT_AVG_BITRATE, config.bitRate);
	if (SUCCEEDED(hr))
	{
		*ppType = pType;
		(*ppType)->AddRef();
	}

	SafeRelease(&pType);

	return hr;
}

HRESULT CreateOutputProfile(const RecordConfig& config, IMFMediaType** ppType)
{
	IMFMediaType* pType = NULL;
	HRESULT hr = MFCreateMediaType(&pType);

	if (SUCCEEDED(hr)) hr = pType->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
	if (SUCCEEDED(hr))
	{
		const auto& enc = config.encoderName;
		if      (enc == AudioEncoder::aacLc ||
		         enc == AudioEncoder::aacEld ||
		         enc == AudioEncoder::aacHe)        hr = CreateAACProfile(config, pType);
		else if (enc == AudioEncoder::amrNb)        hr = CreateAmrNbProfile(pType);
		else if (enc == AudioEncoder::amrWb)        hr = CreateAmrWbProfile(pType);
		else if (enc == AudioEncoder::flac)         hr = CreateFlacProfile(config, pType);
		else if (enc == AudioEncoder::pcm16bits ||
		         enc == AudioEncoder::wav)          hr = CreatePcmProfile(config, pType);
		else hr = E_NOTIMPL;
	}
	if (SUCCEEDED(hr))
	{
		*ppType = pType;
		(*ppType)->AddRef();
	}

	SafeRelease(&pType);
	
	return hr;
}

struct WAV_FILE_HEADER
{
	RIFFCHUNK    FileHeader;
	DWORD        fccWaveType;
	RIFFCHUNK    WaveHeader;
	WAVEFORMATEX WaveFormat;
	RIFFCHUNK    DataHeader;
};

HRESULT FillWavHeader(const std::wstring& path, IMFMediaType* pMediaType, DWORD dataWritten)
{
	WAVEFORMATEX* pWav = NULL;
	UINT cbSize = 0;
	DWORD cbWritten = 0;

	WAV_FILE_HEADER header;
	ZeroMemory(&header, sizeof(header));

	DWORD cbFileSize = dataWritten + sizeof(WAV_FILE_HEADER) - sizeof(RIFFCHUNK);

	HRESULT hr = MFCreateWaveFormatExFromMFMediaType(pMediaType, &pWav, &cbSize);

	if (SUCCEEDED(hr))
	{
		header.FileHeader.fcc = MAKEFOURCC('R', 'I', 'F', 'F');
		header.FileHeader.cb  = cbFileSize;
		header.fccWaveType    = MAKEFOURCC('W', 'A', 'V', 'E');
		header.WaveHeader.fcc = MAKEFOURCC('f', 'm', 't', ' ');
		header.WaveHeader.cb  = RIFFROUND(sizeof(WAVEFORMATEX));
		CopyMemory(&header.WaveFormat, pWav, sizeof(WAVEFORMATEX));
		header.DataHeader.fcc = MAKEFOURCC('d', 'a', 't', 'a');
		header.DataHeader.cb  = dataWritten;

		CoTaskMemFree(pWav);

		HANDLE hFile = CreateFile(path.c_str(),
			GENERIC_READ | GENERIC_WRITE, 0, NULL,
			OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);

		if (hFile == INVALID_HANDLE_VALUE)
		{
			printf("Record: Error when opening WAVE file.");
			return E_FAIL;
		}

		if (SetFilePointer(hFile, 0, NULL, FILE_BEGIN) == INVALID_SET_FILE_POINTER)
		{
			printf("Record: Error when seeking to start of WAVE file.");
			CloseHandle(hFile);
			return E_FAIL;
		}

		if (!WriteFile(hFile, (BYTE*)&header, sizeof(WAV_FILE_HEADER), &cbWritten, NULL))
		{
			printf("Record: Error when writing WAVE file RIFF header.");
			CloseHandle(hFile);
			return E_FAIL;
		}

		if (!CloseHandle(hFile))
		{
			printf("Record: Error when closing WAVE file.");
			return E_FAIL;
		}
	}

	return hr;
}

} // namespace MediaType
} // namespace record_windows
