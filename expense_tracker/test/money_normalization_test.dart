import 'package:finance_tracker/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('money normalization helpers', () {
    test('normalizeMoney rounds common decimal cases consistently', () {
      expect(normalizeMoney(0.1 + 0.2), 0.3);
      expect(normalizeMoney(999.99), 999.99);
      expect(normalizeMoney(1000.50), 1000.5);
      expect(normalizeMoney(1234567890.126), 1234567890.13);
    });

    test('normalizeMoney rejects invalid finite values', () {
      expect(normalizeMoney(double.nan), 0.0);
      expect(normalizeMoney(double.infinity), 0.0);
      expect(normalizeMoney(double.negativeInfinity), 0.0);
      expect(normalizeMoney(-50, allowNegative: false), 0.0);
    });

    test('parseMoneyInput normalizes formatted text input safely', () {
      expect(parseMoneyInput('₱1,000.50'), 1000.5);
      expect(parseMoneyInput('PHP 999.99'), 999.99);
      expect(parseMoneyInput(' 1234567.895 '), 1234567.9);
      expect(parseMoneyInput('-99.99'), isNull);
      expect(parseMoneyInput('not money'), isNull);
    });
  });

  group('money-safe finance snapshots', () {
    test('calculateBalanceLedgerSnapshot rounds totals and balances to centavos', () {
      final snapshot = calculateBalanceLedgerSnapshot(
        startingBalance: 1000.50,
        incomeEntries: <IncomeEntry>[
          IncomeEntry(
            id: 'income-a',
            amount: 0.1,
            receivedAt: DateTime.utc(2026, 1, 1),
            note: 'Fraction A',
          ),
          IncomeEntry(
            id: 'income-b',
            amount: 0.2,
            receivedAt: DateTime.utc(2026, 1, 2),
            note: 'Fraction B',
          ),
        ],
        bills: <BillItem>[
          BillItem(
            id: 'bill-paid',
            title: 'Internet',
            amount: 99.99,
            dueDate: DateTime.utc(2026, 1, 5),
            paidDate: DateTime.utc(2026, 1, 5),
            settledCycleKey: null,
            category: 'Utilities',
            isRecurring: false,
            isPaid: true,
          ),
          BillItem(
            id: 'bill-unpaid',
            title: 'Rent',
            amount: 1000.50,
            dueDate: DateTime.utc(2026, 1, 10),
            paidDate: null,
            settledCycleKey: null,
            category: 'Housing',
            isRecurring: false,
            isPaid: false,
          ),
        ],
        expenses: <ExpenseItem>[
          ExpenseItem(
            id: 'expense-a',
            title: 'Groceries',
            amount: 100.105,
            category: 'Food',
            paymentMethod: 'Cash',
            createdAt: DateTime.utc(2026, 1, 3),
          ),
        ],
        savingsBalance: 500.555,
        savingsHistory: <SavingsContributionEntry>[
          SavingsContributionEntry(
            id: 'save-a',
            amount: 50.005,
            createdAt: DateTime.utc(2026, 1, 3),
          ),
          SavingsContributionEntry(
            id: 'save-b',
            amount: 0.105,
            createdAt: DateTime.utc(2026, 1, 4),
            type: SavingsTransferType.withdrawal,
          ),
        ],
      );

      expect(snapshot.totalIncome, 0.3);
      expect(snapshot.settledBillsTotal, 99.99);
      expect(snapshot.upcomingBillsTotal, 1000.5);
      expect(snapshot.totalSpending, 100.11);
      expect(snapshot.savingsContributionsTotal, 50.01);
      expect(snapshot.savingsWithdrawalsTotal, 0.11);
      expect(snapshot.savingsBalance, 500.56);
      expect(snapshot.openingSavingsBalance, 450.66);
      expect(snapshot.availableBalance, 750.8);
    });

    test('calculateBudgetSnapshot keeps projected and daily values normalized', () {
      final snapshot = calculateBudgetSnapshot(
        incomeTotal: 1000.505,
        upcomingBillsAmount: 999.99,
        spendingAmount: 0.1 + 0.2,
        remainingDays: 5,
        availableBalance: 1000.50,
        savingsBalance: 500.555,
        settledBillsAmount: 12.345,
        savingsContributionsAmount: 1.005,
        savingsWithdrawalsAmount: 0.205,
      );

      expect(snapshot.incomeTotal, 1000.51);
      expect(snapshot.spendingAmount, 0.3);
      expect(snapshot.availableBalance, 1000.5);
      expect(snapshot.projectedAvailableBalance, 0.51);
      expect(snapshot.autoDailySpendingLimit, 0.1);
      expect(snapshot.dailySpendingLimit, 0.1);
      expect(snapshot.savingsBalance, 500.56);
      expect(snapshot.settledBillsAmount, 12.35);
      expect(snapshot.savingsContributionsAmount, 1.01);
      expect(snapshot.savingsWithdrawalsAmount, 0.21);
    });

    test('negative projected balances stay finite and manual budget safety fails closed', () {
      final snapshot = calculateBudgetSnapshot(
        incomeTotal: 100,
        upcomingBillsAmount: 1000.50,
        spendingAmount: 10.10,
        remainingDays: 3,
        availableBalance: 100.00,
        savingsBalance: 0,
        useManualDailyBudget: true,
        manualDailyBudget: 1,
      );

      expect(snapshot.projectedAvailableBalance, -900.5);
      expect(snapshot.autoDailySpendingLimit, -300.17);
      expect(snapshot.isManualDailyBudgetSafe, isFalse);
      expect(snapshot.dailySpendingLimit, 1.0);
    });
  });

  group('money-safe persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('stored money values are normalized without breaking saved doubles', () async {
      await FinanceRepository.setStartingBalance(1000.505);
      await FinanceRepository.setSavingsGoal(999.999);
      await FinanceRepository.setSavingsSaved(500.555);

      expect(await FinanceRepository.getStartingBalance(), 1000.51);
      expect(await FinanceRepository.getSavingsGoal(), 1000.0);
      expect(await FinanceRepository.getSavingsSaved(), 500.56);
    });

    test('model deserialization clamps invalid money payloads safely', () {
      final expense = ExpenseItem.fromMap(<String, dynamic>{
        'id': 'expense-a',
        'title': 'Bad payload',
        'amount': double.nan,
        'category': 'Other',
        'paymentMethod': 'Cash',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      });

      final income = IncomeEntry.fromMap(<String, dynamic>{
        'id': 'income-a',
        'amount': double.infinity,
        'receivedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'note': 'Bad payload',
      });

      expect(expense.amount, 0.0);
      expect(income.amount, 0.0);
    });
  });
}
