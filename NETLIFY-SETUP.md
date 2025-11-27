# 🚀 Deploy Your Mobile Video Recorder to Netlify

This guide will help you deploy your mobile video recorder to Netlify in just a few minutes!

## 🎯 Quick Start (5 minutes)

### Option 1: Automatic Deployment (Recommended)
```bash
# 1. Run the deployment script
./deploy-netlify.sh

# 2. Follow the prompts to login to Netlify
# 3. Your app will be deployed automatically!
```

### Option 2: Manual Deployment
```bash
# 1. Build the app
./build-mobile-simple.sh

# 2. Install Netlify CLI
npm install -g netlify-cli

# 3. Login to Netlify
netlify login

# 4. Deploy
cd zig/zig-out/web
netlify deploy --dir=. --prod
```

## 📋 Prerequisites

- [Node.js](https://nodejs.org/) installed on your computer
- A [Netlify account](https://netlify.com) (free)
- Your built mobile video recorder app

## 🔧 Step-by-Step Setup

### 1. Prepare Your App
```bash
# Make sure you're in the video-editor directory
cd video-editor

# Build the mobile app
./build-mobile-simple.sh
```

### 2. Install Netlify CLI
```bash
# Install globally
npm install -g netlify-cli

# Verify installation
netlify --version
```

### 3. Login to Netlify
```bash
netlify login
```
This will open your browser to authenticate with Netlify.

### 4. Deploy Your App
```bash
# Navigate to the built web app
cd zig/zig-out/web

# Deploy to Netlify
netlify deploy --dir=. --prod
```

### 5. Get Your Live URL
After deployment, Netlify will provide you with a URL like:
```
https://amazing-app-name-123456.netlify.app
```

## 📱 Using Your Deployed App

### On Mobile:
1. **Open the URL** in your mobile browser
2. **Grant permissions** for camera and microphone
3. **Add to Home Screen**:
   - **iOS**: Tap Share → Add to Home Screen
   - **Android**: Tap Menu → Add to Home Screen
4. **Launch from home screen** like any other app!

### Features That Work:
- ✅ Camera recording (front & back)
- ✅ Video export and download
- ✅ Works offline after first visit
- ✅ Touch gestures (pinch to zoom)
- ✅ Background recording
- ✅ High quality video up to 4K

## 🎨 Customizing Your Deployment

### Custom Domain
```bash
# Add your own domain
netlify domains:add yourdomain.com
```

### Environment Variables
```bash
# Set environment variables
netlify env:set VAR_NAME "value"
```

### Build Settings
Edit `netlify.toml` in your web directory:
```toml
[build]
  publish = "."
  
[[headers]]
  for = "/*.wasm"
  [headers.values]
    Content-Type = "application/wasm"
    
[[redirects]]
  from = "/*"
  to = "/mobile.html"
  status = 200
```

## 🔒 Security & Performance

### Automatic HTTPS
- ✅ Netlify provides free SSL certificates
- ✅ Required for camera access
- ✅ Automatic redirects from HTTP to HTTPS

### Performance Optimizations
- ✅ Global CDN for fast loading
- ✅ Automatic compression
- ✅ Optimized caching headers
- ✅ WebAssembly support

### Privacy
- ✅ All video processing happens in the browser
- ✅ No videos uploaded to servers
- ✅ No tracking or analytics by default

## 🔄 Updating Your App

To update your deployed app:
```bash
# 1. Make changes to your code
# 2. Rebuild
./build-mobile-simple.sh

# 3. Redeploy
cd zig/zig-out/web
netlify deploy --prod --dir=.
```

## 📊 Monitoring & Analytics

### Built-in Analytics
```bash
# View site analytics
netlify open:admin
```

### Custom Analytics (Optional)
Add to your `mobile.html`:
```html
<!-- Google Analytics, Plausible, etc. -->
```

## 🐛 Troubleshooting

### Common Issues

**"Camera access denied"**
- ✅ Ensure you're using HTTPS (Netlify provides this)
- ✅ Check browser permissions
- ✅ Try refreshing the page

**"WebAssembly not loading"**
- ✅ Check that `video-editor.wasm` is uploaded
- ✅ Verify MIME type is set to `application/wasm`

**"App not working offline"**
- ✅ Visit the app once while online
- ✅ Check service worker registration
- ✅ Clear browser cache and try again

**"Build failed"**
```bash
# Clean and rebuild
rm -rf zig/zig-out
./build-mobile-simple.sh
```

### Netlify-Specific Issues

**Deploy failed**
```bash
# Check deployment logs
netlify logs

# Manual deployment
netlify deploy --dir=zig/zig-out/web --prod
```

**Custom domain not working**
```bash
# Check DNS settings
netlify dns

# Verify domain configuration
netlify open:admin
```

## 💰 Netlify Pricing

### Free Tier (Perfect for this app):
- ✅ 100GB bandwidth/month
- ✅ 300 build minutes/month
- ✅ Custom domain support
- ✅ SSL certificates
- ✅ Global CDN

### When you might need paid:
- Heavy usage (>100GB/month)
- Advanced features (analytics, forms)

## 🌍 Alternative Deployment Options

If Netlify doesn't work for you:

### GitHub Pages
```bash
# Push to gh-pages branch
git subtree push --prefix zig/zig-out/web origin gh-pages
```

### Vercel
```bash
npm install -g vercel
vercel --prod
```

### Firebase Hosting
```bash
npm install -g firebase-tools
firebase deploy
```

## 📞 Getting Help

### Resources:
- [Netlify Documentation](https://docs.netlify.com/)
- [Mobile Video Recorder Issues](https://github.com/yourusername/video-editor/issues)

### Support:
- Check the troubleshooting section above
- Open an issue on GitHub
- Contact Netlify support for platform issues

## 🎉 Success!

Once deployed, you'll have:
- 📱 A professional mobile video recording app
- 🌍 Accessible from anywhere with the URL
- 🔒 Secure HTTPS connection
- ⚡ Fast global CDN delivery
- 💾 Offline functionality
- 🆓 All for free on Netlify!

**Your TikTok camera problems are solved!** 🎬✨

---

*Need help? Open an issue or check the troubleshooting section above.*