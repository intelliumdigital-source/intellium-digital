import 'dart:convert';

import 'package:finance_tracker/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/finance_test_builders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('FinanceRepository legacy salary migration', () {
    test('loadIncomeEntries migrates a legacy salary seed into one income entry', () async {
      final receivedAt = testDate(2024, 6, 15);
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppKeys.salary: 12500.0,
        AppKeys.salaryReceivedDate: receivedAt.toIso8601String(),
      });

      final entries = await FinanceRepository.loadIncomeEntries();
      final prefs = await SharedPreferences.getInstance();

      expect(entries, hasLength(1));
      expect(entries.single.id, startsWith('legacy-'));
      expect(entries.single.amount, 12500);
      expect(dateOnly(entries.single.receivedAt), dateOnly(receivedAt));
      expect(entries.single.note, 'Legacy salary import');
      expect(prefs.getBool(AppKeys.legacySalaryMigratedToIncome), isTrue);
      expect(prefs.getStringList(AppKeys.incomeEntries), hasLength(1));
    });

    test('loadIncomeEntries does not duplicate the migrated salary entry on later loads', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppKeys.salary: 9000.0,
        AppKeys.salaryReceivedDate: testDate(2024, 6, 1).toIso8601String(),
      });

      final firstLoad = await FinanceRepository.loadIncomeEntries();
      final secondLoad = await FinanceRepository.loadIncomeEntries();

      expect(firstLoad, hasLength(1));
      expect(secondLoad, hasLength(1));
      expect(secondLoad.single.amount, firstLoad.single.amount);
      expect(secondLoad.single.note, firstLoad.single.note);
    });

    test('loadIncomeEntries preserves existing income entries instead of creating a legacy import', () async {
      final existingEntry = buildIncomeEntry(
        id: 'income-existing',
        amount: 3200,
        receivedAt: testDate(2024, 6, 20),
        note: 'Existing income',
      );

      SharedPreferences.setMockInitialValues(<String, Object>{
        AppKeys.salary: 9000.0,
        AppKeys.salaryReceivedDate: testDate(2024, 6, 1).toIso8601String(),
        AppKeys.incomeEntries: <String>[
          jsonEncode(existingEntry.toMap()),
        ],
      });

      final entries = await FinanceRepository.loadIncomeEntries();
      final prefs = await SharedPreferences.getInstance();

      expect(entries, hasLength(1));
      expect(entries.single.id, 'income-existing');
      expect(entries.single.amount, 3200);
      expect(entries.single.note, 'Existing income');
      expect(prefs.getBool(AppKeys.legacySalaryMigratedToIncome), isTrue);
    });
  });
}
