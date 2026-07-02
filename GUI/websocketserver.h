#pragma once

#include "../host/textthread.h"

// Broadcasts extracted text to any browser connected over WebSocket.
// Fully isolated from the extraction/hook pipeline: callers just call the
// functions below, nothing outside this file touches a socket directly.
namespace WebSocketServer
{
	// Settings, loaded from and saved to Textractor.ini by the GUI (see
	// GUI/mainwindow.cpp), same pattern as TextThread::flushDelay/Host::defaultCodepage.
	inline bool enabled = true;
	inline int port = 47892;
	inline bool logging = false;
	inline std::wstring originWhitelist; // comma separated Origin headers; empty = allow all

	// (Re)starts the server using the settings above. Always safe to call -
	// stops any existing server first, and does nothing further if disabled.
	void Start();
	void Stop();

	// Broadcasts one extracted line to all connected clients as a "line" message.
	void BroadcastLine(TextThread& thread, const std::wstring& text);

	// Broadcasts a "status" message reflecting whether any game is attached.
	void NotifyProcessAttached();
	void NotifyProcessDetached();
}
