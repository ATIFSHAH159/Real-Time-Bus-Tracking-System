// server.js
const express = require('express');
const axios = require('axios');
const app = express();
const cors = require('cors');
app.use(cors());

const GOOGLE_API_KEY = 'AIzaSyAopwURP-RbAZXSJgAP9GazKct9ILADHgc';

app.get('/directions', async (req, res) => {
  const { origin, destination, waypoints } = req.query;
  let url = `https://maps.googleapis.com/maps/api/directions/json?origin=${origin}&destination=${destination}&key=${GOOGLE_API_KEY}`;
  if (waypoints) url += `&waypoints=${waypoints}`;
  try {
    const response = await axios.get(url);
    res.json(response.data);
  } catch (err) {
    res.status(500).json({ error: err.toString() });
  }
});

app.listen(3000, () => console.log('Proxy listening on port 3000'));