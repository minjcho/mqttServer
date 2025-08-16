// 전역 변수
let wsConnection = null;
let sseConnection = null;
let coordinateHistory = [];
const MAX_HISTORY = 50;

// 페이지 로드 시 초기화
document.addEventListener('DOMContentLoaded', () => {
    updateCurrentTime();
    setInterval(updateCurrentTime, 1000);
    checkAllServices();
    setInterval(checkAllServices, 30000); // 30초마다 서비스 상태 확인
});

// 현재 시간 업데이트
function updateCurrentTime() {
    const now = new Date();
    const timeString = now.toLocaleString('ko-KR', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    });
    document.getElementById('current-time').textContent = timeString;
}

// 로그 추가 함수
function addLog(message, type = 'info') {
    const logContainer = document.getElementById('log-container');
    const logEntry = document.createElement('div');
    logEntry.className = `log-entry ${type}`;
    const timestamp = new Date().toLocaleTimeString('ko-KR');
    logEntry.textContent = `[${timestamp}] ${message}`;
    logContainer.appendChild(logEntry);
    
    // 자동 스크롤
    if (document.getElementById('auto-scroll').checked) {
        logContainer.scrollTop = logContainer.scrollHeight;
    }
    
    // 로그 개수 제한 (최대 100개)
    while (logContainer.children.length > 100) {
        logContainer.removeChild(logContainer.firstChild);
    }
}

// 로그 지우기
function clearLogs() {
    const logContainer = document.getElementById('log-container');
    logContainer.innerHTML = '<div class="log-entry info">로그가 초기화되었습니다.</div>';
}

// 모든 서비스 상태 확인
async function checkAllServices() {
    checkQRService();
    checkWebSocketService();
    checkMQTTService();
}

// QR 로그인 서비스 확인
async function checkQRService() {
    const serviceCard = document.getElementById('qr-service');
    const statusDiv = serviceCard.querySelector('.service-status');
    
    try {
        // OPTIONS 요청으로 서비스 확인 (CORS preflight를 활용)
        const response = await fetch('/api/qr/init', {
            method: 'OPTIONS',
            mode: 'cors'
        });
        
        // OPTIONS 요청이 204를 반환하거나 다른 응답이 있으면 서비스가 살아있음
        if (response.status === 204 || response.status === 200 || response.status === 403) {
            statusDiv.textContent = '온라인';
            statusDiv.className = 'service-status online';
            document.getElementById('api-status').className = 'status-dot online';
            addLog('QR Login Service 연결 확인', 'success');
        } else {
            throw new Error('Service unavailable');
        }
    } catch (error) {
        statusDiv.textContent = '오프라인';
        statusDiv.className = 'service-status offline';
        document.getElementById('api-status').className = 'status-dot offline';
        addLog('QR Login Service 연결 실패: ' + error.message, 'error');
    }
}

// WebSocket 서비스 확인
function checkWebSocketService() {
    const serviceCard = document.getElementById('ws-service');
    const statusDiv = serviceCard.querySelector('.service-status');
    
    if (wsConnection && wsConnection.readyState === SockJS.OPEN) {
        statusDiv.textContent = '연결됨';
        statusDiv.className = 'service-status online';
        document.getElementById('ws-status').className = 'status-dot online';
    } else {
        statusDiv.textContent = '연결 안됨';
        statusDiv.className = 'service-status offline';
        document.getElementById('ws-status').className = 'status-dot offline';
    }
}

// MQTT 서비스 확인
async function checkMQTTService() {
    const serviceCard = document.getElementById('mqtt-service');
    const statusDiv = serviceCard.querySelector('.service-status');
    
    // MQTT는 WebSocket으로 직접 연결이 어려우므로 단순히 포트 상태만 표시
    statusDiv.textContent = '포트 3123';
    statusDiv.className = 'service-status online';
    document.getElementById('mqtt-status').className = 'status-dot online';
    addLog('MQTT Broker는 포트 3123에서 실행 중', 'info');
}

// QR 서비스 테스트
async function testQRService() {
    try {
        addLog('QR Login Service 테스트 시작...', 'info');
        // OPTIONS 요청으로 CORS 테스트
        const response = await fetch('/api/auth/signup', {
            method: 'OPTIONS',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        if (response.status === 204) {
            addLog('QR Login Service CORS 테스트 성공 (OPTIONS 204)', 'success');
            addLog('서비스가 정상적으로 응답하고 있습니다', 'success');
        } else {
            addLog('QR Login Service 응답 상태: ' + response.status, 'warning');
        }
    } catch (error) {
        addLog('QR Login Service 테스트 오류: ' + error.message, 'error');
    }
}

// WebSocket 연결 테스트 (SockJS 사용)
function testWebSocket() {
    if (wsConnection && wsConnection.readyState === SockJS.OPEN) {
        addLog('SockJS 이미 연결되어 있습니다', 'warning');
        return;
    }
    
    addLog('SockJS 연결 시도...', 'info');
    document.getElementById('ws-status').className = 'status-dot connecting';
    
    // ORIN ID 설정 (테스트용)
    const ORIN_ID = '1420524217000';
    
    // SockJS 연결
    wsConnection = new SockJS(`https://minjcho.site/coordinates?orinId=${ORIN_ID}`);
    
    wsConnection.onopen = () => {
        addLog(`SockJS 연결 성공 - ORIN ID: ${ORIN_ID}`, 'success');
        document.getElementById('ws-status').className = 'status-dot online';
        checkWebSocketService();
    };
    
    wsConnection.onmessage = (event) => {
        try {
            const data = JSON.parse(event.data);
            
            if (data.type === 'connected') {
                addLog(`✅ ${data.message} (구독 ORIN ID: ${data.orinId})`, 'success');
            } else if (data.type === 'coordinates') {
                updateCoordinateDisplay({
                    coordX: data.data.coordX,
                    coordY: data.data.coordY,
                    timestamp: data.timestamp,
                    orinId: data.orinId
                });
                addLog(`📍 ORIN ${data.orinId} 좌표: X=${data.data.coordX}, Y=${data.data.coordY}`, 'info');
            } else {
                addLog('메시지 수신: ' + event.data, 'info');
            }
        } catch (error) {
            addLog('SockJS 메시지 파싱 오류: ' + error.message, 'error');
        }
    };
    
    wsConnection.onerror = (error) => {
        addLog('SockJS 오류: ' + error.message, 'error');
        document.getElementById('ws-status').className = 'status-dot offline';
    };
    
    wsConnection.onclose = () => {
        addLog('SockJS 연결 종료', 'warning');
        document.getElementById('ws-status').className = 'status-dot offline';
        wsConnection = null;
        checkWebSocketService();
    };
}

// 좌표 디스플레이 업데이트
function updateCoordinateDisplay(data) {
    document.getElementById('coord-x').textContent = data.coordX || '-';
    document.getElementById('coord-y').textContent = data.coordY || '-';
    document.getElementById('coord-timestamp').textContent = 
        data.timestamp ? new Date(data.timestamp).toLocaleTimeString('ko-KR') : '-';
    
    // 히스토리에 추가
    coordinateHistory.push({
        x: data.coordX,
        y: data.coordY,
        time: new Date()
    });
    
    if (coordinateHistory.length > MAX_HISTORY) {
        coordinateHistory.shift();
    }
    
    // 차트 업데이트 (간단한 시각화)
    drawCoordinateChart();
}

// 간단한 좌표 차트 그리기
function drawCoordinateChart() {
    const canvas = document.getElementById('coordinate-chart');
    const ctx = canvas.getContext('2d');
    const width = canvas.width = canvas.offsetWidth;
    const height = canvas.height = 200;
    
    // 캔버스 초기화
    ctx.fillStyle = '#1e293b';
    ctx.fillRect(0, 0, width, height);
    
    if (coordinateHistory.length < 2) return;
    
    // X 좌표 그리기
    ctx.strokeStyle = '#10b981';
    ctx.lineWidth = 2;
    ctx.beginPath();
    
    coordinateHistory.forEach((point, index) => {
        const x = (index / (MAX_HISTORY - 1)) * width;
        const y = height - ((point.x || 0) / 100 * height);
        
        if (index === 0) {
            ctx.moveTo(x, y);
        } else {
            ctx.lineTo(x, y);
        }
    });
    ctx.stroke();
    
    // Y 좌표 그리기
    ctx.strokeStyle = '#2563eb';
    ctx.beginPath();
    
    coordinateHistory.forEach((point, index) => {
        const x = (index / (MAX_HISTORY - 1)) * width;
        const y = height - ((point.y || 0) / 100 * height);
        
        if (index === 0) {
            ctx.moveTo(x, y);
        } else {
            ctx.lineTo(x, y);
        }
    });
    ctx.stroke();
}

// MQTT 테스트
function testMQTT() {
    addLog('MQTT 브로커 정보', 'info');
    addLog('MQTT Broker는 포트 3123에서 실행 중입니다', 'info');
    addLog('MQTT 클라이언트를 사용하여 mosquitto:3123에 연결하세요', 'info');
    addLog('Docker 컨테이너: mosquitto', 'info');
    
    // WebSocket API 테스트
    fetch('/api/mqtt/status', {
        method: 'GET'
    }).then(response => {
        if (response.ok) {
            addLog('MQTT API 엔드포인트 응답 확인', 'success');
        } else {
            addLog('MQTT는 TCP 포트 3123에서 직접 연결 가능', 'info');
        }
    }).catch(error => {
        addLog('MQTT는 MQTT 클라이언트로 직접 연결하세요', 'info');
    });
}

// QR 코드 생성
async function generateQR() {
    try {
        addLog('QR 코드 생성 요청...', 'info');
        
        const response = await fetch('/api/qr/init', {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        if (response.ok) {
            const data = await response.json();
            displayQRCode(data);
            
            // SSE로 상태 모니터링
            if (data.challengeId) {
                monitorQRStatus(data.challengeId);
            }
            
            addLog('QR 코드 생성 성공', 'success');
        } else {
            const error = await response.text();
            addLog('QR 코드 생성 실패: ' + error, 'error');
        }
    } catch (error) {
        addLog('QR 코드 생성 오류: ' + error.message, 'error');
    }
}

// QR 코드 표시
function displayQRCode(data) {
    const qrDisplay = document.getElementById('qr-display');
    
    if (data.qrCode) {
        // Base64 이미지인 경우
        qrDisplay.innerHTML = `<img src="${data.qrCode}" alt="QR Code" style="max-width: 300px;">`;
    } else if (data.challengeId) {
        // Challenge ID만 있는 경우
        qrDisplay.innerHTML = `
            <div style="color: #0f172a; text-align: center;">
                <p>Challenge ID:</p>
                <p style="font-size: 1.2rem; font-weight: bold;">${data.challengeId}</p>
                <p style="margin-top: 10px; font-size: 0.9rem;">QR 코드 생성 중...</p>
            </div>
        `;
    }
    
    // 상태 표시
    const statusDiv = document.getElementById('qr-status');
    statusDiv.textContent = 'QR 코드 생성됨 - 스캔 대기중...';
}

// QR 상태 모니터링
function monitorQRStatus(challengeId) {
    if (sseConnection) {
        sseConnection.close();
    }
    
    addLog(`QR 상태 모니터링 시작: ${challengeId}`, 'info');
    
    const eventSource = new EventSource(`/api/qr/sse/${challengeId}`);
    sseConnection = eventSource;
    
    eventSource.onopen = () => {
        addLog('SSE 연결 성공', 'success');
    };
    
    eventSource.onmessage = (event) => {
        try {
            const data = JSON.parse(event.data);
            updateQRStatus(data);
            addLog(`QR 상태 업데이트: ${data.status}`, 'info');
        } catch (error) {
            addLog('SSE 메시지 파싱 오류: ' + error.message, 'error');
        }
    };
    
    eventSource.onerror = (error) => {
        addLog('SSE 연결 오류', 'error');
        eventSource.close();
        sseConnection = null;
    };
}

// QR 상태 업데이트
function updateQRStatus(data) {
    const statusDiv = document.getElementById('qr-status');
    
    switch(data.status) {
        case 'PENDING':
            statusDiv.textContent = '⏳ QR 코드 스캔 대기중...';
            statusDiv.style.color = '#f59e0b';
            break;
        case 'APPROVED':
            statusDiv.textContent = '✅ QR 코드 승인됨!';
            statusDiv.style.color = '#10b981';
            if (data.token) {
                statusDiv.textContent += ` (토큰: ${data.token.substring(0, 20)}...)`;
            }
            break;
        case 'EXPIRED':
            statusDiv.textContent = '❌ QR 코드 만료됨';
            statusDiv.style.color = '#ef4444';
            break;
        case 'EXCHANGED':
            statusDiv.textContent = '🔄 토큰 교환 완료';
            statusDiv.style.color = '#2563eb';
            break;
        default:
            statusDiv.textContent = `상태: ${data.status}`;
    }
}