import '../core/options.dart';

enum FieldKind { text, longText, number, integer, dateTime, tri, choice, scale, tags, url }

enum FieldSection { plan, entry, exit, psychology, review }

/// Describes one trade field. The form and the detail page are both generated
/// from [tradeFields], so a new backend field only needs one line here.
class FieldSpec {
  const FieldSpec(
    this.key,
    this.label,
    this.kind,
    this.section, {
    this.options = const [],
    this.statuses = const {},
    this.min,
    this.max,
    this.allowCustom = false,
    this.suggestions = const [],
    this.hint,
  });

  final String key;
  final String label;
  final FieldKind kind;
  final FieldSection section;
  final List<String> options;

  /// Statuses this field is shown for. Empty means always.
  final Set<String> statuses;
  final double? min;
  final double? max;
  final bool allowCustom;
  final List<String> suggestions;
  final String? hint;

  bool visibleFor(String status) => statuses.isEmpty || statuses.contains(status);
}

const Set<String> _openOrClosed = {'open', 'closed'};
const Set<String> _closedOnly = {'closed'};
const Set<String> _closedOrSkipped = {'closed', 'skipped'};

const List<FieldSpec> tradeFields = [
  // Plan
  FieldSpec('entryPrice', 'Entry price', FieldKind.number, FieldSection.plan),
  FieldSpec('stopLoss', 'Stop loss', FieldKind.number, FieldSection.plan),
  FieldSpec('takeProfit', 'Take profit', FieldKind.number, FieldSection.plan),
  FieldSpec('positionSize', 'Position size (lots)', FieldKind.number, FieldSection.plan),
  FieldSpec('riskPercent', 'Risk %', FieldKind.number, FieldSection.plan, min: 0, max: 100),
  FieldSpec('setup', 'Setup', FieldKind.choice, FieldSection.plan, options: defaultSetups, allowCustom: true),
  FieldSpec('timeframe', 'Timeframe', FieldKind.choice, FieldSection.plan, options: timeframes),
  FieldSpec('htfTrend', 'Higher-timeframe trend', FieldKind.choice, FieldSection.plan, options: htfTrends),
  FieldSpec('marketCondition', 'Market condition', FieldKind.choice, FieldSection.plan, options: marketConditions),
  FieldSpec('newsNearby', 'News nearby', FieldKind.tri, FieldSection.plan),
  FieldSpec('confluence', 'Confluence', FieldKind.tags, FieldSection.plan, hint: 'Type a reason and press add'),
  FieldSpec('entryScreenshot', 'Entry screenshot URL', FieldKind.url, FieldSection.plan),

  // Entry
  FieldSpec('entryTime', 'Entry time', FieldKind.dateTime, FieldSection.entry, statuses: _openOrClosed),
  FieldSpec('spreadPips', 'Spread (pips)', FieldKind.number, FieldSection.entry, statuses: _openOrClosed, min: 0),
  FieldSpec('entryQuality', 'Entry quality', FieldKind.choice, FieldSection.entry,
      options: entryQualities, statuses: _openOrClosed),
  FieldSpec('stopPlacement', 'Stop placement', FieldKind.choice, FieldSection.entry,
      options: stopPlacements, statuses: _openOrClosed),

  // Exit
  FieldSpec('exitTime', 'Exit time', FieldKind.dateTime, FieldSection.exit, statuses: _closedOnly),
  FieldSpec('exitPrice', 'Exit price', FieldKind.number, FieldSection.exit, statuses: _closedOnly),
  FieldSpec('pnl', 'P&L (money, optional)', FieldKind.number, FieldSection.exit, statuses: _closedOnly),
  FieldSpec('maeR', 'MAE (R)', FieldKind.number, FieldSection.exit, statuses: _closedOnly),
  FieldSpec('mfeR', 'MFE (R)', FieldKind.number, FieldSection.exit, statuses: _closedOnly),
  FieldSpec('movedStop', 'Moved stop', FieldKind.tri, FieldSection.exit, statuses: _closedOnly),
  FieldSpec('closedEarly', 'Closed early', FieldKind.tri, FieldSection.exit, statuses: _closedOnly),
  FieldSpec('heldTooLong', 'Held too long', FieldKind.tri, FieldSection.exit, statuses: _closedOnly),
  FieldSpec('exitScreenshot', 'Exit screenshot URL', FieldKind.url, FieldSection.exit, statuses: _closedOnly),

  // Psychology
  FieldSpec('moodBefore', 'Mood before (1-5)', FieldKind.scale, FieldSection.psychology, min: 1, max: 5),
  FieldSpec('hoursSlept', 'Hours slept', FieldKind.number, FieldSection.psychology, min: 0, max: 24),
  FieldSpec('emotionAtEntry', 'Emotion at entry', FieldKind.choice, FieldSection.psychology, options: emotions),
  FieldSpec('emotionDuring', 'Emotion during', FieldKind.choice, FieldSection.psychology,
      options: emotions, statuses: _openOrClosed),
  FieldSpec('emotionAfter', 'Emotion after', FieldKind.choice, FieldSection.psychology,
      options: emotions, statuses: _openOrClosed),
  FieldSpec('mistakes', 'Mistakes', FieldKind.tags, FieldSection.psychology, suggestions: mistakeOptions),

  // Review
  FieldSpec('followedRules', 'Followed my rules', FieldKind.tri, FieldSection.review, statuses: _closedOrSkipped),
  FieldSpec('lesson', 'Lesson', FieldKind.longText, FieldSection.review, statuses: _closedOrSkipped),
  FieldSpec('didWell', 'Did well', FieldKind.longText, FieldSection.review, statuses: _closedOrSkipped),
  FieldSpec('toFix', 'To fix', FieldKind.longText, FieldSection.review, statuses: _closedOrSkipped),
  FieldSpec('notes', 'Notes', FieldKind.longText, FieldSection.review, statuses: _closedOrSkipped),
];

final Map<String, FieldSpec> specByKey = {for (final s in tradeFields) s.key: s};

/// Keys the server rejects if sent.
const Set<String> readOnlyKeys = {
  '_id',
  '__v',
  'createdAt',
  'updatedAt',
  'session',
  'plannedRR',
  'rMultiple',
};
