import 'package:dart_frog/dart_frog.dart';

Handler middleware(Handler handler) {
  return handler.use(requestLogger()).use((innerHandler) {
    return (context) async {
      // Handle CORS preflight cleanly
      if (context.request.method == HttpMethod.options) {
        return Response(
          statusCode: 204,
          headers: _corsHeaders,
        );
      }

      try {
        final response = await innerHandler(context);
        return response.copyWith(
          headers: {
            ...response.headers,
            ..._corsHeaders,
          },
        );
      } catch (e) {
        return Response.json(
          statusCode: 500,
          body: {'error': e.toString()},
          headers: _corsHeaders,
        );
      }
    };
  });
}

const Map<String, Object> _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PATCH, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};
