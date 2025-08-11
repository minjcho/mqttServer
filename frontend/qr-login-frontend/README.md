# QR Login System Frontend

A modern React + TypeScript frontend for the QR-based authentication system. This application provides both desktop and mobile interfaces for seamless QR code login experience.

## 🚀 Features

### Desktop Interface
- **QR Code Display**: Automatically generates and displays QR codes for login
- **Real-time Updates**: Uses Server-Sent Events (SSE) for live status updates
- **Auto-login**: Automatically logs in when QR code is approved on mobile

### Mobile Interface  
- **User Authentication**: Email/password login with demo accounts
- **QR Scanner**: Camera-based QR code scanning with visual feedback
- **Login Approval**: Approve desktop login requests from mobile device

### Responsive Design
- **Adaptive UI**: Automatically detects mobile/desktop and shows appropriate interface
- **Manual Toggle**: Switch between desktop and mobile views for testing
- **Modern Styling**: Beautiful gradient backgrounds and smooth animations

## 🛠️ Technologies

- **React 19** - Modern React with hooks
- **TypeScript** - Type-safe development
- **Vite** - Fast build tool and dev server
- **ZXing Library** - QR code scanning functionality
- **QRCode Generator** - QR code creation
- **CSS3** - Modern styling with animations

## 📋 Prerequisites

- Node.js 18+ (Note: Vite requires Node 20+ but works with 18)
- Running QR Login System backend on `localhost:8090`
- Modern web browser with camera access (for mobile scanning)

## 🚀 Getting Started

### 1. Install Dependencies

```bash
npm install
```

### 2. Start Development Server

```bash
npm run dev
```

The application will be available at `http://localhost:3000`

### 3. Test the Application

#### Desktop Login Flow:
1. Open `http://localhost:3000` on desktop
2. A QR code will automatically generate
3. Use mobile device to scan the QR code
4. Approve the login on mobile
5. Desktop will automatically log in

#### Mobile Login Flow:
1. Open `http://localhost:3000` on mobile device (or click "Mobile View")
2. Log in with demo credentials:
   - **Admin**: `admin@example.com` / `admin123`
   - **User**: `user@example.com` / `user123`
3. Click "Start QR Scanner"
4. Scan QR code from desktop
5. Approve the login request

## 📁 Project Structure

```
src/
├── components/
│   ├── DesktopLogin.tsx    # Desktop QR display and login
│   ├── MobileLogin.tsx     # Mobile authentication and scanning
│   └── QrScanner.tsx       # Camera-based QR code scanner
├── App.tsx                 # Main application component
├── App.css                 # Application styles
└── main.tsx               # Application entry point
```

## 🎯 Key Components

### App.tsx
- Device detection (mobile vs desktop)
- Authentication state management
- View toggling between mobile/desktop

### DesktopLogin.tsx
- QR code generation using `qrcode-generator`
- SSE connection for real-time updates
- Token exchange on approval
- Error handling and retry logic

### MobileLogin.tsx  
- User authentication (login/signup)
- QR scanner integration
- Approval request handling
- Demo credentials display

### QrScanner.tsx
- Camera access and permission handling
- ZXing-based QR code detection
- Visual scanning interface with overlay
- Error handling and retry mechanisms

## 🔧 Configuration

### API Proxy
The Vite development server is configured to proxy API requests to the backend:

```typescript
server: {
  port: 3000,
  proxy: {
    '/api': {
      target: 'http://localhost:8090',
      changeOrigin: true,
      secure: false
    }
  }
}
```

## 📱 Usage Instructions

### For Desktop Users:
1. Navigate to the application
2. QR code appears automatically  
3. Keep the page open and wait for mobile approval
4. Login completes automatically when approved

### For Mobile Users:
1. Navigate to the application (shows mobile interface)
2. Login with your credentials or use demo accounts
3. Click "Start QR Scanner" to activate camera
4. Point camera at desktop QR code
5. Confirm approval when prompted

## 🔒 Security Features

- **JWT Token Management**: Secure token storage and refresh
- **CORS Handling**: Proper cross-origin request configuration
- **Input Validation**: Form validation and error handling
- **Camera Permissions**: Proper camera access request handling

## 🐛 Troubleshooting

### Common Issues:

#### Camera Not Working
- Ensure browser has camera permissions
- Try HTTPS if camera access is blocked
- Check if another app is using the camera

#### QR Code Not Scanning
- Ensure good lighting conditions
- Hold camera steady and close to QR code
- Try refreshing the page if scanner stops responding

#### API Connection Issues  
- Verify backend is running on `localhost:8090`
- Check browser console for CORS errors
- Ensure API endpoints are accessible

#### SSE Connection Problems
- Check browser developer tools for failed connections
- Verify backend SSE endpoints are working
- Try refreshing the page to reconnect

## 🚀 Build for Production

```bash
# Build for production
npm run build

# Preview production build
npm run preview
```

## 📚 API Integration

This frontend integrates with the following backend endpoints:

- `POST /api/qr/init` - Generate QR code
- `GET /api/qr/stream/{challengeId}` - SSE status updates  
- `POST /api/qr/approve` - Approve login (mobile)
- `POST /api/qr/exchange` - Exchange OTC for tokens
- `POST /api/auth/login` - User authentication
- `POST /api/auth/signup` - User registration

## 🤝 Contributing

1. Follow TypeScript best practices
2. Maintain responsive design principles  
3. Add proper error handling
4. Test on both mobile and desktop devices
5. Update documentation for new features

## 📄 License

MIT License - see the main project license for details.
