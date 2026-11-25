import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/options.dart';
import '../journal/filters.dart';
import '../journal/journal_api.dart';
import '../journal/journal_controller.dart';
import '../journal/models/trade.dart';
import '../state/app_state.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/state_views.dart';
import '../widgets/trade_tile.dart';
import 'settings_screen.dart';
import 'trade_flow.dart';

/// Filterable, paged list of trades.
class TradesScreen extends StatefulWidget {
  const TradesScreen({super.key, required this.state, required this.journal});

  final AppState state;
  final JournalController journal;

  @override
  State<TradesScreen> createState() => _TradesScreenState();
}

class _TradesScreenState extends State<TradesScreen> {
  static const _pageSize = 20;

  final TradeFilters _filters = TradeFilters();
  final ScrollController _scroll = ScrollController();
  List<Trade> _items = [];
  int _page = 0;
  int _pages = 1;
  int _total = 0;
  bool _loading = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    widget.journal.addListener(_reset);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
  }

  @override
  void dispose() {
    widget.journal.removeListener(_reset);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  /// Starts again from page 1 (filters changed, a trade was saved, etc.).
  void _reset() {
    if (!mounted) return;
    _generation++;
    setState(() {
      _items = [];
      _page = 0;
      _pages = 1;
      _total = 0;
      _loading = false;
      _error = null;
    });
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (!widget.journal.configured || _loading || _page >= _pages) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.journal.api.listTrades(
        _filters.toQuery(page: _page + 1, limit: _pageSize),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = [..._items, ...result.items];
        _page = result.page;
        _pages = result.pages;
        _total = result.total;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = JournalController.friendly(e);
        _loading = false;
      });
    }
  }

  Future<void> _openFilters() async {
    final result = await showFilterSheet(context, current: _filters, setups: widget.journal.setupOptions);
    if (result == null) return;
    _filters
      ..pair = result.pair
      ..direction = result.direction
      ..setup = result.setup
      ..session = result.session
      ..timeframe = result.timeframe
      ..marketCondition = result.marketCondition
      ..from = result.from
      ..to = result.to;
    _reset();
  }

  @override
  Widget build(BuildContext context) {
    final newestFirst = _filters.sort == '-entryTime';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trades'),
        actions: [
          IconButton(
            tooltip: newestFirst ? 'Newest first' : 'Oldest first',
            icon: Icon(newestFirst ? Icons.arrow_downward : Icons.arrow_upward),
            onPressed: () {
              _filters.sort = newestFirst ? 'entryTime' : '-entryTime';
              _reset();
            },
          ),
          IconButton(
            tooltip: 'Filters',
            icon: Badge(
              label: Text('${_filters.activeCount}'),
              isLabelVisible: _filters.activeCount > 0,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _openFilters,
          ),
          settingsButton(context, widget.state, widget.journal),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openNewTrade(context, widget.journal),
        icon: const Icon(Icons.add),
        label: const Text('Log trade'),
      ),
      body: !widget.journal.configured
          ? SetupPrompt(onOpenSettings: () => openSettings(context, widget.state, widget.journal))
          : Column(
              children: [
                _statusTabs(),
                Expanded(child: _list()),
              ],
            ),
    );
  }

  Widget _statusTabs() {
    final tabs = <String?>[null, ...tradeStatuses];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          for (final s in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(s == null ? 'All' : titleCase(s)),
                selected: _filters.status == s,
                onSelected: (_) {
                  _filters.status = s;
                  _reset();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _list() {
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty && _error != null) {
      return ListView(children: [ErrorState(message: _error!, onRetry: _reset)]);
    }
    if (_items.isEmpty) {
      final filtered = _filters.activeCount > 0 || _filters.status != null;
      return RefreshIndicator(
        onRefresh: () async => _reset(),
        child: ListView(
          children: [
            EmptyState(
              icon: Icons.list_alt_outlined,
              title: filtered ? 'No trades match' : 'No trades yet',
              message: filtered ? 'Try clearing a filter.' : 'Log your first trade to see it here.',
              actionLabel: filtered ? 'Clear filters' : 'Log trade',
              onAction: () {
                if (filtered) {
                  _filters
                    ..clear()
                    ..status = null;
                  _reset();
                } else {
                  openNewTrade(context, widget.journal);
                }
              },
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _reset(),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i < _items.length) {
            final t = _items[i];
            return TradeTile(trade: t, onTap: () => openTrade(context, widget.journal, t.id));
          }
          return _footer();
        },
      ),
    );
  }

  Widget _footer() {
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12);
    if (_error != null) {
      return Center(child: TextButton(onPressed: _loadMore, child: Text('$_error  Tap to retry')));
    }
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(child: Text('$_total trade${_total == 1 ? '' : 's'}', style: muted)),
    );
  }
}
