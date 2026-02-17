const http = require('http');
const https = require('https');
const url = require('url');

const PORT = 3000;

const server = http.createServer((req, res) => {
  // Configurar CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'content-type, x-api-key, anthropic-version');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  if (req.method === 'POST' && req.url === '/v1/messages') {
    let body = '';
    req.on('data', chunk => {
      body += chunk.toString();
    });

    req.on('end', () => {
      const anthropicReq = https.request({
        hostname: 'api.anthropic.com',
        path: '/v1/messages',
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-api-key': req.headers['x-api-key'],
          'anthropic-version': '2023-06-01'
        }
      }, (anthropicRes) => {
        res.writeHead(anthropicRes.statusCode, anthropicRes.headers);
        anthropicRes.pipe(res);
      });

      anthropicReq.on('error', (e) => {
        console.error(e);
        res.writeHead(500);
        res.end(JSON.stringify({ error: e.message }));
      });

      anthropicReq.write(body);
      anthropicReq.end();
    });
  } else {
    res.writeHead(404);
    res.end('Not Found');
  }
});

server.listen(PORT, () => {
  console.log(`Proxy local corriendo en http://localhost:${PORT}`);
  console.log('Use este endpoint en su app Flutter para evitar CORS.');
});
