const express = require('express');
const cors = require('cors');
const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

let tasks = [
  {
    id: '1',
    name: 'Initial Task',
    start: '2024-01-01',
    end: '2024-01-07',
    progress: 20,
    dependencies: ''
  }
];

app.get('/api/tasks', (req, res) => {
  res.json(tasks);
});

app.post('/api/tasks', (req, res) => {
  const { name, start, end, progress, dependencies } = req.body;
  const id = String(Date.now());
  const task = { id, name, start, end, progress: progress || 0, dependencies: dependencies || '' };
  tasks.push(task);
  res.status(201).json(task);
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
