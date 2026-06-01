function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // Requests without a file extension are React client-side routes;
    // serve index.html so the SPA router can handle them.
    if (!uri.includes('.')) {
        request.uri = '/index.html';
    }

    return request;
}
