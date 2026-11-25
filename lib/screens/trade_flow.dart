import 'package:flutter/material.dart';

import '../journal/journal_controller.dart';
import '../journal/models/trade.dart';
import 'trade_detail_screen.dart';
import 'trade_form_screen.dart';

/// Opens the log-trade form and, once saved, the new trade's detail page.
Future<void> openNewTrade(BuildContext context, JournalController journal) async {
  final trade = await Navigator.of(context).push<Trade>(
    MaterialPageRoute(builder: (_) => TradeFormScreen(journal: journal)),
  );
  if (trade != null && context.mounted) openTrade(context, journal, trade.id);
}

Future<void> openEditTrade(BuildContext context, JournalController journal, Trade trade) {
  return Navigator.of(context).push<Trade>(
    MaterialPageRoute(builder: (_) => TradeFormScreen(journal: journal, existing: trade)),
  );
}

void openTrade(BuildContext context, JournalController journal, String id) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => TradeDetailScreen(journal: journal, id: id)),
  );
}
