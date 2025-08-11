import { useState, useEffect } from 'react'
import DesktopLogin from './components/DesktopLogin'
import MobileLogin from './components/MobileLogin'
import './App.css'

function App() {
  const [isMobile, setIsMobile] = useState(false)
  const [isAuthenticated, setIsAuthenticated] = useState(false)

  useEffect(() => {
    // Detect mobile device
    const checkIfMobile = () => {
      return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
        navigator.userAgent
      ) || window.innerWidth <= 768
    }
    
    setIsMobile(checkIfMobile())
    
    // Check if already authenticated
    const token = localStorage.getItem('accessToken')
    if (token) {
      setIsAuthenticated(true)
    }
  }, [])

  const handleLogin = (token: string) => {
    localStorage.setItem('accessToken', token)
    setIsAuthenticated(true)
  }

  const handleLogout = () => {
    localStorage.removeItem('accessToken')
    localStorage.removeItem('refreshToken')
    setIsAuthenticated(false)
  }

  if (isAuthenticated) {
    return (
      <div className="app">
        <div className="auth-success">
          <h1>🎉 Login Successful!</h1>
          <p>You are now authenticated via QR Login System</p>
          <button onClick={handleLogout} className="logout-btn">
            Logout
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1>QR Login System</h1>
        <p>Secure authentication with QR codes</p>
      </header>
      
      {isMobile ? (
        <MobileLogin onLogin={handleLogin} />
      ) : (
        <DesktopLogin onLogin={handleLogin} />
      )}
      
      <footer className="app-footer">
        <p>Switch to {isMobile ? 'Desktop' : 'Mobile'} view:</p>
        <button 
          onClick={() => setIsMobile(!isMobile)}
          className="toggle-view-btn"
        >
          {isMobile ? '🖥️ Desktop View' : '📱 Mobile View'}
        </button>
      </footer>
    </div>
  )
}

export default App
