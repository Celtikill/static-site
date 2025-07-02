// CloudFront Function for Security Headers
// Adds comprehensive security headers to all responses

function handler(event) {
    var response = event.response;
    var headers = response.headers;

    // Security Headers
    headers['strict-transport-security'] = { value: 'max-age=31536000; includeSubDomains; preload' };
    headers['x-content-type-options'] = { value: 'nosniff' };
    headers['x-frame-options'] = { value: 'DENY' };
    headers['x-xss-protection'] = { value: '1; mode=block' };
    headers['referrer-policy'] = { value: 'strict-origin-when-cross-origin' };
    
    // Content Security Policy
    headers['content-security-policy'] = { 
        value: "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' https:; connect-src 'self'; frame-ancestors 'none';" 
    };
    
    // Permissions Policy (formerly Feature Policy)
    headers['permissions-policy'] = { 
        value: 'camera=(), microphone=(), geolocation=(), interest-cohort=()' 
    };

    // Cache Control for static assets
    if (event.request.uri.match(/\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$/)) {
        headers['cache-control'] = { value: 'public, max-age=31536000, immutable' };
    } else if (event.request.uri.match(/\.(html|htm)$/)) {
        headers['cache-control'] = { value: 'public, max-age=300' };
    }

    return response;
}