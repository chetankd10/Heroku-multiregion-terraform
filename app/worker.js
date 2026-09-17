const region = process.env.APP_REGION || 'unknown';
const spaceName = process.env.APP_SPACE_NAME || null;

function heartbeat() {
  console.log(`[worker] space_name=${spaceName || 'n/a'} region=${region} heartbeat at ${new Date().toISOString()}`);
}

heartbeat();
setInterval(heartbeat, 30000);
