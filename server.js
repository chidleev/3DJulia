const express = require("express")
const path = require("path")
const http = require("http")
const PORT = process.env.PORT || 3000
const app = express()
const server = http.createServer(app)

app.use(express.static(path.join(__dirname, "public")))
app.use('/build/', express.static(path.join(__dirname, 'node_modules/three/build')));
app.use('/jsm/', express.static(path.join(__dirname, 'node_modules/three/examples/jsm')));

server.listen(PORT, () => {console.log(`Server running on port ${PORT}`)})