#include "websocketserver.h"
#include "qtcommon.h"
#include "../host/host.h"
#include <QWebSocketServer>
#include <QWebSocket>
#include <QWebSocketCorsAuthenticator>
#include <QHostAddress>
#include <ctime>

extern const wchar_t* WEBSOCKET_LISTENING;
extern const wchar_t* WEBSOCKET_LISTEN_FAILED;
extern const wchar_t* WEBSOCKET_CLIENT_CONNECTED;
extern const wchar_t* WEBSOCKET_CLIENT_DISCONNECTED;
extern const wchar_t* WEBSOCKET_CLIENT_REJECTED;

namespace
{
	constexpr auto PROTOCOL_VERSION = "1.0.0";

	QWebSocketServer* server = nullptr;
	Synchronized<std::vector<QWebSocket*>> clients;
	std::atomic<int64_t> lineCounter = 0;
	std::atomic<int> attachedProcesses = 0;

	// Minimal JSON string escaping: converts to UTF-8, escapes the handful of
	// characters JSON requires, and drops other control characters. Multibyte
	// UTF-8 continuation bytes are all >= 0x80 so they pass through untouched.
	std::string JsonEscape(const std::wstring& text)
	{
		std::string out;
		for (unsigned char ch : WideStringToString(text))
			switch (ch)
			{
			case '"': out += "\\\""; break;
			case '\\': out += "\\\\"; break;
			case '\n': out += "\\n"; break;
			case '\r': out += "\\r"; break;
			case '\t': out += "\\t"; break;
			default: if (ch >= 0x20) out += ch;
			}
		return out;
	}

	// Queues the send on the socket's owning (GUI) thread and returns
	// immediately, so callers on other threads (e.g. TextThread's flush
	// timer) never block on network I/O.
	void Send(QWebSocket* client, const std::string& message)
	{
		QMetaObject::invokeMethod(client, [client, message] { client->sendTextMessage(QString::fromStdString(message)); });
	}

	void Broadcast(const std::string& message)
	{
		for (QWebSocket* client : clients.Copy()) Send(client, message);
	}

	std::vector<QString> OriginWhitelist()
	{
		std::vector<QString> whitelist;
		for (QString origin : S(WebSocketServer::originWhitelist).split(',', QString::SkipEmptyParts)) whitelist.push_back(origin.trimmed());
		return whitelist;
	}

	void OnClientDisconnected(QWebSocket* client)
	{
		auto locked = clients.Acquire();
		locked->erase(std::remove(locked->begin(), locked->end(), client), locked->end());
		if (WebSocketServer::logging) Host::AddConsoleOutput(FormatString(WEBSOCKET_CLIENT_DISCONNECTED, S(client->peerAddress().toString())));
		client->deleteLater();
	}

	void OnNewConnection()
	{
		while (server->hasPendingConnections())
		{
			QWebSocket* client = server->nextPendingConnection();
			clients->push_back(client);
			QObject::connect(client, &QWebSocket::disconnected, [client] { OnClientDisconnected(client); });
			QObject::connect(client, &QWebSocket::textMessageReceived, [client](const QString&)
			{
				// Protocol is broadcast-only; tell clients that send us anything so instead of silently ignoring them.
				Send(client, R"({"type":"error","message":"Textractor WebSocket server is broadcast-only; client messages are ignored."})");
			});
			if (WebSocketServer::logging) Host::AddConsoleOutput(FormatString(WEBSOCKET_CLIENT_CONNECTED, S(client->peerAddress().toString())));
			Send(client, FormatString(R"({"type":"connected","version":"%s"})", PROTOCOL_VERSION));
			Send(client, FormatString(R"({"type":"status","status":"%s"})", attachedProcesses.load() > 0 ? "attached" : "waiting"));
		}
	}

	void OnOriginAuthenticationRequired(QWebSocketCorsAuthenticator* authenticator)
	{
		auto whitelist = OriginWhitelist();
		bool allowed = whitelist.empty() || std::any_of(whitelist.begin(), whitelist.end(),
			[&](const QString& origin) { return origin.compare(authenticator->origin(), Qt::CaseInsensitive) == 0; });
		authenticator->setAllowed(allowed);
		if (!allowed && WebSocketServer::logging) Host::AddConsoleOutput(FormatString(WEBSOCKET_CLIENT_REJECTED, S(authenticator->origin())));
	}
}

namespace WebSocketServer
{
	void Stop()
	{
		if (!server) return;
		// Iterate a copy, not the locked list itself: close() may re-enter
		// OnClientDisconnected synchronously, which also locks clients.
		for (QWebSocket* client : clients.Copy()) { client->close(); client->deleteLater(); }
		clients->clear();
		server->close();
		server->deleteLater();
		server = nullptr;
	}

	void Start()
	{
		Stop();
		if (!enabled) return;

		lineCounter = 0;
		attachedProcesses = 0;
		server = new QWebSocketServer(QStringLiteral("Textractor"), QWebSocketServer::NonSecureMode);
		QObject::connect(server, &QWebSocketServer::newConnection, OnNewConnection);
		QObject::connect(server, &QWebSocketServer::originAuthenticationRequired, OnOriginAuthenticationRequired);

		if (server->listen(QHostAddress::LocalHost, port)) Host::AddConsoleOutput(FormatString(WEBSOCKET_LISTENING, port));
		else
		{
			Host::AddConsoleOutput(FormatString(WEBSOCKET_LISTEN_FAILED, port, S(server->errorString())));
			server->deleteLater();
			server = nullptr;
		}
	}

	void BroadcastLine(TextThread& thread, const std::wstring& text)
	{
		if (!server) return;
		std::string escapedThread = JsonEscape(thread.name);
		Broadcast(FormatString(
			R"({"type":"line","id":%I64d,"speaker":"%s","thread":"%s","text":"%s","timestamp":%I64d})",
			++lineCounter,
			escapedThread,
			escapedThread,
			JsonEscape(text),
			(int64_t)time(nullptr)
		));
	}

	void NotifyProcessAttached()
	{
		if (!server) return;
		Broadcast(FormatString(R"({"type":"status","status":"%s"})", ++attachedProcesses > 0 ? "attached" : "waiting"));
	}

	void NotifyProcessDetached()
	{
		if (!server) return;
		Broadcast(FormatString(R"({"type":"status","status":"%s"})", --attachedProcesses > 0 ? "attached" : "waiting"));
	}
}
