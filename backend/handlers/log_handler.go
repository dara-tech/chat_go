package handlers

import (
	"fmt"
	"io"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// ─────────────────────────────────────────────────────────────────────────────
// LogBroker — thread-safe SSE broadcaster
// ─────────────────────────────────────────────────────────────────────────────

// LogBroker holds connected SSE clients and fans out log lines to all of them.
type LogBroker struct {
	mu      sync.RWMutex
	clients map[chan string]struct{}
	buf     []string // ring buffer of recent lines (last 500)
}

// Global singleton — main.go calls NewLogBroker() once.
var GlobalLogBroker *LogBroker

func NewLogBroker() *LogBroker {
	return &LogBroker{
		clients: make(map[chan string]struct{}),
	}
}

// Publish sends a log line to all connected SSE clients and the ring buffer.
func (b *LogBroker) Publish(line string) {
	b.mu.Lock()
	defer b.mu.Unlock()

	// keep last 500 lines
	b.buf = append(b.buf, line)
	if len(b.buf) > 500 {
		b.buf = b.buf[len(b.buf)-500:]
	}

	for ch := range b.clients {
		select {
		case ch <- line:
		default: // slow client — drop rather than block
		}
	}
}

func (b *LogBroker) subscribe() chan string {
	ch := make(chan string, 128)
	b.mu.Lock()
	b.clients[ch] = struct{}{}
	b.mu.Unlock()
	return ch
}

func (b *LogBroker) unsubscribe(ch chan string) {
	b.mu.Lock()
	delete(b.clients, ch)
	b.mu.Unlock()
	close(ch)
}

// recentLines returns the buffered lines (snapshot) for replaying to new clients.
func (b *LogBroker) recentLines() []string {
	b.mu.RLock()
	defer b.mu.RUnlock()
	cp := make([]string, len(b.buf))
	copy(cp, b.buf)
	return cp
}

// ─────────────────────────────────────────────────────────────────────────────
// LogWriter — io.Writer that tees writes to LogBroker AND an inner writer
// ─────────────────────────────────────────────────────────────────────────────

// LogWriter wraps an existing io.Writer (os.Stderr/os.Stdout) and forwards
// every Write call to the broker so all log output is captured.
type LogWriter struct {
	inner  io.Writer
	broker *LogBroker
}

func NewLogWriter(inner io.Writer, broker *LogBroker) *LogWriter {
	return &LogWriter{inner: inner, broker: broker}
}

func (w *LogWriter) Write(p []byte) (n int, err error) {
	n, err = w.inner.Write(p)
	w.broker.Publish(string(p))
	return
}

// ─────────────────────────────────────────────────────────────────────────────
// LogHandler — HTTP handlers
// ─────────────────────────────────────────────────────────────────────────────

type LogHandler struct {
	broker    *LogBroker
	logSecret string
}

func NewLogHandler(broker *LogBroker, logSecret string) *LogHandler {
	return &LogHandler{broker: broker, logSecret: logSecret}
}

// authLog checks the ?secret= query param.
func (h *LogHandler) authLog(c *gin.Context) bool {
	if h.logSecret == "" {
		// No secret configured → deny access
		c.JSON(http.StatusForbidden, gin.H{"error": "Log access not configured (LOG_SECRET not set)"})
		return false
	}
	if c.Query("secret") != h.logSecret {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid log secret"})
		return false
	}
	return true
}

// ServeUI serves the embedded HTML dashboard at GET /admin/logs
func (h *LogHandler) ServeUI(c *gin.Context) {
	if !h.authLog(c) {
		return
	}
	c.Header("Content-Type", "text/html; charset=utf-8")
	c.Status(http.StatusOK)
	fmt.Fprint(c.Writer, logDashboardHTML)
}

// StreamSSE is the SSE endpoint at GET /logs/stream
func (h *LogHandler) StreamSSE(c *gin.Context) {
	if !h.authLog(c) {
		return
	}

	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")
	c.Header("X-Accel-Buffering", "no") // disable nginx buffering

	ch := h.broker.subscribe()
	defer h.broker.unsubscribe(ch)

	// Replay buffered lines first so the client sees recent history immediately
	for _, line := range h.broker.recentLines() {
		fmt.Fprintf(c.Writer, "data: %s\n\n", sseEscape(line))
	}
	c.Writer.Flush()

	ticker := time.NewTicker(25 * time.Second)
	defer ticker.Stop()

	ctx := c.Request.Context()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			// SSE keep-alive comment
			fmt.Fprint(c.Writer, ": ping\n\n")
			c.Writer.Flush()
		case line, ok := <-ch:
			if !ok {
				return
			}
			fmt.Fprintf(c.Writer, "data: %s\n\n", sseEscape(line))
			c.Writer.Flush()
		}
	}
}

// sseEscape replaces bare newlines inside a log line so the SSE frame stays valid.
func sseEscape(s string) string {
	out := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		if s[i] == '\n' && i < len(s)-1 {
			out = append(out, '\n')
			out = append(out, 'd', 'a', 't', 'a', ':', ' ')
		} else {
			out = append(out, s[i])
		}
	}
	return string(out)
}

// ─────────────────────────────────────────────────────────────────────────────
// Embedded HTML dashboard (single-file, zero JS deps)
// ─────────────────────────────────────────────────────────────────────────────

const logDashboardHTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>ChatGo · Server Logs</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  :root {
    --bg:       #0d1117;
    --surface:  #161b22;
    --border:   #30363d;
    --accent:   #58a6ff;
    --green:    #3fb950;
    --yellow:   #d29922;
    --red:      #f85149;
    --muted:    #8b949e;
    --text:     #e6edf3;
    --font:     'SF Mono', 'Fira Code', 'Consolas', monospace;
  }

  html, body { height: 100%; background: var(--bg); color: var(--text); font-family: var(--font); }

  /* ── Top bar ── */
  header {
    display: flex; align-items: center; gap: 12px;
    padding: 10px 18px;
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    position: sticky; top: 0; z-index: 10;
  }
  header .logo { font-size: 15px; font-weight: 700; color: var(--accent); letter-spacing: -0.3px; }
  header .badge {
    font-size: 11px; font-weight: 600; padding: 2px 8px;
    border-radius: 999px; background: rgba(63,185,80,.15); color: var(--green);
    border: 1px solid rgba(63,185,80,.35);
  }
  header .badge.offline { background: rgba(248,81,73,.12); color: var(--red); border-color: rgba(248,81,73,.3); }

  /* ── Controls ── */
  .controls {
    display: flex; align-items: center; gap: 8px; margin-left: auto; flex-wrap: wrap;
  }
  .controls input[type=text] {
    background: var(--bg); border: 1px solid var(--border); border-radius: 6px;
    color: var(--text); padding: 5px 10px; font: inherit; font-size: 12px; width: 180px;
    outline: none;
  }
  .controls input[type=text]:focus { border-color: var(--accent); }
  .controls select {
    background: var(--bg); border: 1px solid var(--border); border-radius: 6px;
    color: var(--text); padding: 5px 8px; font: inherit; font-size: 12px; outline: none;
  }
  .btn {
    background: var(--surface); border: 1px solid var(--border); border-radius: 6px;
    color: var(--text); padding: 5px 12px; font: inherit; font-size: 12px;
    cursor: pointer; transition: border-color .15s, color .15s;
  }
  .btn:hover { border-color: var(--accent); color: var(--accent); }
  .btn.danger:hover { border-color: var(--red); color: var(--red); }

  /* ── Stats strip ── */
  .stats {
    display: flex; gap: 20px; padding: 8px 18px;
    background: var(--surface); border-bottom: 1px solid var(--border);
    font-size: 11px; color: var(--muted);
  }
  .stats span b { color: var(--text); }

  /* ── Log pane ── */
  #log-pane {
    height: calc(100vh - 98px);
    overflow-y: auto;
    padding: 8px 4px;
    font-size: 12.5px;
    line-height: 1.55;
  }

  .log-line {
    display: flex; align-items: baseline; gap: 0;
    padding: 1px 14px;
    border-left: 3px solid transparent;
    white-space: pre-wrap; word-break: break-all;
    transition: background .1s;
  }
  .log-line:hover { background: rgba(255,255,255,.03); }

  /* level colouring */
  .log-line.ERROR  { border-left-color: var(--red);    color: var(--red);    background: rgba(248,81,73,.05); }
  .log-line.WARN   { border-left-color: var(--yellow);  color: var(--yellow); background: rgba(210,153,34,.05); }
  .log-line.INFO   { border-left-color: var(--green);   color: var(--green);  }
  .log-line.DEBUG  { border-left-color: var(--muted);   color: var(--muted);  }
  .log-line.hidden { display: none; }

  .ts { color: var(--muted); font-size: 11px; margin-right: 10px; flex-shrink: 0; }

  /* scroll anchor */
  #anchor { height: 1px; }
</style>
</head>
<body>

<header>
  <span class="logo">⚡ ChatGo Logs</span>
  <span class="badge offline" id="status-badge">● Connecting…</span>

  <div class="controls">
    <input type="text" id="filter-input" placeholder="Filter…" oninput="applyFilter()"/>
    <select id="level-select" onchange="applyFilter()">
      <option value="">All levels</option>
      <option value="ERROR">ERROR</option>
      <option value="WARN">WARN</option>
      <option value="INFO">INFO</option>
      <option value="DEBUG">DEBUG</option>
    </select>
    <button class="btn" onclick="togglePause()" id="pause-btn">⏸ Pause</button>
    <button class="btn" onclick="scrollToBottom()">↓ Bottom</button>
    <button class="btn danger" onclick="clearLogs()">🗑 Clear</button>
  </div>
</header>

<div class="stats">
  <span>Lines: <b id="stat-total">0</b></span>
  <span style="color:var(--red)">ERROR: <b id="stat-error">0</b></span>
  <span style="color:var(--yellow)">WARN: <b id="stat-warn">0</b></span>
  <span style="color:var(--green)">INFO: <b id="stat-info">0</b></span>
</div>

<div id="log-pane">
  <div id="log-container"></div>
  <div id="anchor"></div>
</div>

<script>
(function () {
  const SECRET = new URLSearchParams(location.search).get('secret') || '';
  const SSE_URL = '/logs/stream?secret=' + encodeURIComponent(SECRET);

  let es = null;
  let paused = false;
  let stats  = { total: 0, error: 0, warn: 0, info: 0 };
  let filterText = '';
  let filterLevel = '';

  // ── SSE connection ───────────────────────────────────────────────────────
  function connect() {
    if (es) { es.close(); }
    setBadge('Connecting…', false);
    es = new EventSource(SSE_URL);

    es.onopen = () => setBadge('Live', true);
    es.onerror = () => {
      setBadge('Reconnecting…', false);
      setTimeout(connect, 3000);
    };
    es.onmessage = e => {
      if (paused) return;
      appendLine(e.data);
    };
  }

  // ── Append a single log line ─────────────────────────────────────────────
  function appendLine(raw) {
    const level = detectLevel(raw);
    const ts    = detectTS(raw);

    stats.total++;
    if (level === 'ERROR') stats.error++;
    else if (level === 'WARN')  stats.warn++;
    else if (level === 'INFO')  stats.info++;
    updateStats();

    const div = document.createElement('div');
    div.className = 'log-line ' + level;
    div.dataset.raw   = raw.toLowerCase();
    div.dataset.level = level;

    const tsSpan = document.createElement('span');
    tsSpan.className = 'ts';
    tsSpan.textContent = ts;

    const txt = document.createTextNode(ts ? raw.slice(ts.length).trimStart() : raw);

    div.appendChild(tsSpan);
    div.appendChild(txt);

    applyVisibility(div);

    const container = document.getElementById('log-container');
    container.appendChild(div);

    // trim to 2000 DOM nodes
    while (container.children.length > 2000) {
      container.removeChild(container.firstChild);
    }

    scrollToBottomIfNear();
  }

  // ── Level detection ──────────────────────────────────────────────────────
  function detectLevel(line) {
    const u = line.toUpperCase();
    if (u.includes('ERROR') || u.includes('FATAL') || u.includes('PANIC')) return 'ERROR';
    if (u.includes('WARN'))  return 'WARN';
    if (u.includes('DEBUG')) return 'DEBUG';
    return 'INFO';
  }

  // ── Timestamp extraction (Go log default: "2006/01/02 15:04:05") ─────────
  const TS_RE = /^\d{4}\/\d{2}\/\d{2} \d{2}:\d{2}:\d{2}/;
  function detectTS(line) {
    const m = line.match(TS_RE);
    return m ? m[0] : '';
  }

  // ── Filter ───────────────────────────────────────────────────────────────
  function applyFilter() {
    filterText  = document.getElementById('filter-input').value.toLowerCase();
    filterLevel = document.getElementById('level-select').value;
    document.querySelectorAll('#log-container .log-line').forEach(applyVisibility);
  }

  function applyVisibility(el) {
    const matchText  = !filterText  || el.dataset.raw.includes(filterText);
    const matchLevel = !filterLevel || el.dataset.level === filterLevel;
    el.classList.toggle('hidden', !(matchText && matchLevel));
  }

  // ── Stats ────────────────────────────────────────────────────────────────
  function updateStats() {
    document.getElementById('stat-total').textContent = stats.total;
    document.getElementById('stat-error').textContent = stats.error;
    document.getElementById('stat-warn').textContent  = stats.warn;
    document.getElementById('stat-info').textContent  = stats.info;
  }

  // ── Badge ────────────────────────────────────────────────────────────────
  function setBadge(text, online) {
    const b = document.getElementById('status-badge');
    b.textContent = (online ? '● ' : '○ ') + text;
    b.className   = 'badge' + (online ? '' : ' offline');
  }

  // ── Scroll helpers ───────────────────────────────────────────────────────
  function scrollToBottomIfNear() {
    const pane = document.getElementById('log-pane');
    const dist = pane.scrollHeight - pane.scrollTop - pane.clientHeight;
    if (dist < 120) pane.scrollTop = pane.scrollHeight;
  }

  function scrollToBottom() {
    const pane = document.getElementById('log-pane');
    pane.scrollTop = pane.scrollHeight;
  }

  // ── Controls ─────────────────────────────────────────────────────────────
  function togglePause() {
    paused = !paused;
    document.getElementById('pause-btn').textContent = paused ? '▶ Resume' : '⏸ Pause';
  }

  function clearLogs() {
    document.getElementById('log-container').innerHTML = '';
    stats = { total: 0, error: 0, warn: 0, info: 0 };
    updateStats();
  }

  // expose to HTML onclick
  window.applyFilter    = applyFilter;
  window.togglePause    = togglePause;
  window.clearLogs      = clearLogs;
  window.scrollToBottom = scrollToBottom;

  connect();
})();
</script>
</body>
</html>
`

