const express = require('express');
const { rateLimit } = require('express-rate-limit');
const mysql = require('mysql2');
const app = express();

const userLookupLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 60,
  standardHeaders: 'draft-8',
  legacyHeaders: false
});

const connection = mysql.createConnection({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'test_db'
});

app.get('/api/user', userLookupLimiter, (req, res) => {
  const userId = req.query.id;
  if (typeof userId !== 'string') {
    return res.status(400).send('A single user ID is required');
  }

  connection.execute('SELECT * FROM users WHERE id = ?', [userId], (err, results) => {
    if (err) return res.status(500).send('Unable to retrieve user');
    res.json(results);
  });
});

app.get('/welcome', (req, res) => {
  const userName = String(req.query.name ?? '');
  const escapedName = userName.replace(/[&<>"']/g, (character) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  })[character]);

  res.type('html').send(`
    <html>
      <body>
        <h1>Welcome back, ${escapedName}!</h1>
      </body>
    </html>
  `);
});

app.listen(process.env.PORT || 3000, () => {
  console.log('Test server running');
});
