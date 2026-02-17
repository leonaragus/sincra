// Vercel Serverless Function (Edge)
// This file acts as a proxy for Anthropic API to bypass CORS
export const config = {
  runtime: 'edge', // Usamos Edge Runtime para menor latencia y costo
};

export default async function handler(req) {
  // Manejo de CORS Preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'content-type, x-api-key, anthropic-version',
      },
    });
  }

  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  try {
    const body = await req.json();
    
    // Obtenemos la API Key desde las variables de entorno de Vercel (preferible)
    // O desde el header de la petición (menos seguro pero flexible para desarrollo)
    const apiKey = process.env.ANTHROPIC_API_KEY || req.headers.get('x-api-key');

    if (!apiKey) {
      return new Response(JSON.stringify({ error: 'Missing API Key' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    const data = await response.json();

    return new Response(JSON.stringify(data), {
      status: response.status,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*', // Permitir respuesta al cliente
      },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    });
  }
}
