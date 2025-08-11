import { useState, useEffect, useRef } from 'react'
import qrcode from 'qrcode-generator'

interface DesktopLoginProps {
  onLogin: (token: string) => void
}

interface QrStatusData {
  status: string
  otc?: string
}

const DesktopLogin: React.FC<DesktopLoginProps> = ({ onLogin }) => {
  const [qrCodeDataUrl, setQrCodeDataUrl] = useState('')
  const [challengeId, setChallengeId] = useState('')
  const [status, setStatus] = useState<'loading' | 'waiting' | 'approved' | 'error'>('loading')
  const [errorMessage, setErrorMessage] = useState('')
  const eventSourceRef = useRef<EventSource | null>(null)

  const initializeQR = async () => {
    try {
      setStatus('loading')
      setErrorMessage('')
      
      const response = await fetch('/api/qr/init', {
        method: 'POST'
      })

      if (response.ok) {
        const challengeIdFromHeader = response.headers.get('X-Challenge-Id')
        if (challengeIdFromHeader) {
          setChallengeId(challengeIdFromHeader)
          
          // Generate QR code with challenge info
          const qrCodeData = JSON.stringify({
            challengeId: challengeIdFromHeader,
            nonce: generateNonce()
          })
          
          const qr = qrcode(0, 'M')
          qr.addData(qrCodeData)
          qr.make()
          
          // Convert to data URL for display
          const qrDataUrl = qr.createDataURL(6)
          setQrCodeDataUrl(qrDataUrl)
          
          setStatus('waiting')
          startListeningForUpdates(challengeIdFromHeader)
        } else {
          throw new Error('No Challenge ID received')
        }
      } else {
        throw new Error('Failed to initialize QR login')
      }
    } catch (error) {
      console.error('Error initializing QR:', error)
      setErrorMessage(error instanceof Error ? error.message : 'Failed to generate QR code')
      setStatus('error')
    }
  }

  const generateNonce = (): string => {
    return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15)
  }

  const startListeningForUpdates = (challengeId: string) => {
    // Close any existing connection
    if (eventSourceRef.current) {
      eventSourceRef.current.close()
    }

    // Start SSE connection for real-time updates
    const eventSource = new EventSource(`/api/qr/stream/${challengeId}`)
    eventSourceRef.current = eventSource

    eventSource.onmessage = async (event) => {
      try {
        const data: QrStatusData = JSON.parse(event.data)
        
        if (data.status === 'APPROVED' && data.otc) {
          setStatus('approved')
          
          // Exchange OTC for tokens
          const tokenResponse = await fetch('/api/qr/exchange', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({ otc: data.otc })
          })

          if (tokenResponse.ok) {
            const tokens = await tokenResponse.json()
            localStorage.setItem('refreshToken', tokens.refreshToken)
            onLogin(tokens.accessToken)
          } else {
            throw new Error('Failed to exchange OTC for tokens')
          }
        } else if (data.status === 'EXPIRED') {
          setErrorMessage('QR code has expired. Please generate a new one.')
          setStatus('error')
        }
      } catch (error) {
        console.error('Error processing SSE message:', error)
        setErrorMessage('Error processing authentication response')
        setStatus('error')
      }
    }

    eventSource.onerror = () => {
      console.error('SSE connection error')
      setErrorMessage('Connection lost. Please try again.')
      setStatus('error')
    }

    // Clean up on timeout (2 minutes)
    setTimeout(() => {
      if (eventSource.readyState === EventSource.OPEN) {
        eventSource.close()
        if (status === 'waiting') {
          setErrorMessage('QR code has expired. Please generate a new one.')
          setStatus('error')
        }
      }
    }, 120000)
  }

  useEffect(() => {
    initializeQR()

    return () => {
      if (eventSourceRef.current) {
        eventSourceRef.current.close()
      }
    }
  }, [])

  return (
    <div className="desktop-login">
      <div className="login-container">
        <h2>🖥️ Desktop Login</h2>
        <p>Scan the QR code with your mobile device to log in</p>
        
        <div className="qr-section">
          {status === 'loading' && (
            <div className="loading-state">
              <div className="spinner"></div>
              <p>Generating QR code...</p>
            </div>
          )}
          
          {status === 'waiting' && qrCodeDataUrl && (
            <div className="qr-display">
              <img src={qrCodeDataUrl} alt="QR Code for login" className="qr-image" />
              <p className="qr-instruction">
                📱 Open your mobile app and scan this QR code
              </p>
              <div className="qr-info">
                <small>Challenge ID: {challengeId}</small>
              </div>
            </div>
          )}
          
          {status === 'approved' && (
            <div className="approved-state">
              <div className="success-icon">✅</div>
              <p>QR code approved! Logging you in...</p>
            </div>
          )}
          
          {status === 'error' && (
            <div className="error-state">
              <div className="error-icon">❌</div>
              <p className="error-message">{errorMessage}</p>
              <button onClick={initializeQR} className="retry-btn">
                Generate New QR Code
              </button>
            </div>
          )}
        </div>
        
        <div className="desktop-instructions">
          <h3>How to use:</h3>
          <ol>
            <li>Open the mobile version of this app on your phone</li>
            <li>Log in with your credentials on mobile</li>
            <li>Use the camera to scan the QR code above</li>
            <li>Approve the login request on your mobile device</li>
            <li>You'll be automatically logged in on this desktop</li>
          </ol>
        </div>
      </div>
    </div>
  )
}

export default DesktopLogin