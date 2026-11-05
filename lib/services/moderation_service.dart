import 'package:flutter_chess_app/services/api_client.dart';

/// Why a player can be reported (same values as the backend's REASONS).
const Map<String, String> kReportReasons = {
  'cheating': 'Cheating (outside help / engine)',
  'abusive': 'Abusive behaviour',
  'stalling': 'Stalling (not moving on purpose)',
  'sandbagging': 'Losing on purpose',
  'other': 'Something else',
};

class MyModerationStatus {
  final int warnings;
  final String? banKind; // 'play' | 'full' | null
  final DateTime? banUntil; // null + banKind set = permanent
  final String banReason;
  final String? appealStatus; // 'open' | 'unbanned' | 'rejected' | null
  final String appealNote;

  const MyModerationStatus({
    required this.warnings,
    required this.banKind,
    required this.banUntil,
    required this.banReason,
    required this.appealStatus,
    required this.appealNote,
  });

  bool get banned => banKind != null;

  factory MyModerationStatus.fromJson(Map<String, dynamic> j) {
    final ban = j['ban'] is Map ? Map<String, dynamic>.from(j['ban']) : null;
    final appeal = j['appeal'] is Map ? Map<String, dynamic>.from(j['appeal']) : null;
    return MyModerationStatus(
      warnings: (j['warnings'] as num?)?.toInt() ?? 0,
      banKind: ban?['kind']?.toString(),
      banUntil: ban?['until'] == null ? null : DateTime.tryParse(ban!['until'].toString()),
      banReason: ban?['reason']?.toString() ?? '',
      appealStatus: appeal?['status']?.toString(),
      appealNote: appeal?['adminNote']?.toString() ?? '',
    );
  }
}

/// Player side (report an opponent, see own status, appeal) and admin side (review queue, appeals).
/// Errors are thrown as [ApiException] with a message that is safe to show.
class ModerationService {
  final ApiClient _api = ApiClient.instance;

  // ---------------- player ----------------

  /// Returns true if the report was stored (or had already been sent for this game).
  Future<bool> reportGame(String gameId, String reason, String details) async {
    final r = await _api.post('/games/${Uri.encodeComponent(gameId)}/report', body: {
      'reason': reason,
      'details': details,
    });
    return r['success'] == true;
  }

  Future<MyModerationStatus> myStatus() async {
    final r = await _api.get('/moderation/me');
    return MyModerationStatus.fromJson(r);
  }

  Future<void> appeal(String message) async {
    await _api.post('/moderation/appeals', body: {'message': message});
  }

  // ---------------- admin ----------------

  Future<List<Map<String, dynamic>>> listReports(String status) async {
    final r = await _api.get('/admin/game-reports', query: {'status': status});
    return (r['reports'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> getReport(String id) async {
    return await _api.get('/admin/game-reports/$id');
  }

  /// action: dismiss | warn | ban. For ban: kind = play|full, days = number or null (= permanent).
  Future<void> resolveReport(String id, String action, {String? kind, int? days, String note = ''}) async {
    await _api.put('/admin/game-reports/$id', body: {
      'action': action,
      if (kind != null) 'kind': kind,
      if (action == 'ban') 'days': days ?? 'permanent',
      'note': note,
    });
  }

  Future<List<Map<String, dynamic>>> listAppeals(String status) async {
    final r = await _api.get('/admin/appeals', query: {'status': status});
    return (r['appeals'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// action: reject | unban
  Future<void> decideAppeal(String id, String action, {String note = ''}) async {
    await _api.put('/admin/appeals/$id', body: {'action': action, 'note': note});
  }
}
