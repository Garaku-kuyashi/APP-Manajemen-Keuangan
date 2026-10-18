import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

DateTime _toDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.fromMillisecondsSinceEpoch(0);
}

class ChatTopic {
  const ChatTopic({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime updatedAt;

  factory ChatTopic.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return ChatTopic(
      id: document.id,
      title: data['title'] as String? ?? 'Percakapan baru',
      updatedAt: _toDate(data['updatedAt']),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.createdAt,
  });

  final String id;
  final String text;
  final bool isUser;
  final DateTime createdAt;

  factory ChatMessage.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return ChatMessage(
      id: document.id,
      text: data['text'] as String? ?? '',
      isUser: data['role'] == 'user',
      createdAt: _toDate(data['createdAt']),
    );
  }
}

class ChatRepository {
  ChatRepository({required this._firestore, required this._auth});

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _topics {
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) {
      throw StateError(
        'A verified Firebase user is required to access chat history.',
      );
    }
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('chatTopics');
  }

  Stream<List<ChatTopic>> watchTopics() => _topics
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(ChatTopic.fromDocument).toList());

  Stream<List<ChatMessage>> watchMessages(String topicId) => _messages(topicId)
      .orderBy('createdAt')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(ChatMessage.fromDocument).toList());

  Future<List<ChatMessage>> getRecentMessages(
    String topicId, {
    int limit = 20,
  }) async {
    final snapshot = await _messages(topicId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map(ChatMessage.fromDocument)
        .toList()
        .reversed
        .toList();
  }

  Future<String> createTopic(
    String firstMessage, {
    required String welcomeMessage,
  }) async {
    final topic = _topics.doc();
    final now = Timestamp.now();
    final batch = _firestore.batch();
    batch.set(topic, {
      'title': _titleFrom(firstMessage),
      'createdAt': now,
      'updatedAt': now,
    });
    batch.set(topic.collection('messages').doc(), {
      'text': welcomeMessage,
      'role': 'assistant',
      'createdAt': now,
    });
    await batch.commit();
    return topic.id;
  }

  Future<void> addMessage({
    required String topicId,
    required String text,
    required bool isUser,
  }) async {
    final topic = _topics.doc(topicId);
    final batch = _firestore.batch();
    batch.set(_messages(topicId).doc(), {
      'text': text,
      'role': isUser ? 'user' : 'assistant',
      'createdAt': Timestamp.now(),
    });
    batch.update(topic, {'updatedAt': Timestamp.now()});
    await batch.commit();
  }

  Future<void> deleteTopic(String topicId) async {
    final topic = _topics.doc(topicId);
    final messageCollection = topic.collection('messages');
    final messages = await messageCollection.get();
    for (var start = 0; start < messages.docs.length; start += 400) {
      final batch = _firestore.batch();
      for (final message in messages.docs.skip(start).take(400)) {
        batch.delete(message.reference);
      }
      await batch.commit();
    }
    await topic.delete();
  }

  CollectionReference<Map<String, dynamic>> _messages(String topicId) =>
      _topics.doc(topicId).collection('messages');

  static String _titleFrom(String text) {
    final title = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty) return 'Percakapan baru';
    return title.length <= 48 ? title : '${title.substring(0, 45)}...';
  }
}
