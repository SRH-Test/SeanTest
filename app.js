const express = require('express');
const mysql = require('mysql2');
const { rateLimit } = require('express-rate-limit');

const requiredConfig = ['DB_HOST', 'DB_USER', 'DB_PASSWORD', 'DB_NAME'];
const missingConfig = requiredConfig.filter((key) => !process.env[key]);

if (missingConfig.length > 0) {
  throw new Error(`Missing required database configuration: ${missingConfig.join(', ')}`);
}

const app = express();
const connection = mysql.createConnection({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME
});

app.use('/api/user', rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 100,
  standardHeaders: true,
  legacyHeaders: false
}));

function escapeHtml(value) {
  return value.replace(/[&<>"']/g, (character) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  })[character]);
}

app.get('/api/user', (req, res) => {
  const userId = req.query.id;

  if (typeof userId !== 'string') {
    return res.status(400).send('Invalid user ID');
  }

  connection.query('SELECT * FROM users WHERE id = ?', [userId], (err, results) => {
    if (err) {
      return res.status(500).send('Unable to retrieve user');
    }

    res.json(results);
  });
});

app.get('/welcome', (req, res) => {
  const userName = typeof req.query.name === 'string' ? req.query.name : '';
  const htmlResponse = `
    <html>
      <body>
        <h1>Welcome back, ${escapeHtml(userName)}!</h1>
      </body>
    </html>
  `;

  res.send(htmlResponse);
});

app.listen(3000, () => {
  console.log('Test server running on port 3000');
});
