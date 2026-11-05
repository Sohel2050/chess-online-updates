import 'package:flutter_chess_app/services/api_client.dart';

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
int _int(dynamic v, [int d = 0]) => (v as num?)?.toInt() ?? d;

/// One line of a club list (backend/controllers/clubController.js, `summary`).
class ClubSummary {
  final String id;
  final String name;
  final String description;
  final int memberCount;
  final int maxMembers;
  final String? myRole; // owner | admin | member | null
  final String ownerName;
  final int unreadChat; // chat messages from others since I last read the chat (server caps it at 100)
  final DateTime? myMutedUntil; // set while an admin has muted me in the chat

  ClubSummary({required this.id, required this.name, required this.description, required this.memberCount, required this.maxMembers, required this.myRole, required this.ownerName, this.unreadChat = 0, this.myMutedUntil});

  factory ClubSummary.fromJson(Map<String, dynamic> j) => ClubSummary(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
        memberCount: _int(j['memberCount']),
        maxMembers: _int(j['maxMembers'], 100),
        myRole: j['myRole']?.toString(),
        ownerName: j['ownerName']?.toString() ?? '',
        unreadChat: _int(j['unreadChat']),
        myMutedUntil: _date(j['myMutedUntil']),
      );

  bool get isMember => myRole != null;
  bool get isManager => myRole == 'owner' || myRole == 'admin';
  bool get isOwner => myRole == 'owner';
}

class ClubMember {
  final String userId;
  final String name;
  final String role;
  final int rating;
  final DateTime? mutedUntil; // chat mute still running, else null
  ClubMember({required this.userId, required this.name, required this.role, required this.rating, this.mutedUntil});

  factory ClubMember.fromJson(Map<String, dynamic> j) => ClubMember(
        userId: j['userId']?.toString() ?? '',
        name: j['name']?.toString() ?? 'Player',
        role: j['role']?.toString() ?? 'member',
        rating: _int(j['rating'], 1200),
        mutedUntil: _date(j['mutedUntil']),
      );
}

class ClubDetail {
  final ClubSummary info;
  final List<ClubMember> members;
  ClubDetail({required this.info, required this.members});

  factory ClubDetail.fromJson(Map<String, dynamic> j) => ClubDetail(
        info: ClubSummary.fromJson(j),
        members: ((j['members'] as List?) ?? []).map((e) => ClubMember.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

class ClubList {
  final List<ClubSummary> mine;
  final List<ClubSummary> discover;
  ClubList({required this.mine, required this.discover});
}

class ClubBoardRow {
  final int rank;
  final String userId;
  final String name;
  final String role;
  final int points;
  final int rating;
  ClubBoardRow({required this.rank, required this.userId, required this.name, required this.role, required this.points, required this.rating});
}

class ClubBoard {
  final String by;
  final DateTime? resetsAt;
  final int totalPoints;
  final List<ClubBoardRow> rows;
  ClubBoard({required this.by, required this.resetsAt, required this.totalPoints, required this.rows});
}

class ClubPost {
  final String id;
  final String authorId;
  final String authorName;
  final String text;
  final bool pinned;
  final DateTime? createdAt;
  ClubPost({required this.id, required this.authorId, required this.authorName, required this.text, required this.pinned, required this.createdAt});
}

class ClubPosts {
  final bool canPost;
  final List<ClubPost> posts;
  ClubPosts({required this.canPost, required this.posts});
}

/// One chat message of a club (backend `messageJson`).
class ClubChatMessage {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorRole; // owner | admin | member | null (left the club)
  final String text;
  final DateTime? createdAt;
  ClubChatMessage({required this.id, required this.authorId, required this.authorName, required this.authorRole, required this.text, required this.createdAt});

  factory ClubChatMessage.fromJson(Map<String, dynamic> m) => ClubChatMessage(
        id: m['id']?.toString() ?? '',
        authorId: m['authorId']?.toString() ?? '',
        authorName: m['authorName']?.toString() ?? '',
        authorRole: m['authorRole']?.toString(),
        text: m['text']?.toString() ?? '',
        createdAt: _date(m['createdAt']),
      );
}

class ClubChatPage {
  final List<ClubChatMessage> messages; // oldest first
  final bool hasMore;
  ClubChatPage({required this.messages, required this.hasMore});
}

class ClubService {
  final ApiClient _api = ApiClient.instance;

  List<ClubSummary> _summaries(dynamic v) =>
      ((v as List?) ?? []).map((e) => ClubSummary.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  ClubDetail _one(Map<String, dynamic> r) => ClubDetail.fromJson(Map<String, dynamic>.from(r['club'] as Map));

  Future<ClubList> list({String query = ''}) async {
    final r = await _api.get('/clubs', query: query.isEmpty ? null : {'q': query});
    return ClubList(mine: _summaries(r['mine']), discover: _summaries(r['discover']));
  }

  Future<ClubDetail> get(String id) async => _one(await _api.get('/clubs/$id'));

  Future<ClubDetail> create({required String name, String description = ''}) async =>
      _one(await _api.post('/clubs', body: {'name': name, 'description': description}));

  Future<ClubDetail> updateDescription(String id, String description) async =>
      _one(await _api.put('/clubs/$id', body: {'description': description}));

  Future<ClubDetail> join(String id) async => _one(await _api.post('/clubs/$id/join'));
  Future<void> leave(String id) async => _api.post('/clubs/$id/leave');
  Future<void> deleteClub(String id) async => _api.delete('/clubs/$id');

  Future<ClubDetail> removeMember(String id, String userId, {bool ban = false}) async =>
      _one(await _api.post('/clubs/$id/members/$userId/remove', body: {'ban': ban}));

  Future<ClubDetail> setRole(String id, String userId, String role) async =>
      _one(await _api.post('/clubs/$id/members/$userId/role', body: {'role': role}));

  /// Chat mute for [minutes] (0 = lift it, at most one week). Owner / admins, same hierarchy as removing a member.
  Future<ClubDetail> muteMember(String id, String userId, int minutes) async =>
      _one(await _api.post('/clubs/$id/members/$userId/mute', body: {'minutes': minutes}));

  /// "I have read the chat" (clears the unread badge). Never throws: a missed call only keeps the badge a bit longer.
  Future<void> markChatRead(String id) async {
    try {
      await _api.post('/clubs/$id/messages/read');
    } catch (_) {}
  }

  Future<ClubDetail> transfer(String id, String userId) async =>
      _one(await _api.post('/clubs/$id/transfer', body: {'userId': userId}));

  Future<ClubBoard> leaderboard(String id, {String by = 'weekly'}) async {
    final r = await _api.get('/clubs/$id/leaderboard', query: {'by': by});
    final rows = ((r['rows'] as List?) ?? []).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return ClubBoardRow(
        rank: _int(m['rank']),
        userId: m['userId']?.toString() ?? '',
        name: m['name']?.toString() ?? 'Player',
        role: m['role']?.toString() ?? 'member',
        points: _int(m['points']),
        rating: _int(m['rating'], 1200),
      );
    }).toList();
    return ClubBoard(by: r['by']?.toString() ?? by, resetsAt: _date(r['resetsAt']), totalPoints: _int(r['totalPoints']), rows: rows);
  }

  Future<ClubPosts> posts(String id) async {
    final r = await _api.get('/clubs/$id/posts');
    final posts = ((r['posts'] as List?) ?? []).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return ClubPost(
        id: m['id']?.toString() ?? '',
        authorId: m['authorId']?.toString() ?? '',
        authorName: m['authorName']?.toString() ?? '',
        text: m['text']?.toString() ?? '',
        pinned: m['pinned'] == true,
        createdAt: _date(m['createdAt']),
      );
    }).toList();
    return ClubPosts(canPost: r['canPost'] == true, posts: posts);
  }

  /// Returns true when the members were also notified (at most once an hour per club).
  Future<bool> post(String id, String text, {bool notify = false, bool pinned = false}) async {
    final r = await _api.post('/clubs/$id/posts', body: {'text': text, 'notify': notify, 'pinned': pinned});
    return r['notified'] == true;
  }

  Future<void> deletePost(String id, String postId) async => _api.delete('/clubs/$id/posts/$postId');
  Future<void> pinPost(String id, String postId, bool pinned) async => _api.post('/clubs/$id/posts/$postId/pin', body: {'pinned': pinned});

  /// kind: tournament | club | club_post | club_message. reason: inappropriate_name | offensive_text | spam | cheating | other.
  Future<void> report({required String kind, required String targetId, required String reason, String details = ''}) async =>
      _api.post('/clubs/report', body: {'kind': kind, 'targetId': targetId, 'reason': reason, 'details': details});

  // ---- admin
  Future<List<Map<String, dynamic>>> adminReports({bool reviewed = false}) async {
    final r = await _api.get('/admin/content-reports', query: {'status': reviewed ? 'reviewed' : 'open'});
    return ((r['reports'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> adminResolve(String reportId, String action) async => _api.put('/admin/content-reports/$reportId', body: {'action': action});

  Future<List<Map<String, dynamic>>> adminTournaments(String status) async {
    final r = await _api.get('/admin/tournaments', query: {'status': status});
    return ((r['tournaments'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> adminCancelTournament(String id) async => _api.post('/tournaments/$id/cancel');

  Future<List<Map<String, dynamic>>> adminClubs({String q = ''}) async {
    final r = await _api.get('/admin/clubs', query: q.isEmpty ? null : {'q': q});
    return ((r['clubs'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> adminDeleteClub(String id) async => _api.delete('/admin/clubs/$id');

  // ---- chat (members only; live updates come through GameSocketService.onClubEvent)

  /// Newest [limit] messages, or the ones before message [before].
  Future<ClubChatPage> messages(String id, {String? before, int limit = 30}) async {
    final r = await _api.get('/clubs/$id/messages', query: {'limit': limit, if (before != null) 'before': before});
    final list = ((r['messages'] as List?) ?? []).map((e) => ClubChatMessage.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    return ClubChatPage(messages: list, hasMore: r['hasMore'] == true);
  }

  Future<ClubChatMessage> sendMessage(String id, String text) async {
    final r = await _api.post('/clubs/$id/messages', body: {'text': text});
    return ClubChatMessage.fromJson(Map<String, dynamic>.from(r['message'] as Map));
  }

  Future<void> deleteMessage(String id, String messageId) async => _api.delete('/clubs/$id/messages/$messageId');
}
