/// `source` values for money that moves between you and the people you share
/// expenses with.
///
/// These transactions change account balances (the cash really moved) but are
/// not spending or income, so budgets, insights and monthly totals skip them.
const String kSplitLentSource = 'split_lent';
const String kSplitReceivedSource = 'split_received';
const String kSplitPaidBackSource = 'split_paid_back';

const List<String> kSplitCashSources = [
  kSplitLentSource,
  kSplitReceivedSource,
  kSplitPaidBackSource,
];

/// True for a transaction that only moved shared money around.
bool isSplitCashFlow(String source) => kSplitCashSources.contains(source);
