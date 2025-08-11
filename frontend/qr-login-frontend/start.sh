#!/bin/bash

echo "🚀 Starting QR Login System Frontend"
echo "====================================="

echo "📋 Prerequisites:"
echo "- Backend should be running on localhost:8090"
echo "- Camera access will be requested for mobile scanning"
echo ""

echo "🌐 Application will be available at:"
echo "- Desktop: http://localhost:3000 (auto-detects desktop)"
echo "- Mobile: http://localhost:3000 (auto-detects mobile)"
echo ""

echo "🔐 Demo Accounts:"
echo "- Admin: admin@example.com / admin123"
echo "- User: user@example.com / user123"
echo ""

echo "📱 Usage:"
echo "1. Open on desktop → QR code displays"
echo "2. Open on mobile → Login and scan QR"
echo "3. Use toggle button to test different views"
echo ""

npm run dev