import http.server
import subprocess

class ClipHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)

        # Safely pass data to wl-copy
        subprocess.run(
            ["wl-copy"],
            input=post_data,
            check=True
        )

        self.send_response(200)
        self.end_headers()
        print(f"Copied: {post_data.decode('utf-8', errors='ignore')}")

http.server.HTTPServer(('0.0.0.0', 5555), ClipHandler).serve_forever()
