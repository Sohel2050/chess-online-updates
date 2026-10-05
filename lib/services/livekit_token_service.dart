import 'package:flutter_chess_app/services/api_client.dart';

class LiveKitCredentials {
  final String token;
  final String url;
  LiveKitCredentials({required this.token, required this.url});
}

/// Fetches a short-lived LiveKit access token from the backend
/// (`POST /livekit/token`) for the given room name. Replaces
/// `ZegoProvider`, which used to hand out a static App ID/App Sign pair —
/// LiveKit instead requires a signed, per-user, per-room token minted
/// server-side, which is more secure (nothing secret ships in the app).
class LiveKitTokenService {
  final ApiClient _api = ApiClient.instance;

  Future<LiveKitCredentials> getToken(String roomName) async {
    final result = await _api.post('/livekit/token', body: {'roomName': roomName});
    return LiveKitCredentials(
      token: result['token'] as String,
      url: result['url'] as String,
    );
  }
}
