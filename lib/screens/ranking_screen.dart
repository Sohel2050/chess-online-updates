import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'package:flutter_chess_app/services/admin_service.dart';
import 'package:flutter_chess_app/services/ranking_service.dart';
import 'package:logger/logger.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  String _selectedRatingType = Constants.tempoRating; // Default to fast rating
  List<Map<String, String>> _enabledRatingTypes =
      []; // Track enabled rating types
  bool _isLoadingRatings = true;
  final AdminService _adminService = AdminService();
  final RankingService _rankingService = RankingService();
  final Logger _logger = Logger();

  // Pagination settings — page-number based now (backend handles skip/limit),
  // replacing the old Firestore DocumentSnapshot cursor.
  static const int _pageSize = 50; // Load 50 users per page
  int _currentPage = 1;
  bool _hasMorePages = true;
  List<ChessUser> _users = [];
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  int? _totalPlayerCount;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadEnabledGameModes();
    _loadTotalPlayerCount();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadMoreUsers();
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoadingMore || !_hasMorePages) return;

    setState(() => _isLoadingMore = true);

    try {
      final newUsers = await _rankingService.getLeaderboardPage(
        ratingType: _selectedRatingType,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (newUsers.isEmpty) {
        setState(() => _hasMorePages = false);
        return;
      }

      setState(() {
        _users.addAll(newUsers);
        _currentPage++;
        _hasMorePages = newUsers.length == _pageSize;
      });
    } catch (e) {
      _logger.e('Error loading more users: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadEnabledGameModes() async {
    try {
      final enabledModes = await _adminService.getEnabledGameModes();

      final ratingTypesList = <Map<String, String>>[];
      for (var mode in enabledModes) {
        final title = mode[Constants.title] as String? ?? '';
        final timeControl = mode[Constants.timeControl] as String? ?? '';

        // Map mode to rating type
        final ratingType = Constants.gameModeToRatingType[timeControl];
        if (ratingType != null) {
          ratingTypesList.add({'ratingType': ratingType, 'label': title});
        }
      }

      if (mounted) {
        setState(() {
          _enabledRatingTypes = ratingTypesList;
          // Set default to first enabled rating type if available
          if (_enabledRatingTypes.isNotEmpty) {
            _selectedRatingType = _enabledRatingTypes[0]['ratingType']!;
          }
          _isLoadingRatings = false;
        });
        // Load first page of users
        _resetAndLoadUsers();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRatings = false;
        });
      }
    }
  }

  Future<void> _resetAndLoadUsers() async {
    setState(() {
      _users = [];
      _currentPage = 1;
      _hasMorePages = true;
    });
    await _loadMoreUsers();
  }

  Future<void> _loadTotalPlayerCount() async {
    try {
      final count = await _rankingService.getTotalPlayerCount();
      if (mounted && count != null) {
        setState(() {
          _totalPlayerCount = count;
        });
      }
    } catch (e) {
      _logger.e('Error loading player count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Rankings'),
        bottom: _isLoadingRatings
            ? const PreferredSize(
                preferredSize: Size.fromHeight(50.0),
                child: Center(child: CircularProgressIndicator()),
              )
            : _enabledRatingTypes.isEmpty
            ? const PreferredSize(
                preferredSize: Size.fromHeight(50.0),
                child: Center(child: Text('No game modes available')),
              )
            : PreferredSize(
                preferredSize: const Size.fromHeight(50.0),
                child: _buildRatingTypeSelector(),
              ),
        actions: [
          if (_totalPlayerCount != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  'Players: ${Constants.formatCount(_totalPlayerCount!)}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
      body: _isLoadingRatings
          ? const Center(child: CircularProgressIndicator())
          : _enabledRatingTypes.isEmpty
          ? const Center(child: Text('No game modes available for rankings'))
          : _buildUsersList(),
    );
  }

  Widget _buildUsersList() {
    if (_users.isEmpty && !_isLoadingMore) {
      return const Center(child: Text('No players found.'));
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _users.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the end
        if (index == _users.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final user = _users[index];
        final rating = user.toMap()[_selectedRatingType] ?? 1200;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Text(
              '#${index + 1}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            title: Text(
              user.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              'Rating: $rating',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            trailing: ProfileImageWidget(
              imageUrl: user.photoUrl,
              radius: 20,
              isEditable: false,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRatingTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _enabledRatingTypes.map((ratingType) {
          return _buildRatingButton(
            ratingType['ratingType']!,
            ratingType['label']!,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRatingButton(String ratingType, String label) {
    final bool isSelected = _selectedRatingType == ratingType;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedRatingType = ratingType;
          });
          // Reset and load users for the new rating type
          _resetAndLoadUsers();
        }
      },
      selectedColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
