import 'dart:math';

import 'package:finance_tracker/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/finance_test_builders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('calculateRemainingSweldoDays', () {
    test('uses the explicit payday difference when a future payday is provided', () {
      final result = calculateRemainingSweldoDays(
        nextPaydayDate: testDate(2024, 6, 20),
        fallbackDaysUntilPayday: 99,
        referenceDate: testDate(2024, 6, 15),
      );

      expect(result, 5);
    });

    test('clamps past payday dates to zero', () {
      final result = calculateRemainingSweldoDays(
        nextPaydayDate: testDate(2024, 6, 10),
        fallbackDaysUntilPayday: 99,
        referenceDate: testDate(2024, 6, 15),
      );

      expect(result, 0);
    });

    test('falls back to the stored remaining days when no payday date exists', () {
      final result = calculateRemainingSweldoDays(
        nextPaydayDate: null,
        fallbackDaysUntilPayday: 4,
        referenceDate: testDate(2024, 6, 15),
      );

      expect(result, 4);
    });
  });

  group('filterExpensesForActiveCycle', () {
    test('includes only expenses inside the active cutoff window', () {
      final today = dateOnly(DateTime.now());
      final cycleStart = today.subtract(const Duration(days: 7));
      final nextCutoff = today.add(const Duration(days: 3));

      final expenses = <ExpenseItem>[
        buildExpenseItem(
          id: 'before-cycle',
          amount: 10,
          createdAt: cycleStart.subtract(const Duration(days: 1)),
        ),
        buildExpenseItem(
          id: 'in-cycle',
          amount: 20,
          createdAt: today.subtract(const Duration(days: 1)),
        ),
        buildExpenseItem(
          id: 'on-cutoff',
          amount: 30,
          createdAt: nextCutoff,
        ),
      ];

      final result = filterExpensesForActiveCycle(
        expenses,
        cycleStartDate: cycleStart,
        nextCutoffDate: nextCutoff,
      );

      expect(result.map((item) => item.id).toList(), ['in-cycle']);
    });

    test('ignores a future cycle start instead of dropping current expenses', () {
      final today = dateOnly(DateTime.now());

      final expenses = <ExpenseItem>[
        buildExpenseItem(
          id: 'current',
          amount: 20,
          createdAt: today.subtract(const Duration(days: 1)),
        ),
        buildExpenseItem(
          id: 'older',
          amount: 30,
          createdAt: today.subtract(const Duration(days: 20)),
        ),
      ];

      final result = filterExpensesForActiveCycle(
        expenses,
        cycleStartDate: today.add(const Duration(days: 2)),
        nextCutoffDate: today.add(const Duration(days: 10)),
      );

      expect(result.map((item) => item.id).toList(), ['current', 'older']);
    });
  });

  group('bill budgeting', () {
    test('billCountsTowardBudgetCycle excludes paid bills first', () {
      final result = billCountsTowardBudgetCycle(
        buildBillItem(
          isPaid: true,
          paidDate: testDate(2024, 6, 10),
        ),
        cycleEndExclusive: testDate(2024, 6, 20),
      );

      expect(result, isFalse);
    });

    test('billCountsTowardBudgetCycle always includes unpaid recurring bills', () {
      final result = billCountsTowardBudgetCycle(
        buildBillItem(
          isRecurring: true,
          dueDate: testDate(2024, 1, 31),
        ),
        cycleEndExclusive: testDate(2024, 1, 10),
      );

      expect(result, isTrue);
    });

    test('billCountsTowardBudgetCycle uses an exclusive cutoff for one-time bills', () {
      final beforeCutoff = billCountsTowardBudgetCycle(
        buildBillItem(dueDate: testDate(2024, 6, 19)),
        cycleEndExclusive: testDate(2024, 6, 20),
      );
      final onCutoff = billCountsTowardBudgetCycle(
        buildBillItem(dueDate: testDate(2024, 6, 20)),
        cycleEndExclusive: testDate(2024, 6, 20),
      );

      expect(beforeCutoff, isTrue);
      expect(onCutoff, isFalse);
    });

    test('calculateUnpaidBillsForBudget includes recurring and in-window unpaid bills only', () {
      final total = calculateUnpaidBillsForBudget(
        bills: <BillItem>[
          buildBillItem(
            id: 'recurring',
            amount: 30,
            isRecurring: true,
            dueDate: testDate(2024, 1, 31),
          ),
          buildBillItem(
            id: 'due-soon',
            amount: 40,
            dueDate: testDate(2024, 6, 18),
          ),
          buildBillItem(
            id: 'after-cutoff',
            amount: 50,
            dueDate: testDate(2024, 6, 25),
          ),
          buildBillItem(
            id: 'already-paid',
            amount: 60,
            isPaid: true,
            paidDate: testDate(2024, 6, 10),
          ),
        ],
        cycleStartDate: testDate(2024, 6, 1),
        nextCutoffDate: testDate(2024, 6, 20),
      );

      expect(total, 70);
    });
  });

  group('calculateBalanceLedgerSnapshot', () {
    test('tracks income, paid bills, spending, and savings transfers in the ledger', () {
      final snapshot = calculateBalanceLedgerSnapshot(
        startingBalance: 1000,
        incomeEntries: <IncomeEntry>[
          buildIncomeEntry(amount: 200, receivedAt: testDate(2024, 6, 5)),
        ],
        bills: <BillItem>[
          buildBillItem(
            amount: 50,
            isPaid: true,
            paidDate: testDate(2024, 6, 8),
          ),
          buildBillItem(
            amount: 70,
            dueDate: testDate(2024, 6, 20),
          ),
        ],
        expenses: <ExpenseItem>[
          buildExpenseItem(amount: 100, createdAt: testDate(2024, 6, 9)),
        ],
        savingsBalance: 150,
        savingsHistory: <SavingsContributionEntry>[
          buildSavingsContributionEntry(
            amount: 80,
            createdAt: testDate(2024, 6, 3),
          ),
          buildSavingsContributionEntry(
            amount: 20,
            createdAt: testDate(2024, 6, 4),
            type: SavingsTransferType.withdrawal,
          ),
        ],
      );

      expect(snapshot.totalIncome, 200);
      expect(snapshot.settledBillsTotal, 50);
      expect(snapshot.upcomingBillsTotal, 70);
      expect(snapshot.totalSpending, 100);
      expect(snapshot.savingsContributionsTotal, 80);
      expect(snapshot.savingsWithdrawalsTotal, 20);
      expect(snapshot.openingSavingsBalance, 90);
      expect(snapshot.availableBalance, 990);
      expect(snapshot.savingsBalance, 150);
    });

    test('income entries increase available balance', () {
      final snapshot = calculateBalanceLedgerSnapshot(
        startingBalance: 200,
        incomeEntries: <IncomeEntry>[
          buildIncomeEntry(amount: 75),
          buildIncomeEntry(amount: 25),
        ],
        bills: const <BillItem>[],
        expenses: const <ExpenseItem>[],
        savingsBalance: 0,
        savingsHistory: const <SavingsContributionEntry>[],
      );

      expect(snapshot.availableBalance, 300);
    });

    test('paid bills reduce available balance while unpaid bills do not', () {
      final snapshot = calculateBalanceLedgerSnapshot(
        startingBalance: 200,
        incomeEntries: const <IncomeEntry>[],
        bills: <BillItem>[
          buildBillItem(amount: 40, isPaid: true, paidDate: testDate(2024, 6, 5)),
          buildBillItem(amount: 60, dueDate: testDate(2024, 6, 20)),
        ],
        expenses: const <ExpenseItem>[],
        savingsBalance: 0,
        savingsHistory: const <SavingsContributionEntry>[],
      );

      expect(snapshot.availableBalance, 160);
      expect(snapshot.upcomingBillsTotal, 60);
    });
  });

  group('calculateBudgetSnapshot', () {
    test('keeps a safe manual daily budget when it fits the projected pace', () {
      final snapshot = calculateBudgetSnapshot(
        incomeTotal: 0,
        upcomingBillsAmount: 100,
        spendingAmount: 50,
        remainingDays: 4,
        availableBalance: 500,
        savingsBalance: 0,
        useManualDailyBudget: true,
        manualDailyBudget: 90,
      );

      expect(snapshot.projectedAvailableBalance, 400);
      expect(snapshot.autoDailySpendingLimit, 100);
      expect(snapshot.usesManualDailyBudget, isTrue);
      expect(snapshot.isManualDailyBudgetSafe, isTrue);
      expect(snapshot.dailySpendingLimit, 90);
    });

    test('flags an unsafe manual daily budget when it exceeds the safe pace', () {
      final snapshot = calculateBudgetSnapshot(
        incomeTotal: 0,
        upcomingBillsAmount: 100,
        spendingAmount: 50,
        remainingDays: 4,
        availableBalance: 500,
        savingsBalance: 0,
        useManualDailyBudget: true,
        manualDailyBudget: 150,
      );

      expect(snapshot.projectedAvailableBalance, 400);
      expect(snapshot.autoDailySpendingLimit, 100);
      expect(snapshot.usesManualDailyBudget, isTrue);
      expect(snapshot.isManualDailyBudgetSafe, isFalse);
      expect(snapshot.dailySpendingLimit, 150);
    });

    test('handles negative projected balances without masking the deficit', () {
      final snapshot = calculateBudgetSnapshot(
        incomeTotal: 0,
        upcomingBillsAmount: 250,
        spendingAmount: 0,
        remainingDays: 3,
        availableBalance: 100,
        savingsBalance: 0,
        useManualDailyBudget: true,
        manualDailyBudget: 1,
      );

      expect(snapshot.projectedAvailableBalance, -150);
      expect(snapshot.autoDailySpendingLimit, closeTo(-50, 0.000001));
      expect(snapshot.isManualDailyBudgetSafe, isFalse);
      expect(snapshot.dailySpendingLimit, 1);
    });

    test('falls back to projected balance directly when no days remain', () {
      final snapshot = calculateBudgetSnapshot(
        incomeTotal: 0,
        upcomingBillsAmount: 80,
        spendingAmount: 0,
        remainingDays: 0,
        availableBalance: 200,
        savingsBalance: 0,
      );

      expect(snapshot.projectedAvailableBalance, 120);
      expect(snapshot.autoDailySpendingLimit, 120);
      expect(snapshot.dailySpendingLimit, 120);
    });
  });

  group('recalculateBudget', () {
    test('builds an integrated budget overview from expenses, bills, income, and savings', () {
      final today = dateOnly(DateTime.now());
      final cycleStart = today.subtract(const Duration(days: 7));
      final nextCutoff = today.add(const Duration(days: 3));

      final overview = recalculateBudget(
        startingBalance: 200,
        incomeEntries: <IncomeEntry>[
          buildIncomeEntry(
            amount: 100,
            receivedAt: today.subtract(const Duration(days: 5)),
          ),
        ],
        savingsBalance: 50,
        savingsHistory: <SavingsContributionEntry>[
          buildSavingsContributionEntry(
            amount: 15,
            createdAt: today.subtract(const Duration(days: 2)),
          ),
          buildSavingsContributionEntry(
            amount: 5,
            createdAt: today.subtract(const Duration(days: 1)),
            type: SavingsTransferType.withdrawal,
          ),
        ],
        bills: <BillItem>[
          buildBillItem(
            amount: 40,
            isPaid: true,
            paidDate: today.subtract(const Duration(days: 3)),
            dueDate: today.subtract(const Duration(days: 3)),
          ),
          buildBillItem(
            amount: 60,
            dueDate: today.add(const Duration(days: 1)),
          ),
        ],
        expenses: <ExpenseItem>[
          buildExpenseItem(
            id: 'old-expense',
            amount: 20,
            createdAt: today.subtract(const Duration(days: 20)),
          ),
          buildExpenseItem(
            id: 'active-expense',
            amount: 30,
            createdAt: today.subtract(const Duration(days: 1)),
          ),
        ],
        cycleStartDate: cycleStart,
        nextCutoffDate: nextCutoff,
        fallbackDaysUntilCutoff: 99,
      );

      expect(
        overview.activeCycleExpenses.map((item) => item.id).toList(),
        ['active-expense'],
      );
      expect(overview.snapshot.spendingAmount, 30);
      expect(overview.snapshot.upcomingBillsAmount, 70);
      expect(overview.snapshot.availableBalance, 200);
      expect(overview.snapshot.projectedAvailableBalance, 130);
      expect(overview.snapshot.remainingDays, 3);
      expect(overview.snapshot.settledBillsAmount, 40);
      expect(overview.snapshot.savingsContributionsAmount, 15);
      expect(overview.snapshot.savingsWithdrawalsAmount, 5);
      expect(overview.snapshot.dailySpendingLimit, closeTo(130 / 3, 0.000001));
    });

    test('keeps unpaid bills out of available balance and only subtracts them from projected balance', () {
      final today = dateOnly(DateTime.now());

      final overview = recalculateBudget(
        startingBalance: 200,
        incomeEntries: const <IncomeEntry>[],
        savingsBalance: 0,
        savingsHistory: const <SavingsContributionEntry>[],
        bills: <BillItem>[
          buildBillItem(amount: 60, dueDate: today.add(const Duration(days: 1))),
        ],
        expenses: const <ExpenseItem>[],
        cycleStartDate: today.subtract(const Duration(days: 1)),
        nextCutoffDate: today.add(const Duration(days: 3)),
        fallbackDaysUntilCutoff: 99,
      );

      expect(overview.snapshot.availableBalance, 200);
      expect(overview.snapshot.projectedAvailableBalance, 140);
    });
  });

  group('savings transfer behavior', () {
    test('reports contribution and withdrawal balance effects correctly', () {
      final contribution = buildSavingsContributionEntry(amount: 80);
      final withdrawal = buildSavingsContributionEntry(
        amount: 25,
        type: SavingsTransferType.withdrawal,
      );

      expect(contribution.isContribution, isTrue);
      expect(contribution.isWithdrawal, isFalse);
      expect(contribution.savingsBalanceEffect, 80);
      expect(contribution.availableBalanceEffect, -80);
      expect(contribution.label, 'Add to Savings');

      expect(withdrawal.isContribution, isFalse);
      expect(withdrawal.isWithdrawal, isTrue);
      expect(withdrawal.savingsBalanceEffect, -25);
      expect(withdrawal.availableBalanceEffect, 25);
      expect(withdrawal.label, 'Withdraw from Savings');
    });
  });

  group('recurring bill due-date behavior', () {
    test('parseBillDueDateValue anchors recurring "Every 31" dates to the current month', () {
      final now = DateTime.now();
      final expected = DateTime(
        now.year,
        now.month,
        min(31, DateTime(now.year, now.month + 1, 0).day),
      );

      final actual = parseBillDueDateValue('Every 31', isRecurring: true);

      expect(actual, expected);
    });

    test('resolveUpcomingBillDate returns the next valid recurring due date', () {
      final now = DateTime.now();
      final today = dateOnly(now);
      var year = now.year;
      var month = now.month;
      var safeDay = min(31, DateTime(year, month + 1, 0).day);
      var expected = DateTime(year, month, safeDay);

      if (expected.isBefore(today)) {
        month++;
        if (month > 12) {
          month = 1;
          year++;
        }
        safeDay = min(31, DateTime(year, month + 1, 0).day);
        expected = DateTime(year, month, safeDay);
      }

      final actual = resolveUpcomingBillDate(
        buildBillItem(
          dueDate: testDate(2024, 1, 31),
          isRecurring: true,
        ),
      );

      expect(actual, expected);
      expect(actual, isNotNull);
      expect(actual!.isBefore(today), isFalse);
    });
  });
}
