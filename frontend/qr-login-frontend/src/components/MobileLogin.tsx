import { useState, useEffect } from 'react'
import QrScanner from './QrScanner'

interface MobileLoginProps {
  onLogin: (token: string) => void
}

interface LoginFormData {
  email: string
  password: string
}

const MobileLogin: React.FC<MobileLoginProps> = () => {
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [userToken, setUserToken] = useState('')
  const [loginForm, setLoginForm] = useState<LoginFormData>({ email: '', password: '' })
  const [loginError, setLoginError] = useState('')
  const [isLoggingIn, setIsLoggingIn] = useState(false)
  const [showScanner, setShowScanner] = useState(false)

  useEffect(() => {
    // Check if user already has a token
    const token = localStorage.getItem('accessToken')
    if (token) {
      setUserToken(token)
      setIsAuthenticated(true)
    }
  }, [])

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsLoggingIn(true)
    setLoginError('')

    try {
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(loginForm)
      })

      if (response.ok) {
        const data = await response.json()
        setUserToken(data.accessToken)
        localStorage.setItem('accessToken', data.accessToken)
        localStorage.setItem('refreshToken', data.refreshToken)
        setIsAuthenticated(true)
      } else {
        const errorData = await response.json()
        setLoginError(errorData.message || 'Login failed')
      }
    } catch (error) {
      setLoginError('Network error. Please check your connection.')
    } finally {
      setIsLoggingIn(false)
    }
  }

  const handleSignup = async () => {
    if (!loginForm.email || !loginForm.password) {
      setLoginError('Please fill in all fields')
      return
    }

    setIsLoggingIn(true)
    setLoginError('')

    try {
      const response = await fetch('/api/auth/signup', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(loginForm)
      })

      if (response.status === 201) {
        // Auto-login after successful signup
        handleLogin(new Event('submit') as any)
      } else {
        const errorData = await response.json()
        setLoginError(errorData.error || 'Signup failed')
      }
    } catch (error) {
      setLoginError('Network error. Please check your connection.')
    } finally {
      setIsLoggingIn(false)
    }
  }

  const handleQrApproval = async (qrData: any) => {
    try {
      const response = await fetch('/api/qr/approve', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${userToken}`
        },
        body: JSON.stringify({
          challengeId: qrData.challengeId,
          nonce: qrData.nonce
        })
      })

      if (response.ok) {
        await response.json()
        alert('✅ Desktop login approved successfully!')
        setShowScanner(false)
      } else {
        const errorData = await response.json()
        alert(`❌ Failed to approve login: ${errorData.message}`)
      }
    } catch (error) {
      alert('❌ Error approving login. Please try again.')
    }
  }

  const handleLogout = () => {
    localStorage.removeItem('accessToken')
    localStorage.removeItem('refreshToken')
    setIsAuthenticated(false)
    setUserToken('')
  }

  if (!isAuthenticated) {
    return (
      <div className="mobile-login">
        <div className="login-container">
          <h2>📱 Mobile Login</h2>
          <p>Login to your account to scan QR codes</p>
          
          <form onSubmit={handleLogin} className="login-form">
            <div className="form-group">
              <input
                type="email"
                placeholder="Email"
                value={loginForm.email}
                onChange={(e) => setLoginForm({ ...loginForm, email: e.target.value })}
                required
                className="form-input"
              />
            </div>
            
            <div className="form-group">
              <input
                type="password"
                placeholder="Password (min 8 characters)"
                value={loginForm.password}
                onChange={(e) => setLoginForm({ ...loginForm, password: e.target.value })}
                required
                minLength={8}
                className="form-input"
              />
            </div>
            
            {loginError && (
              <div className="error-message">
                {loginError}
              </div>
            )}
            
            <div className="form-actions">
              <button 
                type="submit" 
                disabled={isLoggingIn}
                className="login-btn"
              >
                {isLoggingIn ? 'Logging in...' : 'Login'}
              </button>
              
              <button 
                type="button" 
                onClick={handleSignup}
                disabled={isLoggingIn}
                className="signup-btn"
              >
                {isLoggingIn ? 'Signing up...' : 'Sign Up'}
              </button>
            </div>
          </form>
          
          <div className="demo-credentials">
            <h3>Demo Accounts:</h3>
            <div className="demo-account">
              <strong>Admin:</strong>
              <p>📧 admin@example.com</p>
              <p>🔑 admin123</p>
            </div>
            <div className="demo-account">
              <strong>User:</strong>
              <p>📧 user@example.com</p>
              <p>🔑 user123</p>
            </div>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="mobile-authenticated">
      <div className="auth-container">
        <h2>📱 Mobile - Authenticated</h2>
        <p>You are logged in and ready to scan QR codes</p>
        
        <div className="user-info">
          <div className="auth-status">
            <span className="status-indicator">🟢</span>
            <span>Authenticated</span>
          </div>
        </div>
        
        <div className="scanner-section">
          {!showScanner ? (
            <div className="scanner-prompt">
              <h3>Ready to scan QR code</h3>
              <p>Scan a QR code from a desktop to approve login</p>
              <button 
                onClick={() => setShowScanner(true)}
                className="scan-btn"
              >
                📷 Start QR Scanner
              </button>
            </div>
          ) : (
            <div className="scanner-active">
              <QrScanner onScanSuccess={handleQrApproval} />
              <button 
                onClick={() => setShowScanner(false)}
                className="close-scanner-btn"
              >
                ✕ Close Scanner
              </button>
            </div>
          )}
        </div>
        
        <div className="mobile-instructions">
          <h3>How to approve desktop login:</h3>
          <ol>
            <li>Go to the desktop version of this app</li>
            <li>A QR code will be displayed on the desktop</li>
            <li>Click "Start QR Scanner" above</li>
            <li>Point your camera at the QR code</li>
            <li>Approve the login when prompted</li>
          </ol>
        </div>
        
        <div className="logout-section">
          <button onClick={handleLogout} className="logout-btn">
            🚪 Logout
          </button>
        </div>
      </div>
    </div>
  )
}

export default MobileLogin