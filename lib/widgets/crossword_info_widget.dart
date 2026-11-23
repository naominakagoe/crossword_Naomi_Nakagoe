import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../providers.dart';
import '../utils.dart';
import 'ticker_builder.dart';

class CrosswordInfoWidget extends ConsumerWidget {
  const CrosswordInfoWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(sizeProvider);
    final displayInfo = ref.watch(displayInfoProvider);
    final startTime = ref.watch(startTimeProvider);
    final endTime = ref.watch(endTimeProvider);
    final remaining = ref.watch(expectedRemainingTimeProvider);
    final workers = ref.watch(workerCountProvider);

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 32, bottom: 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.onPrimary.withAlpha(230),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: DefaultTextStyle(
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CrosswordInfoRichText(
                      label: 'Grid size',
                      value: '${size.width} x ${size.height}',
                    ),
                    _CrosswordInfoRichText(
                      label: 'Words in grid',
                      value: displayInfo.wordsInGridCount,
                    ),
                    _CrosswordInfoRichText(
                      label: 'Candidate words',
                      value: displayInfo.candidateWordsCount,
                    ),
                    _CrosswordInfoRichText(
                      label: 'Locations to explore',
                      value: displayInfo.locationsToExploreCount,
                    ),
                    _CrosswordInfoRichText(
                      label: 'Known bad locations',
                      value: displayInfo.knownBadLocationsCount,
                    ),
                    _CrosswordInfoRichText(
                      label: 'Grid filled',
                      value: displayInfo.gridFilledPercentage,
                    ),
                    _CrosswordInfoRichText(
                      label: 'Max worker count',
                      value: workers.label,
                    ),
                    switch ((startTime, endTime)) {
                      (null, _) => _CrosswordInfoRichText(
                          label: 'Time elapsed',
                          value: 'Not started yet',
                        ),
                      (DateTime start, null) => TickerBuilder(
                          builder: (context) => _CrosswordInfoRichText(
                            label: 'Time elapsed',
                            value: DateTime.now().difference(start).formatted,
                          ),
                        ),
                      (DateTime start, DateTime end) => _CrosswordInfoRichText(
                          label: 'Completed in',
                          value: end.difference(start).formatted,
                        ),
                    },
                    if (startTime != null && endTime == null)
                      _CrosswordInfoRichText(
                        label: 'Est. remaining',
                        value: remaining.formatted,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CrosswordInfoRichText extends StatelessWidget {
  const _CrosswordInfoRichText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: '$label ', style: style),
          TextSpan(
            text: value,
            style: style.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}