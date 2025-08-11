import { useEffect, useRef, useState } from 'react'
import { BrowserMultiFormatReader, NotFoundException } from '@zxing/library'

interface QrScannerProps {
  onScanSuccess: (data: any) => void
}

const QrScanner: React.FC<QrScannerProps> = ({ onScanSuccess }) => {
  const videoRef = useRef<HTMLVideoElement>(null)
  const [isScanning, setIsScanning] = useState(false)
  const [error, setError] = useState('')
  const [hasPermission, setHasPermission] = useState(false)
  const codeReader = useRef<BrowserMultiFormatReader | null>(null)

  useEffect(() => {
    initializeScanner()
    return () => {
      stopScanner()
    }
  }, [])

  const initializeScanner = async () => {
    try {
      // Check if mediaDevices is available
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('Camera API not available. Please use HTTPS or follow the browser setup guide.')
      }
      
      // Request camera permission
      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: 'environment' // Use back camera if available
        }
      })
      
      setHasPermission(true)
      
      if (videoRef.current) {
        videoRef.current.srcObject = stream
        videoRef.current.setAttribute('playsinline', 'true') // For iOS
        videoRef.current.play()
        
        // Initialize ZXing code reader
        codeReader.current = new BrowserMultiFormatReader()
        startScanning()
      }
    } catch (err) {
      console.error('Error accessing camera:', err)
      const errorMessage = err instanceof Error ? err.message : 'Failed to access camera'
      setError(errorMessage)
      
      // Show specific help for HTTPS requirement
      if (!navigator.mediaDevices) {
        setError('Camera access requires HTTPS. Please use https:// or set up Chrome flags for your IP address.')
      }
    }
  }

  const startScanning = () => {
    if (!codeReader.current || !videoRef.current) return

    setIsScanning(true)
    setError('')

    // Start continuous scanning
    const scanFrame = () => {
      if (!codeReader.current || !videoRef.current || !isScanning) return

      try {
        codeReader.current.decodeFromVideoDevice(
          null,
          videoRef.current.id,
          (result, error) => {
            if (result) {
              handleScanResult(result.getText())
            }
            if (error && !(error instanceof NotFoundException)) {
              console.error('Scan error:', error)
            }
          }
        )
      } catch (error) {
        console.error('Scanning error:', error)
      }
    }

    scanFrame()
  }

  const handleScanResult = (text: string) => {
    try {
      setIsScanning(false)
      
      // Parse QR code data
      const qrData = JSON.parse(text)
      
      if (qrData.challengeId && qrData.nonce) {
        onScanSuccess(qrData)
      } else {
        setError('Invalid QR code format. Please scan a valid login QR code.')
        setTimeout(() => {
          setIsScanning(true)
          startScanning()
        }, 2000)
      }
    } catch (error) {
      console.error('Error parsing QR data:', error)
      setError('Invalid QR code. Please scan a valid login QR code.')
      setTimeout(() => {
        setIsScanning(true)
        startScanning()
      }, 2000)
    }
  }

  const stopScanner = () => {
    setIsScanning(false)
    
    if (codeReader.current) {
      codeReader.current.reset()
    }
    
    if (videoRef.current && videoRef.current.srcObject) {
      const stream = videoRef.current.srcObject as MediaStream
      const tracks = stream.getTracks()
      tracks.forEach(track => track.stop())
      videoRef.current.srcObject = null
    }
  }

  const retryScanning = () => {
    setError('')
    setIsScanning(true)
    startScanning()
  }

  if (!hasPermission) {
    return (
      <div className="scanner-container">
        <div className="permission-prompt">
          <h3>📷 Camera Access Required</h3>
          <p>Please grant camera permission to scan QR codes</p>
          <button onClick={initializeScanner} className="permission-btn">
            Grant Camera Access
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="scanner-container">
      <div className="scanner-viewport">
        <video
          ref={videoRef}
          id="qr-scanner-video"
          className="scanner-video"
          playsInline
          muted
        />
        
        <div className="scanner-overlay">
          <div className="scanner-frame">
            <div className="corner top-left"></div>
            <div className="corner top-right"></div>
            <div className="corner bottom-left"></div>
            <div className="corner bottom-right"></div>
          </div>
        </div>
        
        <div className="scanner-status">
          {isScanning ? (
            <div className="scanning-indicator">
              <div className="pulse-dot"></div>
              <span>Scanning for QR code...</span>
            </div>
          ) : (
            <div className="scan-paused">
              <span>Scan paused</span>
            </div>
          )}
        </div>
      </div>
      
      {error && (
        <div className="scanner-error">
          <p>{error}</p>
          <button onClick={retryScanning} className="retry-scan-btn">
            Try Again
          </button>
        </div>
      )}
      
      <div className="scanner-instructions">
        <p>📱 Point your camera at the QR code displayed on the desktop</p>
        <p>The code will be automatically detected and processed</p>
      </div>
    </div>
  )
}

export default QrScanner