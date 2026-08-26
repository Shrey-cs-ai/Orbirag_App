import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:orbirag/core/error_message/error_message.dart';

class AppException implements Exception {
  final int statusCode;
  final String message;

  AppException(this.statusCode, this.message);

  @override
  String toString() => 'Error $statusCode: $message';
}

dynamic handleResponse(http.Response response) {
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw AppException(
      response.statusCode,
      ErrorMessages.fromStatusCode(response.statusCode),
    );
  }
}