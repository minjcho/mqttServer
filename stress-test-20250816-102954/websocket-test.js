const SockJS = require('sockjs-client');

const args = process.argv.slice(2);
const connections = parseInt(args[0]) || 100;
const host = args[1] || 'https://minjcho.site';
const baseOrinId = args[2] || 'stress';

let connected = 0;
let failed = 0;
const sockets = [];
const startTime = Date.now();

for (let i = 0; i < connections; i++) {
    setTimeout(() => {
        try {
            const orinId = `${baseOrinId}${i}`;
            const socket = new SockJS(`${host}/coordinates?orinId=${orinId}`);
            
            socket.onopen = () => {
                connected++;
                sockets.push(socket);
            };
            
            socket.onerror = (error) => {
                failed++;
            };
            
        } catch (error) {
            failed++;
        }
    }, i * 10);
}

setTimeout(() => {
    const duration = (Date.now() - startTime) / 1000;
    console.log(`${connections},${connected},${failed},${duration}`);
    
    sockets.forEach(socket => {
        try { socket.close(); } catch(e) {}
    });
    
    process.exit(0);
}, connections * 10 + 5000);
