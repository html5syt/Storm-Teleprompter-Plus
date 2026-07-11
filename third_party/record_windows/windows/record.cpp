#include "record.h"
#include "record_audio_device.h"
#include "record_mediatype.h"
#include "record_windows_plugin.h"

namespace record_windows
{
	// static
	HRESULT Recorder::CreateInstance(EventStreamHandler<>* stateEventHandler, EventStreamHandler<>* recordEventHandler, Recorder** ppRecorder)
	{
		auto pRecorder = new (std::nothrow) Recorder(stateEventHandler, recordEventHandler);

		if (pRecorder == NULL)
		{
			return E_OUTOFMEMORY;
		}

		// The Recorder constructor sets the ref count to 1.
		*ppRecorder = pRecorder;

		return S_OK;
	}

	Recorder::Recorder(EventStreamHandler<>* stateEventHandler, EventStreamHandler<>* recordEventHandler)
		: m_nRefCount(1),
		m_critsec(),
		m_pConfig(nullptr),
		m_pSource(NULL),
		m_pReader(NULL),
		m_pWriter(NULL),
		m_pPresentationDescriptor(NULL),
		m_stateEventHandler(stateEventHandler),
		m_recordEventHandler(recordEventHandler),
		m_recordingPath(std::wstring()),
		m_pMediaType(NULL)
	{
	}

	Recorder::~Recorder()
	{
		Dispose();
	}

	void Recorder::SetOnConfigChanged(std::function<void(const RecordConfig&)> callback)
	{
		m_onConfigChanged = std::move(callback);
	}

	HRESULT Recorder::Start(std::unique_ptr<RecordConfig> config, std::wstring path)
	{
		bool supported = false;
		HRESULT hr = AudioDevice::IsEncoderSupported(config->encoderName, &supported);

		if (FAILED(hr) || !supported)
		{
			return E_NOTIMPL;
		}

		hr = InitRecording(std::move(config));

		if (SUCCEEDED(hr))
		{
			m_recordingPath = path;
			hr = CreateSinkWriter(path);
		}
		if (SUCCEEDED(hr))
		{
			// Request the first sample
			hr = m_pReader->ReadSample((DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM,
				0,
				NULL, NULL, NULL, NULL
			);
		}
		if (SUCCEEDED(hr))
		{
			UpdateState(RecordState::record);
		}
		else
		{
			EndRecording();
		}

		return hr;
	}

	HRESULT Recorder::StartStream(std::unique_ptr<RecordConfig> config)
	{
		if (config->encoderName != AudioEncoder::pcm16bits)
		{
			return E_NOTIMPL;
		}

		HRESULT hr = InitRecording(std::move(config));

		if (SUCCEEDED(hr))
		{
			// Request the first sample
			hr = m_pReader->ReadSample((DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM,
				0,
				NULL, NULL, NULL, NULL
			);
		}
		if (SUCCEEDED(hr))
		{
			UpdateState(RecordState::record);
		}
		else
		{
			EndRecording();
		}

		return hr;
	}

	HRESULT Recorder::InitRecording(std::unique_ptr<RecordConfig> config)
	{
		HRESULT hr = EndRecording();

		if (SUCCEEDED(hr) && !m_mfStarted)
		{
			hr = MFStartup(MF_VERSION, MFSTARTUP_NOSOCKET);
		}
		if (SUCCEEDED(hr))
		{
			m_mfStarted = true;
			const int origSampleRate  = config->sampleRate;
			const int origNumChannels = config->numChannels;
			const int origBitRate     = config->bitRate;
			AudioDevice::AdjustConfigToDeviceCaps(*config);
			hr = AudioDevice::AdjustConfigToCodecCaps(*config);
			if (SUCCEEDED(hr) && m_onConfigChanged &&
				(config->sampleRate  != origSampleRate ||
				 config->numChannels != origNumChannels ||
				 config->bitRate     != origBitRate))
			{
				m_onConfigChanged(*config);
			}
		}
		if (SUCCEEDED(hr))
		{
			m_pConfig = std::move(config);
		}

		if (SUCCEEDED(hr))
		{
			if (m_pConfig->deviceId.length() != 0)
			{
				auto deviceId = std::wstring(m_pConfig->deviceId.begin(), m_pConfig->deviceId.end());
				hr = CreateAudioCaptureDevice(deviceId.c_str());
			}
			else
			{
				hr = CreateAudioCaptureDevice(NULL);
			}
		}
		if (SUCCEEDED(hr))
		{
			hr = CreateSourceReaderAsync();
		}

		return hr;
	}

	HRESULT Recorder::Pause()
	{
		HRESULT hr = S_OK;

		if (m_pSource)
		{
			hr = m_pSource->Pause();

			if (SUCCEEDED(hr))
			{
				UpdateState(RecordState::pause);
			}
		}

		return hr;
	}

	HRESULT Recorder::Resume()
	{
		HRESULT hr = S_OK;

		if (m_pSource)
		{
			PROPVARIANT var;
			PropVariantInit(&var);
			var.vt = VT_EMPTY;

			hr = m_pSource->Start(m_pPresentationDescriptor, NULL, &var);

			if (SUCCEEDED(hr))
			{
				m_bResuming = true;
			}
		}

		return hr;
	}

	HRESULT Recorder::Stop()
	{
		if (m_dataWritten == 0)
		{
			return Cancel();
		}

		HRESULT hr = EndRecording();

		if (SUCCEEDED(hr))
		{
			UpdateState(RecordState::stop);
		}

		return hr;
	}

	HRESULT Recorder::Cancel()
	{
		auto recordingPath = GetRecordingPath();
		HRESULT hr = EndRecording();

		if (SUCCEEDED(hr))
		{
			UpdateState(RecordState::stop);

			if (!recordingPath.empty())
			{
				DeleteFile(recordingPath.c_str());
			}
		}

		return hr;
	}

	bool Recorder::IsPaused()
	{
		switch (m_recordState)
		{
		case RecordState::pause:
			return true;
		default:
			return false;
		}
	}

	bool Recorder::IsRecording()
	{
		switch (m_recordState)
		{
		case RecordState::record:
			return true;
		default:
			return false;
		}
	}

	HRESULT Recorder::EndRecording()
	{
		AutoLock lock(m_critsec);
		HRESULT hr = S_OK;

		// Release reader callback first
		SafeRelease(m_pReader);

		if (m_pSource)
		{
			hr = m_pSource->Stop();

			if (SUCCEEDED(hr))
			{
				hr = m_pSource->Shutdown();
			}
		}

		if (m_pWriter)
		{
			hr = m_pWriter->Finalize();
		}

		if (m_pConfig && m_pConfig->encoderName == AudioEncoder::wav) {
			MediaType::FillWavHeader(m_recordingPath, m_pMediaType, m_dataWritten);
		}

		m_bFirstSample = true;
		m_bResuming    = false;
		m_llBaseTime   = 0;
		m_llLastTime   = 0;

		m_amplitude.reset();
		m_dataWritten = 0;

		if (m_mfStarted)
		{
			hr = MFShutdown();
			if (SUCCEEDED(hr))
			{
				m_mfStarted = false;
			}
		}

		SafeRelease(m_pSource);
		SafeRelease(m_pPresentationDescriptor);
		SafeRelease(m_pWriter);
		SafeRelease(m_pMediaType);
		m_pConfig = nullptr;
		m_recordingPath = std::wstring();

		return hr;
	}

	HRESULT Recorder::Dispose()
	{
		HRESULT hr = EndRecording();

		m_stateEventHandler = nullptr;
		m_recordEventHandler = nullptr;
		m_onConfigChanged = nullptr;

		return hr;
	}

	void Recorder::UpdateState(RecordState state)
	{
		m_recordState = state;

		if (m_stateEventHandler) {
			// Capture raw pointer and check before calling. This is minimal and
			// mirrors previous behavior with a quick null check on the main thread.
			EventStreamHandler<>* handlerPtr = m_stateEventHandler;
			RecordWindowsPlugin::RunOnMainThread([handlerPtr, state]() -> void {
				handlerPtr->Success(std::make_unique<flutter::EncodableValue>(state));
			});
		}
	}

	HRESULT Recorder::CreateAudioCaptureDevice(LPCWSTR deviceId)
	{
		IMFAttributes* pAttributes = NULL;

		HRESULT hr = MFCreateAttributes(&pAttributes, 2);

		// Set the device type to audio.
		if (SUCCEEDED(hr))
		{
			hr = pAttributes->SetGUID(
				MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
				MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_AUDCAP_GUID
			);
		}

		// Set the endpoint ID.
		if (SUCCEEDED(hr) && deviceId)
		{
			hr = pAttributes->SetString(
				MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_AUDCAP_ENDPOINT_ID,
				deviceId
			);
		}

		// Create the source
		if (SUCCEEDED(hr))
		{
			hr = MFCreateDeviceSource(pAttributes, &m_pSource);
		}
		// Create presentation descriptor to handle Resume action
		if (SUCCEEDED(hr))
		{
			hr = m_pSource->CreatePresentationDescriptor(&m_pPresentationDescriptor);
		}

		SafeRelease(&pAttributes);
		return hr;
	}

	HRESULT Recorder::CreateSourceReaderAsync()
	{
		HRESULT hr = S_OK;
		IMFAttributes* pAttributes = NULL;
		IMFMediaType* pMediaTypeIn = NULL;

		hr = MFCreateAttributes(&pAttributes, 1);
		if (SUCCEEDED(hr))
		{
			hr = pAttributes->SetUnknown(MF_SOURCE_READER_ASYNC_CALLBACK, this);
		}
		if (SUCCEEDED(hr))
		{
			hr = MFCreateSourceReaderFromMediaSource(m_pSource, pAttributes, &m_pReader);
		}
		if (SUCCEEDED(hr))
		{
			hr = MediaType::CreateInputProfile(*m_pConfig, &pMediaTypeIn);
		}
		if (SUCCEEDED(hr))
		{
			hr = m_pReader->SetCurrentMediaType(0, NULL, pMediaTypeIn);
		}

		SafeRelease(&pMediaTypeIn);
		SafeRelease(&pAttributes);
		return hr;
	}

	HRESULT Recorder::CreateSinkWriter(std::wstring path)
	{
		IMFSinkWriter* pSinkWriter = NULL;
		IMFMediaType* pMediaTypeOut = NULL;
		IMFMediaType* pMediaTypeIn = NULL;
		DWORD          streamIndex = 0;

		HRESULT hr = MFCreateSinkWriterFromURL(path.c_str(), NULL, NULL, &pSinkWriter);

		// Set the output media type.
		if (SUCCEEDED(hr))
		{
			hr = MediaType::CreateOutputProfile(*m_pConfig, &pMediaTypeOut);
		}
		if (SUCCEEDED(hr))
		{
			hr = pSinkWriter->AddStream(pMediaTypeOut, &streamIndex);
		}

		// Set the input media type.
		if (SUCCEEDED(hr))
		{
			hr = m_pReader->GetCurrentMediaType(streamIndex, &pMediaTypeIn);
		}
		if (SUCCEEDED(hr))
		{
			hr = pSinkWriter->SetInputMediaType(streamIndex, pMediaTypeIn, NULL);
		}

		// Tell the sink writer to Start accepting data.
		if (SUCCEEDED(hr))
		{
			hr = pSinkWriter->BeginWriting();
		}

		if (SUCCEEDED(hr))
		{
			m_pWriter = pSinkWriter;
			m_pWriter->AddRef();
			m_pMediaType = pMediaTypeOut;
			m_pMediaType->AddRef();
		}

		SafeRelease(&pSinkWriter);
		SafeRelease(&pMediaTypeOut);
		SafeRelease(&pMediaTypeIn);

		return hr;
	}

	std::map<std::string, double> Recorder::GetAmplitude()
	{
		return {
			{"current", m_amplitude.current},
			{"max"    , m_amplitude.peak},
		};
	}

	std::wstring Recorder::GetRecordingPath()
	{
		return m_recordingPath;
	}

};
