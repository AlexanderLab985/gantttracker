# GanttTracker Prototype

This repository contains a minimal prototype for a GanttPRO-like service as described in the technical specification. It consists of a small Express backend and a very simple frontend page that displays tasks using the Frappe Gantt library.

## Structure

- `backend/` – Node.js Express API with endpoints to list and create tasks.
- `frontend/` – static frontend served with `http-server` that fetches tasks from the backend and renders a Gantt chart.

## Running

1. **Backend**
   ```bash
   cd backend
   npm install
   npm start
   ```
   The API will be available on `http://localhost:3001`.

2. **Frontend**
   In another terminal:
   ```bash
   cd frontend
   npm install
   npm start
   ```
   Open `http://localhost:3000` in your browser to see the Gantt chart.

Both parts are intentionally lightweight and can be extended according to the full technical specification.
