import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';

import '../config/env.dart';
import '../storage/session_store.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// Wrapper over Dio that understands the backend `{ success, message, data }`
/// envelope, Firebase/JWT tokens, the `X-Branch-Id` header and 401 refresh.
class ApiClient {
  ApiClient(this.store, {this.onSessionExpired}) {
    dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBase,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 40),
        contentType: Headers.jsonContentType,
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  final SessionStore store;
  final void Function()? onSessionExpired;
  late final Dio dio;
  Completer<String?>? _refreshing;

  static const _publicPaths = [
    '/api/auth/login',
    '/api/auth/register',
    '/api/auth/refresh-token',
    '/api/auth/check-email',
    '/api/auth/forgot-password',
    '/api/auth/verify-otp',
    '/api/auth/reset-password',
    '/api/system/status',
  ];

  Future<String?> currentToken() async {
    try {
      final fb = FirebaseAuth.instance.currentUser;
      if (fb != null) return await fb.getIdToken();
    } catch (_) {
      /* Firebase not configured (e.g. web/dev) – fall back to stored token */
    }
    return store.session?.token;
  }

  Future<void> _onRequest(RequestOptions o, RequestInterceptorHandler h) async {
    final isPublic = _publicPaths.any(o.path.contains);
    if (!isPublic && !o.headers.containsKey('Authorization')) {
      final t = await currentToken();
      if (t != null && t.isNotEmpty) o.headers['Authorization'] = 'Bearer $t';
    }
    final branch = store.selectedBranchId;
    if (branch != null &&
        branch.isNotEmpty &&
        !o.headers.containsKey('X-Branch-Id')) {
      o.headers['X-Branch-Id'] = branch;
    }
    h.next(o);
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler h) async {
    final req = e.requestOptions;
    final is401 = e.response?.statusCode == 401;
    final skip =
        _publicPaths.any(req.path.contains) ||
        req.path.contains('/auth/google') ||
        req.path.contains('/auth/phone');
    if (is401 && !skip && req.extra['retried'] != true) {
      final t = await _refreshToken();
      if (t != null) {
        req.extra['retried'] = true;
        req.headers['Authorization'] = 'Bearer $t';
        try {
          return h.resolve(await dio.fetch(req));
        } on DioException catch (e2) {
          return h.next(e2);
        }
      }
      onSessionExpired?.call();
    }
    h.next(e);
  }

  Future<String?> _refreshToken() async {
    if (_refreshing != null) return _refreshing!.future;
    final c = _refreshing = Completer<String?>();
    String? result;
    try {
      final fb = FirebaseAuth.instance.currentUser;
      if (fb != null) {
        result = await fb.getIdToken(true);
      } else {
        final rt = store.session?.refreshToken;
        if (rt != null && rt.isNotEmpty) {
          final r = await Dio(BaseOptions(baseUrl: Env.apiBase))
              .post('/api/auth/refresh-token', data: {'refreshToken': rt});
          final d = (r.data is Map ? r.data['data'] : null) ?? {};
          result = (d['idToken'] ?? d['token'])?.toString();
          if (result != null && store.session != null) {
            await store.save(
              store.session!.copyWith(
                token: result,
                refreshToken: d['refreshToken']?.toString(),
              ),
            );
          }
        }
      }
    } catch (_) {
      result = null;
    }
    c.complete(result);
    _refreshing = null;
    return result;
  }

  ApiException _wrap(Object e) {
    if (e is ApiException) return e;
    if (e is DioException) {
      final d = e.response?.data;
      String? msg;
      if (d is Map) msg = (d['message'] ?? d['error'])?.toString();
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        msg = kIsWeb
            ? 'Server not reachable from the browser (CORS). Run Chrome on port 5173: flutter run -d chrome --web-port 5173, or use an Android device.'
            : 'No internet connection. Please try again.';
      }
      return ApiException(
        msg ?? 'Something went wrong (${e.response?.statusCode ?? 'network'})',
        status: e.response?.statusCode,
      );
    }
    return ApiException(e.toString());
  }

  dynamic _data(Response r) {
    final b = r.data;
    if (b is Map && b.containsKey('success')) {
      if (b['success'] == false)
        throw ApiException(b['message']?.toString() ?? 'Request failed');
      return b['data'];
    }
    return b;
  }

  Map<String, dynamic>? _clean(Map<String, dynamic>? q) => q == null
      ? null
      : (Map.of(q)
          ..removeWhere((k, v) => v == null || (v is String && v.isEmpty)));

  Future<dynamic> get(String path, {Map<String, dynamic>? q}) async {
    try {
      return _data(await dio.get(path, queryParameters: _clean(q)));
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? q,
    Options? options,
  }) async {
    try {
      return _data(
        await dio.post(
          path,
          data: body ?? {},
          queryParameters: _clean(q),
          options: options,
        ),
      );
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, dynamic>? q,
  }) async {
    try {
      return _data(
        await dio.put(path, data: body ?? {}, queryParameters: _clean(q)),
      );
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? q,
  }) async {
    try {
      return _data(
        await dio.patch(path, data: body ?? {}, queryParameters: _clean(q)),
      );
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? q,
  }) async {
    try {
      return _data(
        await dio.delete(path, data: body, queryParameters: _clean(q)),
      );
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<List<int>> bytes(String path, {Map<String, dynamic>? q}) async {
    try {
      final r = await dio.get<List<int>>(
        path,
        queryParameters: _clean(q),
        options: Options(responseType: ResponseType.bytes),
      );
      return r.data ?? [];
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<dynamic> upload(
    String path,
    String field, {
    String? filePath,
    List<int>? bytes,
    String? filename,
  }) async {
    try {
      final name = _uploadFilename(filename, filePath);
      final ext = name.split('.').last.toLowerCase();
      final mime = ext == 'png'
          ? 'png'
          : (ext == 'webp'
              ? 'webp'
              : (ext == 'gif' ? 'gif' : 'jpeg'));
      MultipartFile file;
      if (bytes != null && bytes.isNotEmpty) {
        file = MultipartFile.fromBytes(
          Uint8List.fromList(bytes),
          filename: name,
          contentType: DioMediaType('image', mime),
        );
      } else if (filePath != null && filePath.isNotEmpty && !kIsWeb) {
        file = await MultipartFile.fromFile(
          filePath,
          filename: name,
          contentType: DioMediaType('image', mime),
        );
      } else {
        throw ApiException('Upload requires file data');
      }
      final form = FormData.fromMap({field: file});
      return _data(
        await dio.post(
          path,
          data: form,
          options: Options(
            contentType: Headers.multipartFormDataContentType,
          ),
        ),
      );
    } catch (e) {
      throw _wrap(e);
    }
  }

  static String _uploadFilename(String? filename, String? filePath) {
    var name = (filename ?? '').trim();
    if (name.isEmpty || name.startsWith('blob:')) {
      final fromPath = (filePath ?? '')
          .split('/')
          .last
          .split('\\')
          .last;
      name = fromPath.startsWith('blob:') ? '' : fromPath;
    }
    name = name.split('/').last.split('\\').last;
    if (name.isEmpty || !name.contains('.')) {
      return name.isEmpty ? 'image.jpg' : '$name.jpg';
    }
    return name;
  }
}
