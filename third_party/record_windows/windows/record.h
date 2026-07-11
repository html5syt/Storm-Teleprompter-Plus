#pragma once

#include <windows.h>
#include <mfidl.h>
#include <mfapi.h>
#include <mferror.h>
#include <Mfreadwrite.h>

#include <assert.h>

#include "utils.h"
#include "record_config.h"
#include "event_stream_handler.h"
#include "amplitude_tracker.h"

namespace record_windows
{
	enum RecordState {
		pause, record, stop
	};

	class Recorder : public IMFSourceReaderCallback
	{
	public:
		static HRESULT CreateInstance(EventStreamHandler<>* stateEventHandler, EventStreamHandler<>* recordEventHandler, Recorder** recorder);

		Recorder(EventStreamHandler<>* stateEventHandler, EventStreamHandler<>* recordEventHandler);
		virtual ~Recorder();

		void SetOnConfigChanged(std::function<void(const RecordConfig&)> callback);

		HRESULT Start(std::unique_ptr<RecordConfig> config, std::wstring path);
		HRESULT StartStream(std::unique_ptr<RecordConfig> config);
		HRESULT Pause();
		HRESULT Resume();
		HRESULT Stop();
		HRESULT Cancel();
		bool IsPaused();
		bool IsRecording();
		HRESULT Dispose();
		std::map<std::string, double> GetAmplitude();
		std::wstring GetRecordingPath();
		// IUnknown methods
		STDMETHODIMP QueryInterface(REFIID iid, void** ppv);
		STDMETHODIMP_(ULONG) AddRef();
		STDMETHODIMP_(ULONG) Release();

		// IMFSourceReaderCallback methods
		STDMETHODIMP OnReadSample(HRESULT hrStatus, DWORD dwStreamIndex, DWORD dwStreamFlags, LONGLONG llTimestamp, IMFSample* pSample);
		STDMETHODIMP OnEvent(DWORD, IMFMediaEvent*);
		STDMETHODIMP OnFlush(DWORD);

	private:
		HRESULT CreateAudioCaptureDevice(LPCWSTR pszEndPointID);
		HRESULT CreateSourceReaderAsync();
		HRESULT CreateSinkWriter(std::wstring path);

		HRESULT InitRecording(std::unique_ptr<RecordConfig> config);
		void UpdateState(RecordState state);
		HRESULT EndRecording();

		long                m_nRefCount;
		CritSec             m_critsec;

		IMFMediaSource*            m_pSource;
		IMFPresentationDescriptor* m_pPresentationDescriptor;
		IMFSourceReader*           m_pReader;
		IMFSinkWriter*             m_pWriter;
		IMFMediaType*              m_pMediaType;
		std::wstring               m_recordingPath;
		bool                       m_mfStarted = false;

		bool     m_bFirstSample = true;
		bool     m_bResuming    = false;
		LONGLONG m_llBaseTime   = 0;
		LONGLONG m_llLastTime   = 0;

		AmplitudeTracker m_amplitude;
		DWORD            m_dataWritten = 0;

		EventStreamHandler<>* m_stateEventHandler;
		EventStreamHandler<>* m_recordEventHandler;
		std::function<void(const RecordConfig&)> m_onConfigChanged;

		RecordState                m_recordState = RecordState::stop;
		std::unique_ptr<RecordConfig> m_pConfig;
	};
};
