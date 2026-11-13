import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/app_constants.dart';

class ChatConversationSummary {
  final String id;
  final String title;
  final String sessionType;
  final String? paperId;
  final int messageCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ChatConversationSummary({
    required this.id,
    required this.title,
    required this.sessionType,
    this.paperId,
    required this.messageCount,
    this.createdAt,
    this.updatedAt,
  });

  factory ChatConversationSummary.fromJson(Map<String, dynamic> json) {
    return ChatConversationSummary(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Chat',
      sessionType: json['session_type'] as String? ?? 'ori_chat',
      paperId: json['paper_id'] as String?,
      messageCount: json['message_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}

class ChatMessageItem {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final dynamic sources;
  final DateTime? createdAt;

  ChatMessageItem({
    required this.id,
    required this.role,
    required this.content,
    this.sources,
    this.createdAt,
  });

  factory ChatMessageItem.fromJson(Map<String, dynamic> json) {
    return ChatMessageItem(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      sources: json['sources'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class ChatHistoryService {
  static final ChatHistoryService instance = ChatHistoryService._internal();
  factory ChatHistoryService() => instance;
  ChatHistoryService._internal();

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  List<String> get _baseUrls => [
        AppConstants.researchBaseUrl,
        AppConstants.chatBaseUrl,
      ];

  /// Fetches conversation list filtered by session_type ('ori_chat' or 'paper_orbit')
  Future<List<ChatConversationSummary>> getHistory({
    String? sessionType,
  }) async {
    final uid = currentUserId;
    for (final base in _baseUrls) {
      try {
        final queryParams = <String, String>{};
        if (sessionType != null && sessionType.isNotEmpty) {
          queryParams['session_type'] = sessionType;
        }
        if (uid != null && uid.isNotEmpty) {
          queryParams['user_id'] = uid;
        }

        final uri = Uri.parse('$base/chat/history').replace(
          queryParameters: queryParams.isNotEmpty ? queryParams : null,
        );

        final headers = <String, String>{
          'Content-Type': 'application/json',
          if (uid != null && uid.isNotEmpty) 'x-user-id': uid,
        };

        final response = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final list = (data['conversations'] as List? ?? []);
          return list
              .map((item) => ChatConversationSummary.fromJson(
                  item as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('[ChatHistoryService] Error hitting $base: $e');
      }
    }
    return [];
  }

  /// Fetches a specific conversation and all its messages
  Future<Map<String, dynamic>?> getConversation(String conversationId) async {
    final uid = currentUserId;
    for (final base in _baseUrls) {
      try {
        final queryParams = <String, String>{
          if (uid != null && uid.isNotEmpty) 'user_id': uid,
        };
        final uri = Uri.parse('$base/chat/history/$conversationId').replace(
          queryParameters: queryParams.isNotEmpty ? queryParams : null,
        );

        final headers = <String, String>{
          'Content-Type': 'application/json',
          if (uid != null && uid.isNotEmpty) 'x-user-id': uid,
        };

        final response = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final rawMessages = (data['messages'] as List? ?? []);
          final messages = rawMessages
              .map((m) => ChatMessageItem.fromJson(m as Map<String, dynamic>))
              .toList();

          return {
            'id': data['id'],
            'title': data['title'],
            'session_type': data['session_type'],
            'paper_id': data['paper_id'],
            'created_at': data['created_at'],
            'updated_at': data['updated_at'],
            'messages': messages,
          };
        }
      } catch (e) {
        debugPrint('[ChatHistoryService] getConversation error at $base: $e');
      }
    }
    return null;
  }

  /// Deletes a conversation from the database
  Future<bool> deleteConversation(String conversationId) async {
    final uid = currentUserId;
    for (final base in _baseUrls) {
      try {
        final queryParams = <String, String>{
          if (uid != null && uid.isNotEmpty) 'user_id': uid,
        };
        final uri = Uri.parse('$base/chat/history/$conversationId').replace(
          queryParameters: queryParams.isNotEmpty ? queryParams : null,
        );

        final headers = <String, String>{
          'Content-Type': 'application/json',
          if (uid != null && uid.isNotEmpty) 'x-user-id': uid,
        };

        final response = await http
            .delete(uri, headers: headers)
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return true;
        }
      } catch (e) {
        debugPrint('[ChatHistoryService] delete error at $base: $e');
      }
    }
    return false;
  }
}

