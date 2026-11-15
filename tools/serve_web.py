"""Local-only web server; serves precompressed artifacts when supported."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse
import threading
import webbrowser

class GameHandler(SimpleHTTPRequestHandler):
    def send_head(self):
        original = Path(self.translate_path(self.path))
        compressed = original.with_name(original.name + ".gz")
        if original.suffix in [".wasm", ".pck", ".js"] and "gzip" in self.headers.get("Accept-Encoding", "") and compressed.is_file():
            stream = compressed.open("rb")
            self.send_response(200)
            self.send_header("Content-Type", self.guess_type(str(original)))
            self.send_header("Content-Encoding", "gzip")
            self.send_header("Content-Length", str(compressed.stat().st_size))
            self.send_header("Vary", "Accept-Encoding")
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            return stream
        return super().send_head()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--open", action="store_true")
    args = parser.parse_args()
    directory = Path(__file__).resolve().parents[1] / "build/web"
    handler = partial(GameHandler, directory=str(directory))
    server = None
    for port in range(args.port, args.port + 10):
        try:
            server = ThreadingHTTPServer(("127.0.0.1", port), handler)
            break
        except OSError:
            continue
    if server is None:
        raise SystemExit("No free local port. Close an older Space server and retry.")
    url = f"http://127.0.0.1:{server.server_port}/"
    print("Space Mission:", url, flush=True)
    if args.open:
        threading.Timer(0.2, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
