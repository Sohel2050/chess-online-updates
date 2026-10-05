import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/color_option.dart';
import 'package:flutter_chess_app/widgets/difficulty_option.dart';
import 'package:provider/provider.dart';
import 'package:squares/squares.dart';

class CPUDifficultyDialog extends StatefulWidget {
  final Function(int difficulty, int playerColor) onConfirm;

  const CPUDifficultyDialog({super.key, required this.onConfirm});

  @override
  State<CPUDifficultyDialog> createState() => _CPUDifficultyDialogState();
}

class _CPUDifficultyDialogState extends State<CPUDifficultyDialog> {
  int _selectedDifficulty = 2; // Default to Normal
  int _selectedColor = Squares.white; // Default to White

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Player Color Selection
          Text(
            'Choose Your Color',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ColorOption(
                  color: Colors.white,
                  label: Constants.white,
                  isSelected: _selectedColor == Squares.white,
                  onTap: () => setState(() => _selectedColor = Squares.white),
                  icon: '♔',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ColorOption(
                  color: Colors.black,
                  label: Constants.black,
                  isSelected: _selectedColor == Squares.black,
                  onTap: () => setState(() => _selectedColor = Squares.black),
                  icon: '♚',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Difficulty Selection
          Text(
            'Select Difficulty',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          ...Constants.difficulties.map(
            (difficulty) => DifficultyOption(
              name: difficulty[Constants.name],
              level: difficulty[Constants.level],
              description: difficulty[Constants.description],
              icon: difficulty[Constants.icon],
              isSelected: _selectedDifficulty == difficulty[Constants.level],
              onTap:
                  () => setState(
                    () => _selectedDifficulty = difficulty[Constants.level],
                  ),
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  // dispose stockfish engine if needed
                  context.read<GameProvider>().disposeStockfish();

                  Navigator.of(
                    context,
                  ).pop(); // Close the dialog without action
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  log(
                    'Selected Difficulty: $_selectedDifficulty, Color: $_selectedColor',
                  );
                  widget.onConfirm(_selectedDifficulty, _selectedColor);
                },
                child: const Text('Start Game'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
