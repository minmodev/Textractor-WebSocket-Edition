# WebSocket server

This fork adds a built-in WebSocket server so a browser can receive extracted
text directly from Textractor, without a separate bridge application.

```
Game -> Textractor -> WebSocket server -> Browser (ws://127.0.0.1:47892)
```

## Server lifecycle

* The server starts automatically when Textractor's main window is created,
  and stops when Textractor exits (`GUI/mainwindow.cpp` calls
  `WebSocketServer::Start()` / `WebSocketServer::Stop()`).
* It listens on `127.0.0.1` only - it is never reachable from another machine.
* Changing WebSocket settings in the Settings dialog and clicking "Save
  settings" restarts the server immediately with the new settings (stops the
  old listener and any connected clients, then re-listens).
* If the configured port can't be bound (e.g. already in use), Textractor
  logs a message to its console/output pane and the server stays off until
  you fix the port and save settings again. Everything else in Textractor
  keeps working normally.
* All networking lives in `GUI/websocketserver.h`/`.cpp`. The extraction and
  hook pipeline (`texthook/`, `host/`) never links against Qt's WebSocket
  module or knows the server exists; the GUI's `SentenceReceived` callback
  (`GUI/mainwindow.cpp`) makes exactly one call,
  `WebSocketServer::BroadcastLine(thread, sentence)`, after extensions have
  processed the line.

## Configuration

Settings live in `Textractor.ini` (same file as every other Textractor
setting) and are editable from the Settings dialog:

| Setting | Default | Meaning |
|---|---|---|
| Enable WebSocket server | on | Master on/off switch. Textractor works exactly as before if disabled. |
| WebSocket server port | `47892` | TCP port to listen on, localhost only. |
| WebSocket allowed origins | *(blank)* | Comma-separated list of allowed `Origin` header values, e.g. `https://mywebsite.com`. Blank allows any origin - fine for a purely local tool, but tighten this if you're worried about other local webpages/tabs connecting in. |
| Log WebSocket connections | off | Logs client connect/disconnect/rejection to Textractor's console pane. Server start/stop and listen failures are always logged regardless of this setting. |

## Message protocol

Connect from a browser with:

```javascript
const socket = new WebSocket("ws://127.0.0.1:47892");
socket.onmessage = (event) => {
  const message = JSON.parse(event.data);
  switch (message.type) {
    case "connected": /* handshake, includes protocol version */ break;
    case "status":    /* "attached" | "waiting" */ break;
    case "line":      /* one extracted line */ break;
    case "error":     /* something the server wants you to know */ break;
  }
};
```

The connection is one-way: Textractor broadcasts, it does not expect the
client to send anything. If a client does send data, the server replies with
an `error` message explaining that.

### `connected`

Sent once, immediately after a client connects.

```json
{ "type": "connected", "version": "1.0.0" }
```

### `status`

Sent to a newly connected client (reflecting current state), and again to all
clients whenever a game process attaches or detaches.

```json
{ "type": "status", "status": "waiting" }
```

`status` is `"attached"` if at least one game process is currently attached,
otherwise `"waiting"`.

### `line`

Sent for every extracted line, from every hook/thread (not just the one
currently shown in Textractor's window), after extensions (translation,
filters, etc.) have run.

```json
{
  "type": "line",
  "id": 1542,
  "speaker": "Dialogue",
  "thread": "Dialogue",
  "text": "Hello.",
  "timestamp": 1751482300
}
```

* `id` - sequential counter, starting at 1 each time the server (re)starts.
* `thread` - the Textractor hook/thread name (what you'd see in Textractor's
  thread dropdown), e.g. `"Console"`, `"Clipboard"`, or a name derived from
  the hook.
* `speaker` - currently always the same value as `thread`. Textractor has no
  built-in concept of a "speaking character" separate from the hook that
  produced the text, so this field is not fabricated data - it mirrors
  `thread` today. It's kept as its own field (rather than dropped) so a
  client-side integration doesn't have to change if a future extension adds
  real speaker detection.
* `timestamp` - Unix epoch seconds, at broadcast time.

### `error`

```json
{ "type": "error", "message": "..." }
```

Currently only sent in reply to a client that sends unexpected data.

## Extension points

The protocol is intentionally forward-compatible: every message has a `type`
field, so a client should ignore message types it doesn't recognize instead
of erroring. To add a new message type, add a small builder function next to
`BroadcastLine` in `GUI/websocketserver.cpp` (see how `BroadcastLine` and
`NotifyProcessAttached`/`NotifyProcessDetached` build their JSON) and call it
from wherever the new event happens - one function call, same as
`BroadcastLine`. Don't reuse the `"line"`/`"status"`/`"connected"`/`"error"`
type strings for anything else; existing clients switch on them.

## Example browser client

See [`docs/websocket-client-test.html`](websocket-client-test.html) - a
single self-contained HTML file, no build step. Open it directly in a
browser (or serve it however you like) while Textractor is running.
