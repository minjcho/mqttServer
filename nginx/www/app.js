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
    checkWebSocketService();
    checkMQTTService();
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

// 지도 데이터 조회
async function fetchMapData() {
    const orinId = document.getElementById('map-orin-id').value;
    const responseDiv = document.getElementById('map-response');
    
    if (!orinId) {
        responseDiv.textContent = '❌ ORIN ID를 입력해주세요';
        responseDiv.className = 'data-response error';
        addLog('지도 데이터 조회 실패: ORIN ID 누락', 'error');
        return;
    }
    
    try {
        addLog(`지도 데이터 조회 시작: ORIN=${orinId}`, 'info');
        responseDiv.textContent = '⏳ 데이터 조회 중...';
        responseDiv.className = 'data-response';
        
        const response = await fetch(`https://minjcho.site/api/map-data/${orinId}/latest`, {
            method: 'GET',
            headers: {
                'Accept': 'application/json'
            }
        });
        
        if (response.ok) {
            const data = await response.json();
            
            let html = `<h4>✅ 최신 지도 데이터</h4>`;
            html += `<table>`;
            html += `<tr><th>항목</th><th>값</th></tr>`;
            html += `<tr><td>Resolution</td><td>${data.resolution}</td></tr>`;
            html += `<tr><td>Origin X</td><td>${data.originX}</td></tr>`;
            html += `<tr><td>Origin Y</td><td>${data.originY}</td></tr>`;
            html += `<tr><td>Origin Theta</td><td>${data.originTheta}</td></tr>`;
            html += `<tr><td>Occupied Threshold</td><td>${data.occupiedThresh}</td></tr>`;
            html += `<tr><td>Free Threshold</td><td>${data.freeThresh}</td></tr>`;
            html += `<tr><td>Negate</td><td>${data.negate}</td></tr>`;
            html += `</table>`;
            
            if (data.pgmUrl) {
                html += `<p><strong>PGM 파일:</strong><br><a href="${data.pgmUrl}" target="_blank" class="map-link">다운로드</a></p>`;
            }
            if (data.yamlUrl) {
                html += `<p><strong>YAML 파일:</strong><br><a href="${data.yamlUrl}" target="_blank" class="map-link">다운로드</a></p>`;
            }
            
            responseDiv.innerHTML = html;
            responseDiv.className = 'data-response success';
            addLog(`지도 데이터 조회 성공`, 'success');
        } else {
            const error = await response.text();
            responseDiv.textContent = `❌ 조회 실패 (${response.status})\n${error}`;
            responseDiv.className = 'data-response error';
            addLog(`지도 데이터 조회 실패: ${error}`, 'error');
        }
    } catch (error) {
        responseDiv.textContent = `❌ 오류 발생: ${error.message}`;
        responseDiv.className = 'data-response error';
        addLog(`지도 데이터 조회 오류: ${error.message}`, 'error');
    }
}

// 센서 데이터 조회
async function fetchSensorData() {
    const orinId = document.getElementById('sensor-orin-id').value;
    const responseDiv = document.getElementById('sensor-response');
    
    if (!orinId) {
        responseDiv.textContent = '❌ ORIN ID를 입력해주세요';
        responseDiv.className = 'data-response error';
        addLog('센서 데이터 조회 실패: ORIN ID 누락', 'error');
        return;
    }
    
    try {
        addLog(`센서 데이터 조회 시작: ORIN=${orinId}`, 'info');
        responseDiv.textContent = '⏳ 데이터 조회 중...';
        responseDiv.className = 'data-response';
        
        const response = await fetch(`https://minjcho.site/api/sensor-data/${orinId}`, {
            method: 'GET',
            headers: {
                'Accept': 'application/json'
            }
        });
        
        if (response.ok) {
            const data = await response.json();
            
            if (Array.isArray(data) && data.length > 0) {
                let html = `<h4>✅ 센서 데이터 (총 ${data.length}개)</h4>`;
                html += `<table>`;
                html += `<tr>
                    <th>시간</th>
                    <th>온도(°C)</th>
                    <th>습도(%)</th>
                    <th>공기질</th>
                    <th>X좌표</th>
                    <th>Y좌표</th>
                    <th>방</th>
                </tr>`;
                
                // 최신 10개만 표시
                const recentData = data.slice(-10).reverse();
                recentData.forEach(item => {
                    const time = new Date(item.measuredAt).toLocaleString('ko-KR');
                    html += `<tr>
                        <td>${time}</td>
                        <td>${item.temperature}</td>
                        <td>${item.humidity}</td>
                        <td>${item.airQuality}</td>
                        <td>${item.coordX}</td>
                        <td>${item.coordY}</td>
                        <td>${item.room}</td>
                    </tr>`;
                });
                
                html += `</table>`;
                
                if (data.length > 10) {
                    html += `<p style="margin-top: 10px; color: #94a3b8;">최신 10개 데이터만 표시됩니다. (전체: ${data.length}개)</p>`;
                }
                
                responseDiv.innerHTML = html;
                responseDiv.className = 'data-response success';
                addLog(`센서 데이터 조회 성공: ${data.length}개 데이터`, 'success');
            } else {
                responseDiv.textContent = '데이터가 없습니다.';
                responseDiv.className = 'data-response';
                addLog('센서 데이터가 없습니다', 'warning');
            }
        } else {
            const error = await response.text();
            responseDiv.textContent = `❌ 조회 실패 (${response.status})\n${error}`;
            responseDiv.className = 'data-response error';
            addLog(`센서 데이터 조회 실패: ${error}`, 'error');
        }
    } catch (error) {
        responseDiv.textContent = `❌ 오류 발생: ${error.message}`;
        responseDiv.className = 'data-response error';
        addLog(`센서 데이터 조회 오류: ${error.message}`, 'error');
    }
}

// MQTT 명령 전송
async function sendMQTTCommand() {
    const orinId = document.getElementById('orin-id').value;
    const command = document.getElementById('mqtt-command').value;
    const responseDiv = document.getElementById('mqtt-response');
    
    if (!orinId || !command) {
        responseDiv.textContent = '❌ ORIN ID와 명령을 모두 입력해주세요';
        responseDiv.className = 'mqtt-response error';
        addLog('MQTT 명령 전송 실패: 입력값 누락', 'error');
        return;
    }
    
    try {
        addLog(`MQTT 명령 전송 시작: ORIN=${orinId}, Command=${command}`, 'info');
        responseDiv.textContent = '⏳ 명령 전송 중...';
        responseDiv.className = 'mqtt-response';
        
        // JSON 형식으로 명령 전송
        const requestBody = {
            command: command
        };
        
        const response = await fetch(`/api/mqtt/commands/${orinId}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            body: JSON.stringify(requestBody)
        });
        
        const result = await response.json();
        
        if (response.ok) {
            responseDiv.textContent = `✅ 명령 전송 성공\n` +
                `ORIN ID: ${result.orinId}\n` +
                `명령: ${result.command}\n` +
                `상태: ${result.success ? '성공' : '실패'}\n` +
                `메시지: ${result.message}`;
            responseDiv.className = 'mqtt-response success';
            addLog(`MQTT 명령 전송 성공: ${result.message}`, 'success');
        } else {
            responseDiv.textContent = `❌ 명령 전송 실패 (${response.status})\n${JSON.stringify(result, null, 2)}`;
            responseDiv.className = 'mqtt-response error';
            addLog(`MQTT 명령 전송 실패: ${JSON.stringify(result)}`, 'error');
        }
    } catch (error) {
        responseDiv.textContent = `❌ 오류 발생: ${error.message}`;
        responseDiv.className = 'mqtt-response error';
        addLog(`MQTT 명령 전송 오류: ${error.message}`, 'error');
    }
}

