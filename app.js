const express = require('express');
const mysql = require('mysql2');
const app = express();
const apiRequestCounts = new Map();
const apiRequestLimit = 60;
const apiRequestWindowMs = 60_000;
const maxTrackedClients = 10_000;

const connection = mysql.createConnection({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'test_db'
});

function rateLimitApiUserLookup(req, res, next) {
  const now = Date.now();
  let requestWindow = apiRequestCounts.get(req.ip);

  if (!requestWindow || now >= requestWindow.resetAt) {
    if (apiRequestCounts.size >= maxTrackedClients) {
      apiRequestCounts.delete(apiRequestCounts.keys().next().value);
    }
    requestWindow = { count: 0, resetAt: now + apiRequestWindowMs };
    apiRequestCounts.set(req.ip, requestWindow);
  }

  requestWindow.count += 1;
  if (requestWindow.count > apiRequestLimit) {
    return res.status(429).send('Too many requests');
  }
  return next();
}

app.get('/api/user', rateLimitApiUserLookup, (req, res) => {
  const userId = req.query.id;
  if (typeof userId !== 'string') {
    return res.status(400).send('A user ID is required');
  }

  connection.query('SELECT * FROM users WHERE id = ?', [userId], (err, results) => {
    if (err) return res.status(500).send('Unable to retrieve user');
    res.json(results);
  });
});

app.get('/welcome', (req, res) => {
  const userName = req.query.name;
  if (typeof userName !== 'string') {
    return res.status(400).send('A name is required');
  }

  const escapedName = userName.replace(/[&<>"']/g, (character) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  })[character]);

  res.type('html').send(`<h1>Welcome back, ${escapedName}!</h1>`);
});

app.listen(3000, () => {
  console.log('Test server running on port 3000');
});
