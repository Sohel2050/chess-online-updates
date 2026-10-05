import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/poll_provider.dart';
import '../models/poll_model.dart';

class CommunityPollScreen extends StatefulWidget {
  final ChessUser user;

  const CommunityPollScreen({super.key, required this.user});

  @override
  State<CommunityPollScreen> createState() => _CommunityPollScreenState();
}

class _CommunityPollScreenState extends State<CommunityPollScreen> {
  String? _selectedOptionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = widget.user.uid;
      if (userId != null) {
        context.read<PollProvider>().loadPoll(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pollProvider = context.watch<PollProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Community Poll')),
      body: _buildBody(pollProvider),
    );
  }

  Widget _buildBody(PollProvider pollProvider) {
    if (pollProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (pollProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(pollProvider.error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final userId = widget.user.uid;
                if (userId != null) {
                  pollProvider.loadPoll(userId);
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (pollProvider.activePoll == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.poll_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No active polls at the moment',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('Check back later!', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    print('hasVoted: ${pollProvider.hasVoted}');

    return pollProvider.hasVoted
        ? _buildResultsView(pollProvider)
        : _buildVotingView(pollProvider);
  }

  Widget _buildVotingView(PollProvider pollProvider) {
    final poll = pollProvider.activePoll!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Help us improve!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    poll.question,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Select one option:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...poll.options.map((option) => _buildOptionTile(option)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _selectedOptionId == null
                ? null
                : () => _castVote(pollProvider),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Cast Vote',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(PollOption option) {
    final isSelected = _selectedOptionId == option.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        title: Text(option.text),
        leading: Radio<String>(
          value: option.id,
          groupValue: _selectedOptionId,
          onChanged: (value) {
            setState(() {
              _selectedOptionId = value;
            });
          },
        ),
        onTap: () {
          setState(() {
            _selectedOptionId = option.id;
          });
        },
      ),
    );
  }

  Future<void> _castVote(PollProvider pollProvider) async {
    if (_selectedOptionId == null) return;

    final userId = widget.user.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await pollProvider.castVote(userId, _selectedOptionId!);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for voting!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to cast vote. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildResultsView(PollProvider pollProvider) {
    final poll = pollProvider.activePoll!;
    final totalVotes = pollProvider.getTotalVotes();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poll.question,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Results:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...poll.options.map(
            (option) => _buildResultTile(option, pollProvider),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'You have answered this poll',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile(PollOption option, PollProvider pollProvider) {
    final percentage = pollProvider.getVotePercentage(option.id);
    final votes = pollProvider.pollResults[option.id] ?? 0;
    final isUserChoice = pollProvider.userVote?.optionId == option.id;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: percentage),
      builder: (context, animatedPercentage, child) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isUserChoice ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isUserChoice ? Colors.green : Colors.transparent,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        option.text,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isUserChoice
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isUserChoice)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: animatedPercentage / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isUserChoice
                          ? Colors.green
                          : Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${animatedPercentage.toStringAsFixed(1)}% ($votes ${votes == 1 ? 'vote' : 'votes'})',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
