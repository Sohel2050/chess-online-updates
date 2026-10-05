import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/levelplay_service.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/screens/levelplay_admin_screen.dart';
import 'package:flutter_chess_app/services/admin_service.dart';
import 'package:flutter_chess_app/services/version_service.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';
import 'package:flutter_chess_app/widgets/main_app_button.dart';
import 'package:logger/logger.dart';

class AdminScreen extends StatefulWidget {
  final ChessUser user;

  const AdminScreen({super.key, required this.user});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final AdminService _adminService = AdminService();
  bool _isLoading = false;
  Map<String, dynamic>? _userStats;
  bool _bannerAdsEnabled = true;
  bool _interstitialAdsEnabled = true;
  bool _appOpenAdsEnabled = true;
  bool _nativeAdsEnabled = true;
  bool _adsStatusLoaded = false;
  Map<String, bool> _playFeatures = const {
    'onlineEnabled': true,
    'cpuEnabled': true,
    'localMultiplayerEnabled': true,
  };
  bool _playFeaturesLoaded = false;
  bool _voiceChatAdGateEnabled = true;
  bool _voiceChatAdGateLoaded = false;
  Logger logger = Logger();

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadAdsSettings();
    _loadPlayFeatures();
    _loadVoiceChatAdGate();
    // Load user stats after a small delay to prioritize ads settings
    // Uses efficient aggregation queries so no OOM risk
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _loadUserStatistics();
    });
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _adminService.isAdmin(widget.user.email!);
    if (!isAdmin) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied: Admin privileges required'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadUserStatistics() async {
    if (_isLoading) return; // Prevent multiple concurrent loads
    setState(() {
      _isLoading = true;
    });
    try {
      final result = await _adminService.getUserStatistics(widget.user.email!);
      if (result['success'] == true && mounted) {
        setState(() {
          _userStats = result['stats'];
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading statistics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getDatabaseStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _adminService.getDatabaseStats(widget.user.email!);
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        // Show results in animated dialog
        await AnimatedDialog.show(
          maxWidth: 400,
          context: context,
          title: result['success'] ? 'Database Statistics' : 'Error',
          child: result['success']
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Collection Counts:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow('Waiting games', result['stats']['waiting']),
                    _buildStatRow('Active games', result['stats']['active']),
                    _buildStatRow(
                      'Archived games',
                      result['stats']['archived'],
                    ),
                    const Divider(height: 24),
                    _buildStatRow(
                      'Total games',
                      result['stats']['total'],
                      isBold: true,
                    ),
                  ],
                )
              : Text(
                  'Failed to get stats: ${result['message']}',
                  style: const TextStyle(color: Colors.red),
                ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        await AnimatedDialog.show(
          maxWidth: 400,
          context: context,
          title: 'Error',
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      }
    }
  }

  Future<void> _cleanupArchivedGames() async {
    // Show confirmation dialog
    final confirmed = await AnimatedDialog.show(
      maxWidth: 400,
      context: context,
      title: 'Confirm Cleanup',
      child: const Text(
        'This will delete archived games older than 30 days. '
        'This action cannot be undone. Continue?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm'),
        ),
      ],
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _adminService.cleanupArchivedGames(
        widget.user.email!,
      );
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        // Show results in animated dialog
        await AnimatedDialog.show(
          maxWidth: 400,
          context: context,
          title: result['success'] ? 'Cleanup Complete' : 'Error',
          child: Text(
            result['success']
                ? 'Archived games cleanup completed successfully!'
                : 'Cleanup failed: ${result['message']}',
            style: TextStyle(
              color: result['success'] ? Colors.green : Colors.red,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        await AnimatedDialog.show(
          maxWidth: 400,
          context: context,
          title: 'Error',
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      }
    }
  }

  Future<void> _cleanUpGameRooms() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _adminService.cleanupWaitingGames(
        widget.user.email!,
      );
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        // Show results in animated dialog
        await AnimatedDialog.show(
          maxWidth: 400,
          context: context,
          title: result['success'] ? 'Cleanup Complete' : 'Error',
          child: Text(
            result['success']
                ? 'Waiting games cleanup completed successfully!'
                : 'Cleanup failed: ${result['message']}',
            style: TextStyle(
              color: result['success'] ? Colors.green : Colors.red,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        await AnimatedDialog.show(
          maxWidth: 400,
          context: context,
          title: 'Error',
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      }
    }
  }

  void _openAdInspector() => _tryOpenAdInspector();

  void _tryOpenAdInspector() {
    if (!LevelPlayService.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'LevelPlay is not initialised yet. Check the App Key in '
            'LevelPlay Ads settings and enable the test suite.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    LevelPlayService.launchTestSuite();
  }

  Future<void> _manageGameModes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch current game mode settings and active search counts
      final result = await _adminService.getGameModeSettings(
        widget.user.email!,
      );
      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      if (result['success'] == true) {
        final currentModes = Map<String, bool>.from(
          result['modes'] as Map<String, dynamic>,
        );
        final activeSearches = Map<String, int>.from(
          result['activeSearches'] as Map<String, dynamic>,
        );

        // Create mutable copy for dialog
        final updatedModes = Map<String, bool>.from(currentModes);

        final confirmed = await AnimatedDialog.show(
          maxWidth: 500,
          context: context,
          title: 'Manage Game Modes',
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Toggle game modes visibility:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...updatedModes.entries.map((entry) {
                    final modeName = entry.key;
                    final isEnabled = entry.value;
                    final activeCount = activeSearches[modeName] ?? 0;
                    final hasActiveSearches = activeCount > 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      modeName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (hasActiveSearches)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '⚠ $activeCount active search(es)',
                                          style: const TextStyle(
                                            color: Colors.orange,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: isEnabled,
                                onChanged: (newValue) {
                                  setState(() {
                                    updatedModes[modeName] = newValue;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    '⚠ Warning: Disabling a mode with active searches will affect those users.',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Apply Changes'),
            ),
          ],
        );

        if (confirmed == true && mounted) {
          // Check if there are changes
          bool hasChanges = false;
          for (final mode in updatedModes.keys) {
            if (currentModes[mode] != updatedModes[mode]) {
              hasChanges = true;
              break;
            }
          }

          if (!hasChanges) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('No changes made')));
            return;
          }

          // Show final confirmation with warnings
          final modesBeingDisabled = updatedModes.entries
              .where((e) => currentModes[e.key] == true && e.value == false)
              .map((e) => e.key)
              .toList();

          final hasActiveOnDisabled = modesBeingDisabled.any(
            (mode) => (activeSearches[mode] ?? 0) > 0,
          );

          final finalConfirmed = await AnimatedDialog.show(
            maxWidth: 500,
            context: context,
            title: 'Confirm Changes',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You are about to make the following changes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...updatedModes.entries
                    .where((e) => currentModes[e.key] != e.value)
                    .map((e) {
                      final isDisabling = currentModes[e.key] == true;
                      final activeCount = activeSearches[e.key] ?? 0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              isDisabling
                                  ? Icons.remove_circle
                                  : Icons.add_circle,
                              color: isDisabling ? Colors.red : Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${isDisabling ? 'Disable' : 'Enable'}: ${e.key}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (activeCount > 0)
                                    Text(
                                      '($activeCount active searches)',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(),
                if (hasActiveOnDisabled) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Some modes being disabled have active searches. Users will be notified.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm Changes'),
              ),
            ],
          );

          if (finalConfirmed == true && mounted) {
            setState(() {
              _isLoading = true;
            });

            try {
              final updateResult = await _adminService.updateGameModeSettings(
                widget.user.email!,
                updatedModes,
              );

              setState(() {
                _isLoading = false;
              });

              if (mounted) {
                await AnimatedDialog.show(
                  maxWidth: 400,
                  context: context,
                  title: updateResult['success'] ? 'Success' : 'Error',
                  child: updateResult['success']
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Game mode settings updated successfully!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      : Text(
                          'Update failed: ${updateResult['message']}',
                          style: const TextStyle(color: Colors.red),
                        ),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                );
              }
            } catch (e) {
              setState(() {
                _isLoading = false;
              });
              if (mounted) {
                await AnimatedDialog.show(
                  maxWidth: 400,
                  context: context,
                  title: 'Error',
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(color: Colors.red),
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                );
              }
            }
          }
        }
      } else {
        await AnimatedDialog.show(
          maxWidth: 400,
          context: context,
          title: 'Error',
          child: Text(
            'Failed to load game modes: ${result['message']}',
            style: const TextStyle(color: Colors.red),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        await AnimatedDialog.show(
          maxWidth: 400,
          context: context,
          title: 'Error',
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      }
    }
  }

  Future<void> _verifyActiveGames() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _adminService.verifyActiveGames(widget.user.email!);
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        await AnimatedDialog.show(
          maxWidth: 600,
          context: context,
          title: 'Active Games Verification',
          child: result['success']
              ? SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Active: ${result['totalActiveGames']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '⚠ ${result['staleGames'].length} Stale',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if ((result['staleGames'] as List).isNotEmpty) ...[
                        const Text(
                          'Stale Games (1+ hour, no moves):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final game
                                  in (result['staleGames'] as List).take(5))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.warning,
                                        size: 16,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${game['player1DisplayName']} vs ${game['player2DisplayName']} (${game['moveCount']} moves)',
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if ((result['staleGames'] as List).length > 5)
                                Text(
                                  '+${(result['staleGames'] as List).length - 5} more',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if ((result['noMovesGames'] as List).isNotEmpty) ...[
                        const Text(
                          'Games with No Moves:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(result['noMovesGames'] as List).length} games created but never started',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Stale threshold: ${result['staleThresholdHours']} hour(s) (no activity)',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Text(
                  'Failed to verify: ${result['message']}',
                  style: const TextStyle(color: Colors.red),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            if (result['success'] && (result['staleGames'] as List).isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _cleanupStaleActiveGames();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cleanup Stale'),
              ),
          ],
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        await AnimatedDialog.show(
          maxWidth: 400,
          context: context,
          title: 'Error',
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      }
    }
  }

  Future<void> _cleanupStaleActiveGames() async {
    final confirmed = await AnimatedDialog.show(
      maxWidth: 400,
      context: context,
      title: 'Confirm Cleanup',
      child: const Text(
        'This will archive all active games with no activity for 1+ hour. '
        'These games will be marked as "abandoned". Continue?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm Cleanup'),
        ),
      ],
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _adminService.cleanupStaleActiveGames(
        widget.user.email!,
      );
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        await AnimatedDialog.show(
          maxWidth: 400,
          context: context,
          title: result['success'] ? 'Cleanup Complete' : 'Error',
          child: result['success']
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Successfully archived ${result['archivedCount']} stale games!',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Active game count is now accurate.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                )
              : Text(
                  'Cleanup failed: ${result['message']}',
                  style: const TextStyle(color: Colors.red),
                ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        await AnimatedDialog.show(
          maxWidth: 400,
          context: context,
          title: 'Error',
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      }
    }
  }

  Future<void> _deleteInactiveGuestUsers() async {
    // Show confirmation dialog
    final confirmed = await AnimatedDialog.show(
      maxWidth: 400,
      context: context,
      title: 'Confirm Deletion',
      child: const Text(
        'This will permanently delete all guest users who have not been '
        'active for 15 days. This action cannot be undone. Continue?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // This only triggers the server-side job and returns right away — it
      // does not wait for millions of users to be scanned/deleted. Progress
      // is then shown live via watchGuestCleanupStatus() in the dialog below.
      final result = await _adminService.deleteInactiveGuestUsers(
        widget.user.email!,
        inactiveDays: 15,
      );

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      if (result['success'] != true) {
        await AnimatedDialog.show(
          maxWidth: 400,
          context: context,
          title: 'Error',
          child: Text(
            'Could not start cleanup: ${result['message']}',
            style: const TextStyle(color: Colors.red),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
        return;
      }

      if (result['started'] == false) {
        // A job was already running server-side; just show its live progress.
        await AnimatedDialog.show(
          maxWidth: 400,
          context: context,
          title: 'Already Running',
          child: Text(result['message'] ?? 'A cleanup job is already running.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      }

      // Show a live-updating progress dialog fed by Firestore, since the
      // job itself runs in the background on the server and can take a
      // while for very large numbers of users.
      await _showGuestCleanupProgressDialog();

      // Refresh user statistics once the dialog is dismissed.
      await _loadUserStatistics();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        await AnimatedDialog.show(
          maxWidth: 400,
          context: context,
          title: 'Error',
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      }
    }
  }

  /// Shows a dialog that live-updates from Firestore (adminStatus/guestCleanup)
  /// while the server-side cleanup job runs. Safe to leave open for a long
  /// time since it's just listening to a stream, not blocking on a request —
  /// the admin can also close it early and the job keeps running server-side.
  Future<void> _showGuestCleanupProgressDialog() async {
    if (!mounted) return;
    await AnimatedDialog.show(
      maxWidth: 400,
      context: context,
      title: 'Guest Cleanup Progress',
      child: StreamBuilder<Map<String, dynamic>?>(
        stream: _adminService.watchGuestCleanupStatus(),
        builder: (context, snapshot) {
          final status = snapshot.data;
          if (!snapshot.hasData || status == null) {
            return const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final state = status['status'] ?? 'running';
          final scanned = status['totalScanned'] ?? 0;
          final deleted = status['totalDeleted'] ?? 0;

          IconData icon;
          Color color;
          String label;
          switch (state) {
            case 'completed':
              icon = Icons.check_circle;
              color = Colors.green;
              label = 'Completed';
              break;
            case 'error':
              icon = Icons.error;
              color = Colors.red;
              label = 'Error: ${status['error'] ?? 'unknown'}';
              break;
            default:
              icon = Icons.hourglass_top;
              color = Colors.orange;
              label = 'Running… this can take a while for large user bases.';
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (state == 'running') ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 16),
              Text('Users scanned so far: $scanned'),
              const SizedBox(height: 4),
              Text('Inactive guests deleted so far: $deleted'),
            ],
          );
        },
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close (job keeps running)'),
        ),
      ],
    );
  }

  Future<void> _loadAdsSettings() async {
    try {
      final result = await _adminService.getAdsSettings(widget.user.email!);
      if (result['success'] == true && mounted) {
        setState(() {
          _bannerAdsEnabled = result['bannerAdsEnabled'] ?? true;
          _interstitialAdsEnabled = result['interstitialAdsEnabled'] ?? true;
          _appOpenAdsEnabled = result['appOpenAdsEnabled'] ?? true;
          _nativeAdsEnabled = result['nativeAdsEnabled'] ?? true;
          _adsStatusLoaded = true;
        });
      }
    } catch (e) {
      // Silently fail - ads status will show as unavailable
      if (mounted) {
        setState(() {
          _adsStatusLoaded = true;
        });
      }
    }
  }

  Future<void> _loadPlayFeatures() async {
    try {
      final features = await _adminService.getPlayFeatures();
      if (mounted) {
        setState(() {
          _playFeatures = features;
          _playFeaturesLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _playFeaturesLoaded = true);
    }
  }

  Future<void> _togglePlayFeature(String key, bool value) async {
    setState(() => _playFeatures = {..._playFeatures, key: value});
    try {
      await _adminService.updatePlayFeatures({key: value});
    } catch (e) {
      // Revert on failure and let the admin know.
      setState(() => _playFeatures = {..._playFeatures, key: !value});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _loadVoiceChatAdGate() async {
    try {
      final enabled = await _adminService.getVoiceChatAdGateEnabled();
      if (mounted) {
        setState(() {
          _voiceChatAdGateEnabled = enabled;
          _voiceChatAdGateLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _voiceChatAdGateLoaded = true);
    }
  }

  Future<void> _toggleVoiceChatAdGate(bool value) async {
    setState(() => _voiceChatAdGateEnabled = value);
    try {
      await _adminService.updateVoiceChatAdGateEnabled(value);
    } catch (e) {
      setState(() => _voiceChatAdGateEnabled = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _toggleAdsForApp() async {
    // Show dialog to select which ad type to toggle
    final selectedAdType = await AnimatedDialog.show<String>(
      maxWidth: 400,
      context: context,
      title: 'Manage Ads',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Select ad type to manage:'),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Banner Ads'),
                  subtitle: Text(
                    _bannerAdsEnabled
                        ? 'Currently enabled'
                        : 'Currently disabled',
                  ),
                  trailing: Icon(
                    _bannerAdsEnabled ? Icons.toggle_on : Icons.toggle_off,
                    color: _bannerAdsEnabled ? Colors.green : Colors.grey,
                  ),
                  onTap: () => Navigator.of(context).pop('banner'),
                ),
                Divider(height: 0, color: Colors.grey.shade300),
                ListTile(
                  title: const Text('Interstitial Ads'),
                  subtitle: Text(
                    _interstitialAdsEnabled
                        ? 'Currently enabled'
                        : 'Currently disabled',
                  ),
                  trailing: Icon(
                    _interstitialAdsEnabled
                        ? Icons.toggle_on
                        : Icons.toggle_off,
                    color: _interstitialAdsEnabled ? Colors.green : Colors.grey,
                  ),
                  onTap: () => Navigator.of(context).pop('interstitial'),
                ),
                Divider(height: 0, color: Colors.grey.shade300),
                ListTile(
                  title: const Text('Native Ads'),
                  subtitle: Text(
                    _nativeAdsEnabled
                        ? 'Currently enabled'
                        : 'Currently disabled',
                  ),
                  trailing: Icon(
                    _nativeAdsEnabled ? Icons.toggle_on : Icons.toggle_off,
                    color: _nativeAdsEnabled ? Colors.green : Colors.grey,
                  ),
                  onTap: () => Navigator.of(context).pop('native'),
                ),
                Divider(height: 0, color: Colors.grey.shade300),
                ListTile(
                  title: const Text('App Open Ads'),
                  subtitle: Text(
                    _appOpenAdsEnabled
                        ? 'Currently enabled'
                        : 'Currently disabled',
                  ),
                  trailing: Icon(
                    _appOpenAdsEnabled ? Icons.toggle_on : Icons.toggle_off,
                    color: _appOpenAdsEnabled ? Colors.green : Colors.grey,
                  ),
                  onTap: () => Navigator.of(context).pop('appOpen'),
                ),
                Divider(height: 0, color: Colors.grey.shade300),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );

    if (selectedAdType == null) return;

    // Determine current state and new state
    bool currentState = false;
    String displayName = '';

    switch (selectedAdType) {
      case 'banner':
        currentState = _bannerAdsEnabled;
        displayName = 'Banner Ads';
        break;
      case 'interstitial':
        currentState = _interstitialAdsEnabled;
        displayName = 'Interstitial Ads';
        break;
      case 'native':
        currentState = _nativeAdsEnabled;
        displayName = 'Native Ads';
        break;
      case 'appOpen':
        currentState = _appOpenAdsEnabled;
        displayName = 'App Open Ads';
        break;
    }

    final newState = !currentState;

    // Show confirmation dialog
    final confirmed = await AnimatedDialog.show(
      maxWidth: 400,
      context: context,
      title: 'Confirm $displayName ${newState ? 'Enable' : 'Disable'}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            newState
                ? 'Enable $displayName for all users?'
                : 'Disable $displayName for all users?',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: newState ? Colors.green.shade50 : Colors.red.shade50,
              border: Border.all(color: newState ? Colors.green : Colors.red),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              newState
                  ? 'Free users will see $displayName'
                  : '$displayName will not be shown to any user',
              style: TextStyle(
                fontSize: 12,
                color: newState ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: newState ? Colors.green : Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(newState ? 'Enable' : 'Disable'),
        ),
      ],
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _adminService.updateAdsSettings(
        widget.user.email!,
        selectedAdType,
        newState,
      );
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        await AnimatedDialog.show(
          maxWidth: 400,
          context: context,
          title: result['success'] ? 'Success' : 'Error',
          child: result['success']
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      '$displayName ${newState ? 'enabled' : 'disabled'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              : Text(
                  'Update failed: ${result['message']}',
                  style: const TextStyle(color: Colors.red),
                ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );

        // Reload ads settings
        if (result['success'] == true) {
          await _loadAdsSettings();
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        await AnimatedDialog.show(
          maxWidth: 400,
          context: context,
          title: 'Error',
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      }
    }
  }

  /// Release a new optional version (users can skip)
  Future<void> _releaseNewVersion() async {
    final versionController = TextEditingController();
    final changelogController = TextEditingController(
      text:
          '• Performance improvements\n• Bug fixes\n• UI enhancements\n• Security updates',
    );

    try {
      final result = await AnimatedDialog.show<Map<String, String>>(
        maxWidth: 500,
        context: context,
        title: 'Release New Version',
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Release a new optional version. Users can skip this update.',
                style: TextStyle(color: Colors.grey),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              const Text(
                'Version Number:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: versionController,
                decoration: InputDecoration(
                  hintText: '1.0.3',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Text(
                'Changelog (What\'s New):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: changelogController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop({
              'version': versionController.text,
              'changelog': changelogController.text,
            }),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Release'),
          ),
        ],
      );

      if (result == null || result['version']!.isEmpty) {
        // Dispose will be deferred at end of method
        return;
      }

      if (!mounted) {
        // Dispose will be deferred at end of method
        return;
      }

      // Use post-frame callback to defer setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _isLoading = true);
      });

      // Give the frame time to process
      await Future.delayed(const Duration(milliseconds: 100));

      final success = await VersionService.updateLatestVersion(
        newVersion: result['version']!,
        changelogText: result['changelog']!.isEmpty
            ? null
            : result['changelog'],
        forceUpdate: false,
      );

      if (!mounted) {
        // Dispose will be deferred at end of method
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _isLoading = false);

        // Show result dialog in next frame
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: Text(success ? 'Release Successful' : 'Release Failed'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    success ? Icons.check_circle : Icons.error,
                    color: success ? Colors.green : Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    success
                        ? 'Version ${result['version']} released!\nUsers will see an optional update.'
                        : 'Failed to release version. Please try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: success ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _isLoading = false);

          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Error'),
                content: Text('Error: $e'),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          }
        });
      }
    }

    // Defer disposal until after all animations complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        versionController.dispose();
        changelogController.dispose();
      });
    });
  }

  /// Force all users to update (use for critical/security updates)
  Future<void> _forceUpdateVersion() async {
    final versionController = TextEditingController();
    final messageController = TextEditingController();
    final changelogController = TextEditingController(
      text:
          '• CRITICAL: Security patches\n• CRITICAL: Bug fixes\n• System stability improvements',
    );

    // Show warning first
    final confirmed = await AnimatedDialog.show<bool>(
      maxWidth: 500,
      context: context,
      title: '⚠️ Force Update Warning',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This will BLOCK all users with older versions from using the app!',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Only use this for critical security updates or major bug fixes.',
            style: TextStyle(fontSize: 12, color: Colors.orange),
          ),
          const SizedBox(height: 12),
          const Text(
            'Make sure the new version is already available in app stores!',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('I Understand, Continue'),
        ),
      ],
    );

    if (confirmed != true) {
      // Dispose will be deferred at end of method
      return;
    }

    // Show input dialog
    final result = await AnimatedDialog.show<Map<String, String>>(
      maxWidth: 500,
      context: context,
      title: 'Force Update Configuration',
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Required Version:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: versionController,
              decoration: InputDecoration(
                hintText: '1.0.5',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const Text(
              'Update Message:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: messageController,
              decoration: InputDecoration(
                hintText: '⚠️ Critical security update required',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Changelog:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: changelogController,
              decoration: InputDecoration(
                hintText: '• CRITICAL: Security patches\n• CRITICAL: Bug fixes',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop({
            'version': versionController.text,
            'message': messageController.text,
            'changelog': changelogController.text,
          }),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Force Update'),
        ),
      ],
    );

    if (result == null || result['version']!.isEmpty) {
      // Dispose will be deferred at end of method
      return;
    }

    if (!mounted) {
      // Dispose will be deferred at end of method
      return;
    }

    // Use post-frame callback to defer setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _isLoading = true);
    });

    // Give the frame time to process
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final success = await VersionService.setMinimumRequiredVersion(
        minVersion: result['version']!,
        updateMessage: result['message']!.isEmpty ? null : result['message'],
        changelogText: result['changelog']!.isEmpty
            ? null
            : result['changelog'],
      );

      if (!mounted) {
        // Dispose will be deferred at end of method
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _isLoading = false);

        // Show result dialog in next frame
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: Text(success ? 'Force Update Active' : 'Failed'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    success ? Icons.warning : Icons.error,
                    color: success ? Colors.red : Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    success
                        ? 'Force update to version ${result['version']} is now ACTIVE!\n\nAll users will be blocked until they update.'
                        : 'Failed to activate force update.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _isLoading = false);

          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Error'),
                content: Text('Error: $e'),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          }
        });
      }
    }

    // Defer disposal until after all animations complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        versionController.dispose();
        messageController.dispose();
        changelogController.dispose();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Statistics',
            onPressed: _isLoading ? null : _loadUserStatistics,
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const LevelPlayAdminScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // User Statistics Section
                  Text(
                    'User Statistics',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_userStats != null)
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                context,
                                'Total Users',
                                _userStats!['totalUsers'].toString(),
                                Icons.people,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                context,
                                'Guest Users',
                                _userStats!['guestUsers'].toString(),
                                Icons.person_outline,
                                Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                context,
                                'Regular Users',
                                _userStats!['regularUsers'].toString(),
                                Icons.person,
                                Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                context,
                                'Premium Users',
                                _userStats!['premiumUsers'].toString(),
                                Icons.star,
                                Colors.purple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                context,
                                'Verified Emails',
                                _userStats!['verifiedEmailUsers'].toString(),
                                Icons.verified_user,
                                Colors.teal,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                context,
                                'Unverified Emails',
                                _userStats!['unverifiedEmailUsers'].toString(),
                                Icons.email,
                                Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Play Screen Features Section — live show/hide toggles
                  // for the Play Online / Computer / Local Multiplayer
                  // buttons players see. Changes take effect for everyone
                  // within a few seconds, no app update needed.
                  Text(
                    'Play Screen Features',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _playFeaturesLoaded
                          ? Column(
                              children: [
                                SwitchListTile(
                                  title: const Text('Play Online'),
                                  subtitle: const Text(
                                    'Matchmaking against a random opponent',
                                  ),
                                  value: _playFeatures['onlineEnabled'] ?? true,
                                  onChanged: (v) => _togglePlayFeature('onlineEnabled', v),
                                ),
                                SwitchListTile(
                                  title: const Text('Computer'),
                                  subtitle: const Text('Play against the CPU'),
                                  value: _playFeatures['cpuEnabled'] ?? true,
                                  onChanged: (v) => _togglePlayFeature('cpuEnabled', v),
                                ),
                                SwitchListTile(
                                  title: const Text('Local Multiplayer'),
                                  subtitle: const Text(
                                    'Two players, same device',
                                  ),
                                  value: _playFeatures['localMultiplayerEnabled'] ?? true,
                                  onChanged: (v) => _togglePlayFeature(
                                    'localMultiplayerEnabled',
                                    v,
                                  ),
                                ),
                              ],
                            )
                          : const Center(child: CircularProgressIndicator()),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Voice Chat Section — independent of the general Ads
                  // Settings below. Turning this off makes in-game voice
                  // chat free for everyone, without touching banner/
                  // interstitial/native/app-open ads anywhere else.
                  Text(
                    'Voice Chat',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _voiceChatAdGateLoaded
                          ? SwitchListTile(
                              title: const Text('Voice Chat Ad-Gate'),
                              subtitle: const Text(
                                'When on, non-premium players must watch an ad '
                                '(or upgrade) to unlock in-game voice chat. '
                                'Turn off to make voice chat free for everyone — '
                                'other ads are not affected.',
                              ),
                              value: _voiceChatAdGateEnabled,
                              onChanged: _toggleVoiceChatAdGate,
                            )
                          : const Center(child: CircularProgressIndicator()),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Admin Actions Section
                  Text(
                    'Admin Actions',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person_remove,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Delete Inactive Guest Users',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Permanently remove guest users who have not been active '
                            'for 15 days. This helps maintain database cleanliness.',
                          ),
                          const SizedBox(height: 16),
                          MainAppButton(
                            text: 'Delete Inactive Guests',
                            onPressed: _isLoading
                                ? () {}
                                : () => _deleteInactiveGuestUsers(),
                            icon: Icons.delete_forever,
                            isPrimary: false,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.analytics,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Database Statistics',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'View current database collection counts.',
                          ),
                          const SizedBox(height: 16),
                          MainAppButton(
                            text: 'Get Stats',
                            onPressed: _isLoading
                                ? () {}
                                : () => _getDatabaseStats(),
                            icon: Icons.analytics,
                            isPrimary: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.delete_sweep,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Cleanup Game Rooms',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Remove created games older than 5 minutes.',
                          ),
                          const SizedBox(height: 16),
                          MainAppButton(
                            text: 'Cleanup Game Rooms',
                            onPressed: _isLoading
                                ? () {}
                                : () => _cleanUpGameRooms(),
                            icon: Icons.delete_sweep,
                            isPrimary: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.sports_esports,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Game Mode Visibility',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Enable or disable specific game modes for players. '
                            'Shows active searches per mode.',
                          ),
                          const SizedBox(height: 16),
                          MainAppButton(
                            text: 'Manage Modes',
                            onPressed: _isLoading
                                ? () {}
                                : () => _manageGameModes(),
                            icon: Icons.sports_esports,
                            isPrimary: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.health_and_safety,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Active Games Health Check',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Verify and cleanup stale active games (1+ hour no activity). '
                            'Helps maintain accurate game counts when network fails or users go offline.',
                          ),
                          const SizedBox(height: 16),
                          MainAppButton(
                            text: 'Verify Active Games',
                            onPressed: _isLoading
                                ? () {}
                                : () => _verifyActiveGames(),
                            icon: Icons.health_and_safety,
                            isPrimary: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.cleaning_services,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Cleanup Archived Games',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Remove archived games older than 30 days.',
                          ),
                          const SizedBox(height: 16),
                          MainAppButton(
                            text: 'Cleanup Old Games',
                            onPressed: _isLoading
                                ? () {}
                                : () => _cleanupArchivedGames(),
                            icon: Icons.delete_sweep,
                            isPrimary: false,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.ads_click,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Manage Advertisements',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Control which ad types are shown to users.',
                          ),
                          const SizedBox(height: 16),
                          if (_adsStatusLoaded)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildAdStatusRow(
                                  'Banner Ads',
                                  _bannerAdsEnabled,
                                ),
                                const SizedBox(height: 8),
                                _buildAdStatusRow(
                                  'Interstitial Ads',
                                  _interstitialAdsEnabled,
                                ),
                                const SizedBox(height: 8),
                                _buildAdStatusRow(
                                  'Native Ads',
                                  _nativeAdsEnabled,
                                ),
                                const SizedBox(height: 8),
                                _buildAdStatusRow(
                                  'App Open Ads',
                                  _appOpenAdsEnabled,
                                ),
                                const SizedBox(height: 16),
                              ],
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          MainAppButton(
                            text: 'Manage Ads',
                            onPressed: (_isLoading || !_adsStatusLoaded)
                                ? () {}
                                : () => _toggleAdsForApp(),
                            icon: Icons.settings,
                            isPrimary: false,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Ad Inspector Section
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.bug_report,
                                color: Colors.green.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ad Inspector (Debug)',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Open the Unity LevelPlay test suite to verify your integration and '
                            'check which mediated networks respond. Enable "test suite" in '
                            'LevelPlay Ads settings and restart the app first.',
                          ),
                          const SizedBox(height: 16),
                          MainAppButton(
                            text: 'Open LevelPlay Test Suite',
                            onPressed: _isLoading
                                ? () {}
                                : () => _openAdInspector(),
                            icon: Icons.bug_report,
                            isPrimary: false,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Version Management Section
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.system_update,
                                color: Colors.purple.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Version Management',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Control app versioning and push updates to users.',
                          ),
                          const SizedBox(height: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              MainAppButton(
                                text: 'Release Optional Update',
                                onPressed: _isLoading
                                    ? () {}
                                    : () => _releaseNewVersion(),
                                icon: Icons.arrow_upward,
                                isPrimary: false,
                              ),
                              const SizedBox(height: 12),
                              MainAppButton(
                                text: '🚨 Force Critical Update',
                                onPressed: _isLoading
                                    ? () {}
                                    : () => _forceUpdateVersion(),
                                icon: Icons.warning,
                                isPrimary: false,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              border: Border.all(color: Colors.purple.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '💡 Tip: Automatic Firestore sync initializes on first app launch with current version.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.purple,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading...', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? Colors.blue : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdStatusRow(String label, bool isEnabled) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEnabled ? Colors.green.shade50 : Colors.red.shade50,
        border: Border.all(
          color: isEnabled ? Colors.green.shade300 : Colors.red.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isEnabled ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
          Icon(
            isEnabled ? Icons.check_circle : Icons.block,
            color: isEnabled ? Colors.green.shade600 : Colors.red.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
