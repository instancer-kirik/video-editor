#!/usr/bin/env python3
import http.server
import ssl
import os
import subprocess
import sys

PORT = 8443

# Create self-signed certificate if it doesn't exist
if not os.path.exists('cert.pem') or not os.path.exists('key.pem'):
    print("Creating self-signed certificate...")
    try:
        subprocess.run([
            'openssl', 'req', '-x509', '-newkey', 'rsa:2048',
            '-keyout', 'key.pem', '-out', 'cert.pem',
            '-days', '365', '-nodes',
            '-subj', '/CN=localhost'
        ], check=True)
    except subprocess.CalledProcessError:
        print("Error: OpenSSL not found. Install OpenSSL to create certificates.")
        sys.exit(1)

# Set up HTTPS server
Handler = http.server.SimpleHTTPRequestHandler
Handler.extensions_map.update({
    '.wasm': 'application/wasm',
    '.json': 'application/manifest+json'
})

with http.server.HTTPServer(('', PORT), Handler) as httpd:
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain('cert.pem', 'key.pem')
    httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

    print(f"HTTPS Server running at https://localhost:{PORT}/mobile.html")
    print("Note: You'll need to accept the self-signed certificate in your browser")
    print("Press Ctrl+C to stop the server")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
