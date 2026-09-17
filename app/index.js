const express = require('express');

const app = express();
const region = process.env.APP_REGION || 'unknown';
const spaceName = process.env.APP_SPACE_NAME || null;
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({
    message: spaceName
      ? `Hello from the ${spaceName} instance (region: ${region})`
      : `Hello from the ${region} instance`,
    space_name: spaceName,
    region,
    dyno: process.env.DYNO || 'local',
    time: new Date().toISOString(),
  });
});

app.listen(port, () => {
  console.log(`web dyno up: space_name=${spaceName || 'n/a'} region=${region} port=${port}`);
});
