import 'package:flutter/material.dart';
import '../models/poll_model.dart';
import '../services/poll_service.dart';

class PollProvider with ChangeNotifier {
  final PollService _pollService = PollService();

  Poll? _activePoll;
  UserVote? _userVote;
  Map<String, int> _pollResults = {};
  bool _isLoading = false;
  String? _error;

  Poll? get activePoll => _activePoll;
  UserVote? get userVote => _userVote;
  Map<String, int> get pollResults => _pollResults;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasVoted => _userVote != null;

  // Load active poll and user's vote status
  Future<void> loadPoll(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _activePoll = await _pollService.getActivePoll();

      if (_activePoll != null) {
        _userVote = await _pollService.getUserVote(userId, _activePoll!.id);
        _pollResults = await _pollService.getPollResults(_activePoll!.id);
      }
    } catch (e) {
      _error = 'Failed to load poll: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cast a vote
  Future<bool> castVote(String userId, String optionId) async {
    if (_activePoll == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _pollService.castVote(
        userId,
        _activePoll!.id,
        optionId,
      );

      if (success) {
        _userVote = UserVote(
          userId: userId,
          pollId: _activePoll!.id,
          optionId: optionId,
          votedAt: DateTime.now(),
        );
        _pollResults = await _pollService.getPollResults(_activePoll!.id);
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Failed to cast vote: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Get vote percentage for an option
  double getVotePercentage(String optionId) {
    final totalVotes = _pollResults.values.fold(0, (sum, votes) => sum + votes);
    if (totalVotes == 0) return 0.0;

    final optionVotes = _pollResults[optionId] ?? 0;
    return (optionVotes / totalVotes) * 100;
  }

  // Get total votes
  int getTotalVotes() {
    return _pollResults.values.fold(0, (sum, votes) => sum + votes);
  }
}
