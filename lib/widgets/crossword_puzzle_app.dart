import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../providers.dart';
import 'crossword_generator_widget.dart';
import 'crossword_puzzle_widget.dart';
import 'puzzle_completed_widget.dart';

class CrosswordPuzzleApp extends StatelessWidget {
  const CrosswordPuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return _EagerInitialization(
      child: Scaffold(
        appBar: AppBar(
          actions: [_CrosswordPuzzleAppMenu()],
          titleTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          title: Text('Crossword Puzzle'),
        ),
        body: SafeArea(
          child: Consumer(
            builder: (context, ref, _) {
              final workQueueAsync = ref.watch(workQueueProvider);
              final puzzle = ref.watch(puzzleProvider);

              return workQueueAsync.when(
                data: (workQueue) {
                  // Ganó.
                  if (puzzle.solved) {
                    return PuzzleCompletedWidget();
                  }
                  // El generador terminó y el juego ya está armado.
                  if (workQueue.isCompleted &&
                      puzzle.crossword == workQueue.crossword &&
                      puzzle.crossword.words.isNotEmpty) {
                    return CrosswordPuzzleWidget();
                  }
                  // Todavía generando.
                  return CrosswordGeneratorWidget();
                },
                error: (error, stackTrace) => Center(child: Text('$error')),
                loading: () => Center(child: CircularProgressIndicator()),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EagerInitialization extends ConsumerWidget {
  const _EagerInitialization({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(wordListProvider);
    return child;
  }
}

class _CrosswordPuzzleAppMenu extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) => MenuAnchor(
        menuChildren: [
          for (final entry in CrosswordSize.values)
            MenuItemButton(
              onPressed: () => ref.read(sizeProvider.notifier).setSize(entry),
              leadingIcon: entry == ref.watch(sizeProvider)
                  ? Icon(Icons.radio_button_checked_outlined)
                  : Icon(Icons.radio_button_unchecked_outlined),
              child: Text(entry.label),
            ),
        ],
        builder: (context, controller, child) => IconButton(
          onPressed: () => controller.open(),
          icon: Icon(Icons.settings),
        ),
      );
}