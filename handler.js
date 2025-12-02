const https = require('https');

/**
 * Lambda handler to proxy weather API requests
 * @param {Object} event - API Gateway event
 * @param {Object} context - Lambda context
 * @returns {Object} API Gateway response
 */
exports.getWeather = async (event, context) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  try {
    // Get query parameters
    const q = event.queryStringParameters?.q;
    const lang = event.queryStringParameters?.lang || 'en-US';

    // Validate required parameters
    if (!q) {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({
          error: 'Missing required parameter: q (location)'
        })
      };
    }

    // Get API key from environment
    const apiKey = process.env.WEATHER_API_KEY;
    if (!apiKey) {
      console.error('WEATHER_API_KEY not configured');
      return {
        statusCode: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({
          error: 'Server configuration error'
        })
      };
    }

    // Build URL for weather API
    const url = `https://api.weatherapi.com/v1/current.json?q=${encodeURIComponent(q)}&lang=${encodeURIComponent(lang)}&key=${apiKey}`;
    
    console.log('Fetching weather data for location:', q);

    // Make request to weather API
    const weatherData = await makeHttpsRequest(url);

    // Return successful response
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify(weatherData)
    };

  } catch (error) {
    console.error('Error fetching weather data:', error);
    
    return {
      statusCode: error.statusCode || 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        error: error.message || 'Failed to fetch weather data',
        details: error.details || null
      })
    };
  }
};

/**
 * Make HTTPS request
 * @param {string} url - URL to request
 * @returns {Promise<Object>} Parsed JSON response
 */
function makeHttpsRequest(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';

      // Handle non-200 status codes
      if (res.statusCode !== 200) {
        res.resume(); // Consume response data to free up memory
        reject({
          statusCode: res.statusCode,
          message: `Weather API returned status ${res.statusCode}`,
          details: `HTTP ${res.statusCode} - ${res.statusMessage}`
        });
        return;
      }

      // Accumulate data chunks
      res.on('data', (chunk) => {
        data += chunk;
      });

      // Parse and resolve when complete
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve(parsed);
        } catch (e) {
          reject({
            statusCode: 500,
            message: 'Failed to parse weather API response',
            details: e.message
          });
        }
      });

    }).on('error', (err) => {
      reject({
        statusCode: 500,
        message: 'Failed to connect to weather API',
        details: err.message
      });
    });
  });
}
