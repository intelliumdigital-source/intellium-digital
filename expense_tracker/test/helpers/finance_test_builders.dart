import 'package:finance_tracker/main.dart';

DateTime testDate(int year, int month, int day) => DateTime(year, month, day);

ExpenseItem buildExpenseItem({
  String id = 'expense-1',
  String title = 'Expense',
  double amount = 100,
  String category = 'Food',
  String paymentMethod = 'Cash',
  DateTime? createdAt,
}) {
  return ExpenseItem(
    id: id,
    title: title,
    amount: amount,
    category: category,
    paymentMethod: paymentMethod,
    createdAt: createdAt ?? testDate(2024, 1, 1),
  );
}

FixedExpenseItem buildFixedExpenseItem({
  String id = 'fixed-1',
  String name = 'Fixed Expense',
  double amount = 100,
}) {
  return FixedExpenseItem(
    id: id,
    name: name,
    amount: amount,
  );
}

BillItem buildBillItem({
  String id = 'bill-1',
  String title = 'Bill',
  double amount = 100,
  DateTime? dueDate,
  DateTime? paidDate,
  String? settledCycleKey,
  String category = 'Utilities',
  bool isRecurring = false,
  bool isPaid = false,
}) {
  return BillItem(
    id: id,
    title: title,
    amount: amount,
    dueDate: dueDate ?? testDate(2024, 1, 1),
    paidDate: paidDate,
    settledCycleKey: settledCycleKey,
    category: category,
    isRecurring: isRecurring,
    isPaid: isPaid,
  );
}

IncomeEntry buildIncomeEntry({
  String id = 'income-1',
  double amount = 100,
  DateTime? receivedAt,
  String note = 'Income',
}) {
  return IncomeEntry(
    id: id,
    amount: amount,
    receivedAt: receivedAt ?? testDate(2024, 1, 1),
    note: note,
  );
}

SavingsContributionEntry buildSavingsContributionEntry({
  String id = 'savings-1',
  double amount = 100,
  DateTime? createdAt,
  SavingsTransferType type = SavingsTransferType.contribution,
}) {
  return SavingsContributionEntry(
    id: id,
    amount: amount,
    createdAt: createdAt ?? testDate(2024, 1, 1),
    type: type,
  );
}
