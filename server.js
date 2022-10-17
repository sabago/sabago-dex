const express = require('express');
const path = require('path');
const port = process.env.PORT || 3000; // Heroku will need the PORT environment variable


const app = express();
app.use(express.static(path.join(__dirname, 'build')));
// app.use(express.static('sabago-blockchain/build'));
// app.get('*', (req, res) => res.sendFile(path.resolve(__dirname, 'reactFolderName', 'build', 'index.html')));
app.listen(process.env.PORT || 3000, function(){
  console.log(`App is live on port ${port}!`);
});