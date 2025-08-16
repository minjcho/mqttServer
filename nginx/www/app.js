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
        const response = await fetch('/api/qr/health', {
            method: 'GET',
            mode: 'cors'
        });
        
        if (response.ok || response.status === 404) {
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
    
    if (wsConnection && wsConnection.readyState === WebSocket.OPEN) {
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
    
    try {
        // MQTT over WebSocket 연결 테스트
        const testWs = new WebSocket('wss://minjcho.site/api/mqtt');
        
        testWs.onopen = () => {
            statusDiv.textContent = '온라인';
            statusDiv.className = 'service-status online';
            document.getElementById('mqtt-status').className = 'status-dot online';
            addLog('MQTT Broker 연결 확인', 'success');
            testWs.close();
        };
        
        testWs.onerror = () => {
            statusDiv.textContent = '오프라인';
            statusDiv.className = 'service-status offline';
            document.getElementById('mqtt-status').className = 'status-dot offline';
            addLog('MQTT Broker 연결 실패', 'error');
        };
        
        setTimeout(() => {
            if (testWs.readyState === WebSocket.CONNECTING) {
                testWs.close();
                statusDiv.textContent = '타임아웃';
                statusDiv.className = 'service-status offline';
                document.getElementById('mqtt-status').className = 'status-dot offline';
            }
        }, 5000);
    } catch (error) {
        statusDiv.textContent = '오프라인';
        statusDiv.className = 'service-status offline';
        document.getElementById('mqtt-status').className = 'status-dot offline';
        addLog('MQTT Broker 연결 실패: ' + error.message, 'error');
    }
}

// QR 서비스 테스트
async function testQRService() {
    try {
        addLog('QR Login Service 테스트 시작...', 'info');
        const response = await fetch('/api/auth/test', {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        if (response.ok) {
            const data = await response.json();
            addLog('QR Login Service 테스트 성공: ' + JSON.stringify(data), 'success');
        } else {
            addLog('QR Login Service 테스트 실패: ' + response.status, 'error');
        }
    } catch (error) {
        addLog('QR Login Service 테스트 오류: ' + error.message, 'error');
    }
}

// WebSocket 연결 테스트
function testWebSocket() {
    if (wsConnection && wsConnection.readyState === WebSocket.OPEN) {
        addLog('WebSocket 이미 연결되어 있습니다', 'warning');
        return;
    }
    
    addLog('WebSocket 연결 시도...', 'info');
    document.getElementById('ws-status').className = 'status-dot connecting';
    
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    wsConnection = new WebSocket(`${protocol}//minjcho.site/coordinates`);
    
    wsConnection.onopen = () => {
        addLog('WebSocket 연결 성공', 'success');
        document.getElementById('ws-status').className = 'status-dot online';
        checkWebSocketService();
    };
    
    wsConnection.onmessage = (event) => {
        try {
            const data = JSON.parse(event.data);
            updateCoordinateDisplay(data);
            addLog(`좌표 수신: X=${data.coordX}, Y=${data.coordY}`, 'info');
        } catch (error) {
            addLog('WebSocket 메시지 파싱 오류: ' + error.message, 'error');
        }
    };
    
    wsConnection.onerror = (error) => {
        addLog('WebSocket 오류: ' + error.message, 'error');
        document.getElementById('ws-status').className = 'status-dot offline';
    };
    
    wsConnection.onclose = () => {
        addLog('WebSocket 연결 종료', 'warning');
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
    addLog('MQTT 브로커 테스트 시작...', 'info');
    
    const mqttWs = new WebSocket('wss://minjcho.site/api/mqtt');
    
    mqttWs.onopen = () => {
        addLog('MQTT WebSocket 연결 성공', 'success');
        
        // 테스트 메시지 전송
        const testMessage = {
            topic: 'test/topic',
            message: 'Hello MQTT',
            timestamp: new Date().toISOString()
        };
        
        mqttWs.send(JSON.stringify(testMessage));
        addLog('MQTT 테스트 메시지 전송: ' + JSON.stringify(testMessage), 'info');
        
        setTimeout(() => mqttWs.close(), 3000);
    };
    
    mqttWs.onmessage = (event) => {
        addLog('MQTT 메시지 수신: ' + event.data, 'success');
    };
    
    mqttWs.onerror = (error) => {
        addLog('MQTT WebSocket 오류: ' + error.message, 'error');
    };
    
    mqttWs.onclose = () => {
        addLog('MQTT WebSocket 연결 종료', 'info');
    };
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
            statusDiv.style.color = var(--warning-color);
            break;
        case 'APPROVED':
            statusDiv.textContent = '✅ QR 코드 승인됨!';
            statusDiv.style.color = var(--secondary-color);
            if (data.token) {
                statusDiv.textContent += ` (토큰: ${data.token.substring(0, 20)}...)`;
            }
            break;
        case 'EXPIRED':
            statusDiv.textContent = '❌ QR 코드 만료됨';
            statusDiv.style.color = var(--danger-color);
            break;
        case 'EXCHANGED':
            statusDiv.textContent = '🔄 토큰 교환 완료';
            statusDiv.style.color = var(--primary-color);
            break;
        default:
            statusDiv.textContent = `상태: ${data.status}`;
    }
}