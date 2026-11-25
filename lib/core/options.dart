/// Fixed pick lists. Free text on the backend means a typo creates a new
/// analytics segment, so the UI only offers these (setups can be extended).
const List<String> defaultSetups = ['breakout', 'pullback', 'range fade'];
const List<String> timeframes = ['m5', 'm15', 'h1', 'h4', 'd1'];
const List<String> emotions = [
  'calm',
  'confident',
  'fomo',
  'revenge',
  'bored',
  'fearful',
  'greedy',
  'hopeful',
];
const List<String> mistakeOptions = [
  'broke rule',
  'overtraded',
  'oversized',
  'moved stop',
  'no setup',
  'early exit',
  'late exit',
];
const List<String> pairOptions = [
  'EURUSD',
  'GBPUSD',
  'USDJPY',
  'USDCHF',
  'AUDUSD',
  'USDCAD',
  'NZDUSD',
  'XAUUSD',
  'BTCUSD',
];
const List<String> sessionOptions = ['asian', 'london', 'newyork'];
const List<String> htfTrends = ['up', 'down', 'sideways'];
const List<String> marketConditions = ['trending', 'ranging', 'news'];
const List<String> entryQualities = ['early', 'on_time', 'late', 'chased'];
const List<String> stopPlacements = ['logical', 'too_tight', 'too_wide'];
const List<String> tradeStatuses = ['planned', 'open', 'closed', 'skipped'];
