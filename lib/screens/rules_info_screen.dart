import 'package:flutter/material.dart';

class RulesInfoScreen extends StatelessWidget {
  const RulesInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game Rules & Info')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to Chess!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Chess is a two-player strategy board game played on a checkered board with 64 squares arranged in an 8x8 grid. Each player begins with 16 pieces: one king, one queen, two rooks, two knights, two bishops, and eight pawns. The goal is to checkmate the opponent\'s king, meaning the king is under immediate attack (in check) and there is no legal way to remove or block the attack.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text(
              'Basic Piece Movements:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildRuleSection(
              context,
              'Pawn:',
              'Moves forward one square, but captures diagonally one square forward. On its first move, it can move two squares forward. Pawns are the only pieces that capture differently than they move.',
            ),
            _buildRuleSection(
              context,
              'Rook:',
              'Moves any number of squares horizontally or vertically. Rooks are powerful pieces, especially when working together.',
            ),
            _buildRuleSection(
              context,
              'Knight:',
              'Moves in an "L" shape: two squares in one direction (horizontal or vertical) and then one square perpendicular to that direction. Knights are the only pieces that can jump over other pieces.',
            ),
            _buildRuleSection(
              context,
              'Bishop:',
              'Moves any number of squares diagonally. Bishops always stay on squares of the same color.',
            ),
            _buildRuleSection(
              context,
              'Queen:',
              'Moves any number of squares horizontally, vertically, or diagonally. The queen is the most powerful piece on the board.',
            ),
            _buildRuleSection(
              context,
              'King:',
              'Moves exactly one square in any direction (horizontal, vertical, or diagonal). The king cannot move into a square that is attacked by an opponent\'s piece.',
            ),
            const SizedBox(height: 24),
            Text(
              'Special Moves:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildRuleSection(
              context,
              'Castling:',
              'A special move involving the king and one of the rooks. It\'s the only move where two pieces move at once. The king moves two squares towards a rook, and the rook moves to the square the king crossed.',
            ),
            _buildRuleSection(
              context,
              'En Passant:',
              'A special pawn capture that can occur when a pawn moves two squares forward from its starting position and lands beside an opponent\'s pawn on an adjacent file. The opponent\'s pawn can capture it as if it had only moved one square.',
            ),
            _buildRuleSection(
              context,
              'Pawn Promotion:',
              'When a pawn reaches the eighth rank (the furthest row from its starting position), it must be promoted to a queen, rook, bishop, or knight of the same color.',
            ),
            const SizedBox(height: 24),
            Text(
              'Game End Conditions:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildRuleSection(
              context,
              'Checkmate:',
              'The primary goal. When a king is attacked and has no legal moves to escape the attack.',
            ),
            _buildRuleSection(
              context,
              'Stalemate:',
              'Occurs when the player whose turn it is to move has no legal move, but their king is not in check. The game is a draw.',
            ),
            _buildRuleSection(
              context,
              'Draw by Agreement:',
              'Players can agree to a draw at any point.',
            ),
            _buildRuleSection(
              context,
              'Draw by Repetition:',
              'If the same position occurs three times, the game is a draw.',
            ),
            _buildRuleSection(
              context,
              'Draw by Fifty-Move Rule:',
              'If 50 moves have passed without a pawn move or a capture, the game is a draw.',
            ),
            _buildRuleSection(
              context,
              'Insufficient Material:',
              'If neither player has enough pieces to checkmate the opponent, the game is a draw.',
            ),
            const SizedBox(height: 24),
            Text(
              'Good luck and have fun playing Chess!',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(content, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
