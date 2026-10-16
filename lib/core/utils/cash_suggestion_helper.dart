import 'currency_formatter.dart';

/// Helper utility to generate dynamic, practical Indonesian Rupiah cash payment
/// suggestions based on the actual amount due and commonly used banknote denominations.
class CashPaymentSuggestionHelper {
  /// Standard Indonesian Rupiah banknote denominations in circulation.
  static const List<int> banknoteDenominations = [
    1000,
    2000,
    5000,
    10000,
    20000,
    50000,
    100000,
  ];

  /// Generates dynamic suggested cash tender amounts for [amountDue].
  ///
  /// Guarantees:
  /// 1. Always includes the exact payable amount as the first option.
  /// 2. All suggested amounts are >= [amountDue] (never below).
  /// 3. All amounts are rounded up to realistic banknote multiples (10k, 50k, 100k, etc.).
  /// 4. Output contains no duplicates and is strictly sorted in ascending order.
  /// 5. Returns a practical subset (up to [maxSuggestions], defaults to 5).
  static List<int> getSuggestedAmounts(num amountDue, {int maxSuggestions = 5}) {
    final due = amountDue.ceil();
    if (due <= 0) return [];

    final suggestions = <int>{};

    // 1. Exact payable amount
    suggestions.add(due);

    // 2. Denomination round-up steps based on scale of amount due
    final roundUpSteps = <int>[];
    if (due < 20000) {
      if (due % 5000 != 0) roundUpSteps.add(5000);
      if (due % 10000 != 0) roundUpSteps.add(10000);
      roundUpSteps.addAll([20000, 50000]);
    } else if (due < 100000) {
      if (due % 10000 != 0) roundUpSteps.add(10000);
      if (due % 50000 != 0) roundUpSteps.add(50000);
      roundUpSteps.addAll([100000, 200000]);
    } else if (due < 500000) {
      if (due % 10000 != 0) roundUpSteps.add(10000);
      if (due % 50000 != 0) roundUpSteps.add(50000);
      if (due % 100000 != 0) roundUpSteps.add(100000);
      roundUpSteps.addAll([200000, 500000]);
    } else if (due < 1000000) {
      if (due % 100000 != 0) roundUpSteps.add(100000);
      roundUpSteps.addAll([1000000]);
    } else {
      if (due % 100000 != 0) roundUpSteps.add(100000);
      if (due % 500000 != 0) roundUpSteps.add(500000);
      final nextMillion = ((due + 1000000 - 1) ~/ 1000000) * 1000000;
      if (nextMillion > due) suggestions.add(nextMillion);
    }

    for (final step in roundUpSteps) {
      final rounded = ((due + step - 1) ~/ step) * step;
      if (rounded > due) {
        suggestions.add(rounded);
      }
    }

    // 3. Relevant wallet milestones scaled to amount due (avoiding excessive suggestions)
    final List<int> candidateMilestones;
    if (due < 100000) {
      candidateMilestones = [50000, 100000, 200000, 500000];
    } else if (due < 200000) {
      candidateMilestones = [150000, 200000, 300000, 500000];
    } else if (due < 500000) {
      candidateMilestones = [300000, 400000, 500000, 1000000];
    } else if (due < 1000000) {
      candidateMilestones = [1000000];
    } else {
      candidateMilestones = [
        ((due + 500000 - 1) ~/ 500000) * 500000,
        ((due + 1000000 - 1) ~/ 1000000) * 1000000,
      ];
    }

    for (final m in candidateMilestones) {
      if (m > due) {
        suggestions.add(m);
      }
    }

    // 4. Filter, deduplicate, and sort ascending
    final sorted = suggestions.where((s) => s >= due).toList()..sort();

    // 5. Return at most maxSuggestions
    if (sorted.length <= maxSuggestions) {
      return sorted;
    }

    return sorted.sublist(0, maxSuggestions);
  }

  /// Calculates change returned to the customer.
  /// If cash received is less than amount due, change is 0.0.
  static double calculateChange({required num amountDue, required num cashReceived}) {
    if (cashReceived < amountDue) return 0.0;
    return (cashReceived - amountDue).toDouble();
  }

  /// Calculates shortage when cash received does not cover amount due.
  static double calculateShortage({required num amountDue, required num cashReceived}) {
    if (cashReceived >= amountDue) return 0.0;
    return (amountDue - cashReceived).toDouble();
  }

  /// Formats an amount using standard Indonesian Rupiah notation.
  static String format(num amount) {
    return CurrencyFormatter.format(amount);
  }
}
