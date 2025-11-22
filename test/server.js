#!/usr/bin/env node

import express from 'express';
import cors from 'cors';
import compression from 'compression';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 8080;

// Enable compression
app.use(compression());

// CORS configuration for WASM
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type'],
    credentials: false
}));

// Security headers for WASM/SharedArrayBuffer
app.use((req, res, next) => {
    res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
    res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    res.setHeader('Access-Control-Allow-Origin', '*');
    next();
});

// Custom MIME type handler for WASM files
app.use((req, res, next) => {
    const ext = path.extname(req.path).toLowerCase();

    const mimeTypes = {
        '.wasm': 'application/wasm',
        '.js': 'application/javascript',
        '.mjs': 'application/javascript',
        '.css': 'text/css',
        '.html': 'text/html',
        '.json': 'application/json',
        '.png': 'image/png',
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.gif': 'image/gif',
        '.svg': 'image/svg+xml',
        '.ico': 'image/x-icon',
        '.mp4': 'video/mp4',
        '.webm': 'video/webm',
        '.mp3': 'audio/mpeg',
        '.wav': 'audio/wav'
    };

    if (mimeTypes[ext]) {
        res.setHeader('Content-Type', mimeTypes[ext]);
    }

    next();
});

// Serve static files from the project root
app.use(express.static(path.join(__dirname, '..')));

// Route: Root redirect to test page
app.get('/', (req, res) => {
    res.redirect('/test/');
});

// Route: Test page
app.get('/test', (req, res) => {
    res.redirect('/test/');
});

// Route: Health check
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        node_version: process.version,
        memory: process.memoryUsage()
    });
});

// Route: API info
app.get('/api/info', (req, res) => {
    res.json({
        name: 'Zig WASM Video Editor Test Server',
        version: '0.1.0',
        endpoints: {
            test: '/test/',
            wasm: '/zig/zig-out/bin/video-editor.wasm',
            source: '/zig/src/',
            health: '/health',
            info: '/api/info'
        },
        features: [
            'WASM MIME type support',
            'CORS headers enabled',
            'Security headers for SharedArrayBuffer',
            'Compression enabled',
            'Static file serving'
        ]
    });
});

// Route: File listing for development
app.get('/api/files', (req, res) => {
    const projectRoot = path.join(__dirname, '..');

    function getFileTree(dir, relativePath = '') {
        const items = [];

        try {
            const entries = fs.readdirSync(dir, { withFileTypes: true });

            for (const entry of entries) {
                if (entry.name.startsWith('.')) continue; // Skip hidden files

                const fullPath = path.join(dir, entry.name);
                const relPath = path.join(relativePath, entry.name);

                if (entry.isDirectory()) {
                    items.push({
                        name: entry.name,
                        type: 'directory',
                        path: relPath,
                        children: getFileTree(fullPath, relPath)
                    });
                } else {
                    const stats = fs.statSync(fullPath);
                    items.push({
                        name: entry.name,
                        type: 'file',
                        path: relPath,
                        size: stats.size,
                        modified: stats.mtime
                    });
                }
            }
        } catch (error) {
            // Ignore errors for inaccessible directories
        }

        return items.sort((a, b) => {
            if (a.type !== b.type) {
                return a.type === 'directory' ? -1 : 1;
            }
            return a.name.localeCompare(b.name);
        });
    }

    res.json({
        root: projectRoot,
        files: getFileTree(projectRoot)
    });
});

// Error handling
app.use((err, req, res, next) => {
    console.error('Server error:', err);
    res.status(500).json({
        error: 'Internal server error',
        message: err.message,
        timestamp: new Date().toISOString()
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({
        error: 'Not found',
        path: req.path,
        message: 'The requested resource was not found',
        suggestions: [
            '/test/ - Main test page',
            '/zig/zig-out/bin/video-editor.wasm - WASM binary',
            '/api/info - Server information',
            '/health - Health check'
        ]
    });
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\n🛑 Server stopped by user');
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('\n🛑 Server terminated');
    process.exit(0);
});

// Start server
app.listen(PORT, () => {
    console.log('=' .repeat(60));
    console.log('🎬 Zig WASM Video Editor Test Server (Node.js)');
    console.log('=' .repeat(60));
    console.log(`📂 Serving directory: ${path.join(__dirname, '..')}`);
    console.log(`🌐 Server running at: http://localhost:${PORT}`);
    console.log(`🔗 Direct test link: http://localhost:${PORT}/test/`);
    console.log('=' .repeat(60));
    console.log('📋 Available endpoints:');
    console.log(`   • Main test page: http://localhost:${PORT}/test/`);
    console.log(`   • WASM binary:    http://localhost:${PORT}/zig/zig-out/bin/video-editor.wasm`);
    console.log(`   • Source files:   http://localhost:${PORT}/zig/src/`);
    console.log(`   • API info:       http://localhost:${PORT}/api/info`);
    console.log(`   • Health check:   http://localhost:${PORT}/health`);
    console.log(`   • File listing:   http://localhost:${PORT}/api/files`);
    console.log('=' .repeat(60));
    console.log('🔧 Features:');
    console.log('   • Express.js server with compression');
    console.log('   • WASM MIME type support');
    console.log('   • CORS headers enabled');
    console.log('   • Security headers for SharedArrayBuffer');
    console.log('   • JSON API endpoints');
    console.log('   • Error handling and 404 responses');
    console.log('=' .repeat(60));
    console.log('Press Ctrl+C to stop the server');
    console.log();
});
