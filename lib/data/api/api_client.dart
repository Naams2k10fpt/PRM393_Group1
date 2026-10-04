import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// The one HTTP client for the PRN232 REST API. Repositories call [get]/[post]/[put]; screens never use Dio.
///
/// - Base URL is read from [AppConfig.baseUrl] on every request.
/// - Attaches `Authorization: Bearer <token>` unless the call passes `auth: false`.
/// - A 401 on an authenticated call means the token was revoked or expired: the token is cleared and
///   [onUnauthorized] fires, so the app sends the user to login from one place.
/// - Every failure becomes an [ApiException].
class ApiClient {
  ApiClient({required this.tokens, Dio? dio}) : dio = dio ?? Dio() {
    this.dio.options
      // Render's free tier sleeps; the first request after idle can take ~60 s.
      ..connectTimeout = const Duration(seconds: 60)
      ..receiveTimeout = const Duration(seconds: 60)
      ..contentType = Headers.jsonContentType
      ..responseType = ResponseType.json;
    this.dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  final Dio dio;
  final TokenStorage tokens;

  /// Called after a 401 on an authenticated request (the token is already cleared).
  void Function()? onUnauthorized;

  static const _authExtra = 'auth';

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? data, bool auth = true}) =>
      _send(() => dio.post<dynamic>(path, data: data, options: Options(extra: {_authExtra: auth})));

  Future<dynamic> put(String path, {Object? data}) => _send(() => dio.put<dynamic>(path, data: data));

  /// For SignalR `accessTokenFactory`: hubs take the same token as `?access_token=`.
  Future<String> accessToken() async => await tokens.read() ?? '';

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    options.baseUrl = AppConfig.baseUrl;
    if (options.extra[_authExtra] != false) {
      final token = await tokens.read();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  Future<void> _onError(DioException error, ErrorInterceptorHandler handler) async {
    final sentToken = error.requestOptions.headers.containsKey('Authorization');
    if (error.response?.statusCode == 401 && sentToken) {
      await tokens.clear();
      onUnauthorized?.call();
    }
    handler.next(error);
  }

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      return (await request()).data;
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  static ApiException toApiException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          code: ApiException.timeout,
          message: 'Máy chủ phản hồi quá lâu. Vui lòng thử lại.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          code: ApiException.networkError,
          message: 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.',
        );
      default:
        break;
    }

    final response = error.response;
    final body = response?.data;
    if (body is Map && body['code'] is String) {
      final errors = <String, List<String>>{};
      final rawErrors = body['errors'];
      if (rawErrors is Map) {
        rawErrors.forEach((key, value) {
          if (value is List) errors['$key'] = value.map((e) => '$e').toList();
        });
      }
      return ApiException(
        code: body['code'] as String,
        message: (body['message'] as String?) ?? 'Đã có lỗi xảy ra.',
        statusCode: response?.statusCode,
        fieldErrors: errors,
        retryAfterSeconds: (body['retryAfterSeconds'] as num?)?.toInt(),
      );
    }

    return ApiException(
      code: ApiException.unknown,
      message: 'Đã có lỗi xảy ra (${response?.statusCode ?? 'không có phản hồi'}). Vui lòng thử lại.',
      statusCode: response?.statusCode,
    );
  }
}
