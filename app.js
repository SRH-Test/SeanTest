const express = require('express');
const mysql = require('mysql2');
const app = express();

// Database configuration
const connection = mysql.createConnection({
  host: 'localhost',
  user: 'root',
  password: 'SuperSecretPassword123!', // Note: Hardcoded password also triggers Secret Scanners
  database: 'test_db'
});

app.get('/api/user', (req, res) => {
  const userId = req.query.id;
  const sqlQuery = "SELECT * FROM users WHERE id = '" + userId + "'";

  connection.query(sqlQuery, (err, results) => {
    if (err) return res.status(500).send(err);
    res.json(results);
  });
});

app.get('/welcome', (req, res) => {
  const userName = req.query.name;

  const htmlResponse = `
    <h1>Welcome back, ${userName}!</h1>
  `;

  res.send(htmlResponse);
});

app.listen(3000, () => {
  console.log('Test server running on port 3000');
});
