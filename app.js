const express = require('express');
const { rateLimit } = require('express-rate-limit');
const mysql = require('mysql2');
const app = express();
const apiUserRateLimit = rateLimit({
  windowMs: 60_000,
  limit: 60,
  standardHeaders: 'draft-7',
  legacyHeaders: false
});

const connection = mysql.createConnection({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'test_db'
});

app.get('/api/user', apiUserRateLimit, (req, res) => {
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
