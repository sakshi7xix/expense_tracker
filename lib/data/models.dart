class Category {
  const Category({required this.id, required this.name});
  final int id;
  final String name;
}

/// One spend. [amount] is your share in paise; [total] is the whole bill.
class Entry {
  const Entry({
    required this.id,
    required this.title,
    required this.amount,
    required this.total,
    required this.categoryId,
    required this.day,
    this.billId,
    this.groupId,
  });
  final int id;
  final String title;
  final int amount;
  final int total;
  final int categoryId;
  final String day;
  final int? billId;
  final int? groupId;

  bool get isSplit => total != amount;
  bool get isAutopay => billId != null;
}

/// A friend with their running balance: positive means they owe you.
class FriendBalance {
  const FriendBalance({
    required this.id,
    required this.name,
    required this.contact,
    required this.joined,
    required this.balance,
  });
  final int id;
  final String name;
  final String contact;
  final bool joined;
  final int balance;
}

class LedgerItem {
  const LedgerItem({
    required this.id,
    required this.friendId,
    required this.friendName,
    required this.title,
    required this.amount,
    required this.isPayment,
    required this.day,
  });
  final int id;
  final int friendId;
  final String friendName;
  final String title;
  final int amount;
  final bool isPayment;
  final String day;
}

class Group {
  const Group({required this.id, required this.name, required this.memberIds});
  final int id;
  final String name;
  final List<int> memberIds;
}

/// A group's money: what its spends came to, and where you stand with each
/// member from those spends (positive: they owe you).
class GroupSummary {
  const GroupSummary({required this.spent, required this.balances});
  final int spent;
  final Map<int, int> balances;

  /// Your overall position in the group.
  int get balance => balances.values.fold(0, (sum, b) => sum + b);
}

enum BillState { due, paid, skipped }

class BillStatus {
  const BillStatus({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDay,
    required this.autopay,
    required this.categoryId,
    required this.state,
  });
  final int id;
  final String name;
  final int amount;
  final int dueDay;
  final bool autopay;
  final int categoryId;
  final BillState state;
}
