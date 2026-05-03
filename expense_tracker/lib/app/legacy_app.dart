import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -----------------------------------------------------------------------------
// App bootstrap
// -----------------------------------------------------------------------------

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SweldoTrackApp());
}

// -----------------------------------------------------------------------------
// Finance pure helpers
// -----------------------------------------------------------------------------

String formatPhp(num amount, {int decimals = 0}) {
  return NumberFormat.currency(
    locale: 'en_PH',
    symbol: '\u20B1',
    decimalDigits: decimals,
  ).format(normalizeMoney(amount));
}

double normalizeMoney(
  num? value, {
  bool allowNegative = true,
}) {
  if (value == null) return 0.0;
  final doubleValue = value.toDouble();
  if (!doubleValue.isFinite || doubleValue.isNaN) {
    return 0.0;
  }

  final normalized = (doubleValue * 100).round() / 100;
  if (!allowNegative && normalized < 0) {
    return 0.0;
  }
  if (normalized == 0) {
    return 0.0;
  }
  return normalized;
}

double? normalizeOptionalMoney(
  num? value, {
  bool allowNegative = true,
}) {
  if (value == null) return null;
  return normalizeMoney(value, allowNegative: allowNegative);
}

double? parseMoneyInput(
  String? rawValue, {
  bool allowNegative = false,
}) {
  final trimmed = (rawValue ?? '').trim();
  if (trimmed.isEmpty) return null;

  final sanitized = trimmed
      .replaceAll(RegExp(r'[,\s]'), '')
      .replaceAll('\u20B1', '')
      .replaceAll(RegExp(r'php', caseSensitive: false), '');
  if (sanitized.isEmpty) return null;

  final parsed = double.tryParse(sanitized);
  if (parsed == null || !parsed.isFinite || parsed.isNaN) {
    return null;
  }
  if (!allowNegative && parsed < 0) {
    return null;
  }
  return normalizeMoney(parsed, allowNegative: allowNegative);
}

const double maxSupportedPesoAmount = 999999999.99;

String _sentenceCase(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
}

String? validatePesoAmountInput(
  String? rawValue, {
  required String fieldLabel,
  bool allowNegative = false,
  bool allowZero = false,
  double maxAmount = maxSupportedPesoAmount,
}) {
  final trimmed = (rawValue ?? '').trim();
  final title = _sentenceCase(fieldLabel);
  if (trimmed.isEmpty) {
    return 'Enter $fieldLabel';
  }

  final sanitized = trimmed
      .replaceAll(RegExp(r'[,\s]'), '')
      .replaceAll('\u20B1', '')
      .replaceAll(RegExp(r'php', caseSensitive: false), '');
  if (sanitized.isEmpty) {
    return 'Enter $fieldLabel';
  }

  final rawParsed = double.tryParse(sanitized);
  if (rawParsed == null || !rawParsed.isFinite || rawParsed.isNaN) {
    return 'Enter a valid $fieldLabel in pesos and centavos';
  }
  if (!allowNegative && rawParsed < 0) {
    return '$title cannot be negative';
  }
  final parsed = normalizeMoney(rawParsed, allowNegative: allowNegative);
  if (!allowZero && parsed <= 0) {
    return '$title must be greater than zero';
  }
  if (parsed.abs() > maxAmount + 0.001) {
    return '$title is too large. Enter an amount below ${formatPhp(maxAmount, decimals: 2)}.';
  }
  return null;
}

String formatCalendarDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String formatRecurringDay(int day) {
  return 'Every $day';
}

DateTime dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

Iterable<(DateTime, double)> _analyticsSpendingEntries(
  List<ExpenseItem> expenses, {
  List<BillItem> bills = const <BillItem>[],
}) sync* {
  // Analytics spending is expense-only. Bills stay separate in balance logic
  // so paid bills are never silently double-counted in charts or totals.
  for (final expense in expenses) {
    yield (dateOnly(expense.createdAt), expense.amount);
  }
}

double getTodayExpensesTotal(
  List<ExpenseItem> expenses, {
  List<BillItem> bills = const <BillItem>[],
}) {
  final today = dateOnly(DateTime.now());
  return _analyticsSpendingEntries(expenses, bills: bills)
      .where((entry) => entry.$1 == today)
      .fold<double>(0, (sum, entry) => sum + entry.$2);
}

double getCurrentMonthExpensesTotal(
  List<ExpenseItem> expenses, {
  List<BillItem> bills = const <BillItem>[],
}) {
  final now = dateOnly(DateTime.now());
  return _analyticsSpendingEntries(expenses, bills: bills)
      .where(
          (entry) => entry.$1.year == now.year && entry.$1.month == now.month)
      .fold<double>(0, (sum, entry) => sum + entry.$2);
}

double getCurrentYearExpensesTotal(
  List<ExpenseItem> expenses, {
  List<BillItem> bills = const <BillItem>[],
}) {
  final now = dateOnly(DateTime.now());
  return _analyticsSpendingEntries(expenses, bills: bills)
      .where((entry) => entry.$1.year == now.year)
      .fold<double>(0, (sum, entry) => sum + entry.$2);
}

List<double> getLast7DaysSpending(
  List<ExpenseItem> expenses, {
  List<BillItem> bills = const <BillItem>[],
}) {
  final today = dateOnly(DateTime.now());
  final start = today.subtract(const Duration(days: 6));
  final totals = List<double>.filled(7, 0);

  for (final entry in _analyticsSpendingEntries(expenses, bills: bills)) {
    final dayIndex = entry.$1.difference(start).inDays;
    if (dayIndex >= 0 && dayIndex < 7) {
      totals[dayIndex] += entry.$2;
    }
  }

  return totals;
}

List<double> getLast12MonthsSpending(
  List<ExpenseItem> expenses, {
  List<BillItem> bills = const <BillItem>[],
}) {
  final now = dateOnly(DateTime.now());
  final monthStarts = List.generate(
    12,
    (index) => DateTime(now.year, now.month - (11 - index), 1),
  );
  final totals = List<double>.filled(12, 0);

  for (final entry in _analyticsSpendingEntries(expenses, bills: bills)) {
    for (var index = 0; index < monthStarts.length; index++) {
      final monthStart = monthStarts[index];
      if (entry.$1.year == monthStart.year &&
          entry.$1.month == monthStart.month) {
        totals[index] += entry.$2;
        break;
      }
    }
  }

  return totals;
}

List<String> getLast12MonthLabels({DateTime? referenceDate}) {
  final now = dateOnly(referenceDate ?? DateTime.now());
  return List.generate(
    12,
    (index) => DateFormat('MMM').format(
      DateTime(now.year, now.month - (11 - index), 1),
    ),
  );
}

List<double> buildSevenDayExpenseTrend(List<ExpenseItem> expenses) {
  // Literal rolling 7-day trend based on calendar dates, independent of cutoff totals.
  final today = dateOnly(DateTime.now());
  final start = today.subtract(const Duration(days: 6));
  final totals = List<double>.filled(7, 0);

  for (final item in expenses) {
    final expenseDate = dateOnly(item.createdAt);
    final dayIndex = expenseDate.difference(start).inDays;
    if (dayIndex >= 0 && dayIndex < 7) {
      totals[dayIndex] += item.amount;
    }
  }

  return totals;
}

String shortWeekdayLabel(DateTime date) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return labels[date.weekday - 1];
}

String greetingForTime(DateTime dateTime) {
  final hour = dateTime.hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

String formatHeaderDate(DateTime dateTime) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${shortWeekdayLabel(dateTime)}, ${months[dateTime.month - 1]} ${dateTime.day}';
}

String formatHeaderTime(DateTime dateTime) {
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

const String _appInfoChannelName = 'sweldotrack/app_info';
const String _unknownAppVersionLabel = 'Version unavailable';
@Deprecated('Use AppInstallInfo.versionLabel instead.')
const String appVersionLabel = _unknownAppVersionLabel;
const Color intelliumBackground = Color(0xFF090B16);
const Color intelliumSurface = Color(0xFF111427);
const Color intelliumCard = Color(0xFF151A30);
const Color intelliumCyan = Color(0xFF64E8FF);
const Color intelliumBlue = Color(0xFF4A8DFF);
const Color intelliumPurple = Color(0xFF8B5CFF);
const Color intelliumPink = Color(0xFFD96CFF);
const Color intelliumTextPrimary = Color(0xFFF6F7FF);
const Color intelliumTextSecondary = Color(0xFFA9B1D6);
const Color intelliumTextMuted = Color(0xFF7F89B0);

class AppInstallInfo {
  final String versionName;
  final String buildNumber;

  const AppInstallInfo({
    required this.versionName,
    required this.buildNumber,
  });

  static const MethodChannel _channel = MethodChannel(_appInfoChannelName);
  static const AppInstallInfo unknown = AppInstallInfo(
    versionName: '',
    buildNumber: '',
  );

  String get versionLabel {
    if (versionName.isEmpty && buildNumber.isEmpty) {
      return _unknownAppVersionLabel;
    }
    if (buildNumber.isEmpty) {
      return 'Version $versionName';
    }
    if (versionName.isEmpty) {
      return 'Build $buildNumber';
    }
    return 'Version $versionName (Build $buildNumber)';
  }

  static Future<AppInstallInfo> load() async {
    if (kIsWeb) return unknown;

    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getAppVersion',
      );
      if (raw == null) return unknown;

      return AppInstallInfo(
        versionName: _readStoredString(raw['versionName']),
        buildNumber: _readStoredString(raw['buildNumber']),
      );
    } on PlatformException {
      return unknown;
    } catch (_) {
      return unknown;
    }
  }
}

enum SweldoThemePreset { emerald, jade, ocean, sunset }

class SweldoThemeDefinition {
  final SweldoThemePreset preset;
  final String label;
  final Color seedColor;
  final Color scaffoldColor;
  final Color surfaceColor;
  final Color inputColor;
  final List<Color> previewColors;

  const SweldoThemeDefinition({
    required this.preset,
    required this.label,
    required this.seedColor,
    required this.scaffoldColor,
    required this.surfaceColor,
    required this.inputColor,
    required this.previewColors,
  });
}

const List<SweldoThemeDefinition> sweldoThemeDefinitions = [
  SweldoThemeDefinition(
    preset: SweldoThemePreset.emerald,
    label: 'Emerald Dark',
    seedColor: Color(0xFF00C896),
    scaffoldColor: Color(0xFF0B0F1A),
    surfaceColor: Color(0xFF111827),
    inputColor: Color(0xFF0F172A),
    previewColors: [Color(0xFF00C896), Color(0xFF0B0F1A)],
  ),
  SweldoThemeDefinition(
    preset: SweldoThemePreset.jade,
    label: 'Jade Green',
    seedColor: Color(0xFF2EE6A6),
    scaffoldColor: Color(0xFF07110D),
    surfaceColor: Color(0xFF0C1B15),
    inputColor: Color(0xFF11261D),
    previewColors: [Color(0xFF2EE6A6), Color(0xFF07110D)],
  ),
  SweldoThemeDefinition(
    preset: SweldoThemePreset.ocean,
    label: 'Ocean Dark',
    seedColor: Color(0xFF3AA0FF),
    scaffoldColor: Color(0xFF08131F),
    surfaceColor: Color(0xFF102033),
    inputColor: Color(0xFF0D1A2B),
    previewColors: [Color(0xFF3AA0FF), Color(0xFF0F2742)],
  ),
  SweldoThemeDefinition(
    preset: SweldoThemePreset.sunset,
    label: 'Sunset Dark',
    seedColor: Color(0xFFFF8A5B),
    scaffoldColor: Color(0xFF161018),
    surfaceColor: Color(0xFF241724),
    inputColor: Color(0xFF201421),
    previewColors: [Color(0xFFFF8A5B), Color(0xFF592B4A)],
  ),
];

SweldoThemeDefinition sweldoThemeFor(SweldoThemePreset preset) {
  return sweldoThemeDefinitions.firstWhere(
    (theme) => theme.preset == preset,
    orElse: () => sweldoThemeDefinitions.first,
  );
}

bool isFreeSweldoTheme(SweldoThemePreset preset) {
  return preset == SweldoThemePreset.emerald ||
      preset == SweldoThemePreset.jade;
}

@immutable
class SweldoThemeMarker extends ThemeExtension<SweldoThemeMarker> {
  final SweldoThemePreset preset;

  const SweldoThemeMarker({required this.preset});

  @override
  SweldoThemeMarker copyWith({SweldoThemePreset? preset}) {
    return SweldoThemeMarker(preset: preset ?? this.preset);
  }

  @override
  SweldoThemeMarker lerp(
    covariant ThemeExtension<SweldoThemeMarker>? other,
    double t,
  ) {
    if (other is! SweldoThemeMarker) return this;
    return t < 0.5 ? this : other;
  }
}

class SweldoVisualStyle {
  final SweldoThemePreset preset;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color cardFill;
  final Color sectionFill;
  final Color borderColor;
  final Color shadowColor;
  final LinearGradient accentGradient;
  final LinearGradient analyticsAccentGradient;
  final LinearGradient premiumCtaGradient;

  const SweldoVisualStyle({
    required this.preset,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.cardFill,
    required this.sectionFill,
    required this.borderColor,
    required this.shadowColor,
    required this.accentGradient,
    required this.analyticsAccentGradient,
    required this.premiumCtaGradient,
  });

  bool get isJade => preset == SweldoThemePreset.jade;

  factory SweldoVisualStyle.fromContext(BuildContext context) {
    final marker = Theme.of(context).extension<SweldoThemeMarker>();
    final preset = marker?.preset ?? SweldoThemePreset.emerald;

    if (preset == SweldoThemePreset.jade) {
      return const SweldoVisualStyle(
        preset: SweldoThemePreset.jade,
        textPrimary: Color(0xFFF2FFF8),
        textSecondary: Color(0xFFCBEBDD),
        textMuted: Color(0xFF87A99A),
        cardFill: Color(0xCC0C1B15),
        sectionFill: Color(0xE6091611),
        borderColor: Color(0x332EE6A6),
        shadowColor: Color(0x442EE6A6),
        accentGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9DFFE0), Color(0xFF2EE6A6), Color(0xFF0F7D58)],
        ),
        analyticsAccentGradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB7FFE8), Color(0xFF45F5B6), Color(0xFF11855E)],
        ),
        premiumCtaGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF143A2C), Color(0xFF0D241B), Color(0xFF07120E)],
        ),
      );
    }

    return SweldoVisualStyle(
      preset: preset,
      textPrimary: intelliumTextPrimary,
      textSecondary: intelliumTextSecondary,
      textMuted: intelliumTextMuted,
      cardFill: intelliumCard,
      sectionFill: intelliumSurface,
      borderColor: const Color(0x0DFFFFFF),
      shadowColor: const Color(0x00000000),
      accentGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [intelliumCyan, intelliumBlue, intelliumPurple],
      ),
      analyticsAccentGradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [intelliumCyan, intelliumBlue, intelliumPurple],
      ),
      premiumCtaGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFC857), intelliumPink],
      ),
    );
  }

  BoxDecoration cardDecoration({double radius = 24}) {
    return BoxDecoration(
      color: isJade ? null : cardFill,
      gradient: isJade
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cardFill, const Color(0xB30A1511)],
            )
          : null,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor),
      boxShadow: isJade
          ? [
              BoxShadow(
                color: shadowColor.withValues(alpha: .18),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ]
          : null,
    );
  }

  BoxDecoration sectionContainerDecoration({double radius = 28}) {
    return BoxDecoration(
      color: isJade ? null : sectionFill,
      gradient: isJade
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [sectionFill, const Color(0xD107120E)],
            )
          : null,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor),
      boxShadow: isJade
          ? [
              BoxShadow(
                color: shadowColor.withValues(alpha: .12),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ]
          : null,
    );
  }

  BoxDecoration premiumCtaDecoration({double radius = 28}) {
    return BoxDecoration(
      gradient: isJade ? premiumCtaGradient : accentGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isJade
            ? const Color(0x552EE6A6)
            : Colors.white.withValues(alpha: .05),
      ),
      boxShadow: isJade
          ? [
              const BoxShadow(
                color: Color(0x662EE6A6),
                blurRadius: 30,
                spreadRadius: 1,
              ),
            ]
          : null,
    );
  }

  BoxDecoration iconChipBackground(Color color, {double radius = 16}) {
    return BoxDecoration(
      color: isJade ? null : color.withValues(alpha: .16),
      gradient: isJade
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: .28),
                const Color(0x992EE6A6),
              ],
            )
          : null,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: isJade
          ? [
              BoxShadow(
                color: color.withValues(alpha: .22),
                blurRadius: 16,
              ),
            ]
          : null,
    );
  }

  BoxDecoration analyticsDecoration({double radius = 28}) {
    return sectionContainerDecoration(radius: radius);
  }
}

ThemeData buildSweldoTheme(SweldoThemeDefinition theme) {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: theme.scaffoldColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: theme.seedColor,
      brightness: Brightness.dark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: theme.scaffoldColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: theme.surfaceColor,
      behavior: SnackBarBehavior.floating,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.seedColor,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: theme.seedColor),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: theme.inputColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: theme.seedColor),
      ),
      hintStyle: const TextStyle(color: Colors.white38),
      labelStyle: const TextStyle(color: Colors.white70),
    ),
    extensions: <ThemeExtension<dynamic>>[
      SweldoThemeMarker(preset: theme.preset),
    ],
  );
}

DateTime? parseStoredBillDate(String value) {
  final match = RegExp(r'^([A-Za-z]{3}) (\d{1,2}), (\d{4})$').firstMatch(value);
  if (match == null) return null;

  const monthMap = {
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12,
  };

  final month = monthMap[match.group(1)];
  final day = int.tryParse(match.group(2) ?? '');
  final year = int.tryParse(match.group(3) ?? '');
  if (month == null || day == null || year == null) return null;
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

DateTime _resolveRecurringBillAnchor(int day, {DateTime? referenceDate}) {
  final reference = dateOnly(referenceDate ?? DateTime.now());
  final safeDay = day.clamp(1, 31).toInt();
  final maxDay = DateTime(reference.year, reference.month + 1, 0).day;
  return DateTime(reference.year, reference.month, min(safeDay, maxDay));
}

DateTime _resolveRecurringBillMonthAnchor(
  int day, {
  required int year,
  required int month,
}) {
  final safeDay = day.clamp(1, 31).toInt();
  final maxDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, min(safeDay, maxDay));
}

String billCycleKey(DateTime dateTime) {
  final date = dateOnly(dateTime);
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
}

DateTime parseBillDueDateValue(dynamic value, {bool isRecurring = false}) {
  if (value is String) {
    final isoDate = parseStoredIsoDate(value);
    if (isoDate != null) {
      return dateOnly(isoDate);
    }

    if (isRecurring) {
      final match = RegExp(r'^Every (\d{1,2})$').firstMatch(value);
      final recurringDay = int.tryParse(match?.group(1) ?? '');
      if (recurringDay != null) {
        return _resolveRecurringBillAnchor(recurringDay);
      }
    }

    final formattedDate = parseStoredBillDate(value);
    if (formattedDate != null) {
      return dateOnly(formattedDate);
    }
  }

  return dateOnly(DateTime.now());
}

DateTime? resolveUpcomingBillDate(BillItem bill) {
  if (bill.isRecurring) {
    return billHasOutstandingBalance(bill)
        ? resolveCurrentRecurringBillDate(bill)
        : resolveNextRecurringBillDate(bill);
  }

  return dateOnly(bill.dueDate);
}

DateTime resolveCurrentRecurringBillDate(
  BillItem bill, {
  DateTime? referenceDate,
}) {
  final reference = dateOnly(referenceDate ?? DateTime.now());
  return _resolveRecurringBillMonthAnchor(
    bill.dueDate.day,
    year: reference.year,
    month: reference.month,
  );
}

DateTime resolveNextRecurringBillDate(
  BillItem bill, {
  DateTime? referenceDate,
}) {
  final reference = dateOnly(referenceDate ?? DateTime.now());
  var year = reference.year;
  var month = reference.month + 1;
  if (month > 12) {
    month = 1;
    year++;
  }
  return _resolveRecurringBillMonthAnchor(
    bill.dueDate.day,
    year: year,
    month: month,
  );
}

String resolveBillCurrentCycleKey(
  BillItem bill, {
  DateTime? referenceDate,
}) {
  if (!bill.isRecurring) {
    return billCycleKey(bill.dueDate);
  }
  return billCycleKey(
    resolveCurrentRecurringBillDate(
      bill,
      referenceDate: referenceDate,
    ),
  );
}

bool isBillSettledForCurrentCycle(
  BillItem bill, {
  DateTime? referenceDate,
}) {
  if (!bill.isRecurring) {
    return bill.isPaid;
  }
  if (!bill.isPaid) return false;

  final settledCycleKey = bill.settledCycleKey?.trim();
  final currentCycleKey = resolveBillCurrentCycleKey(
    bill,
    referenceDate: referenceDate,
  );
  if (settledCycleKey != null && settledCycleKey.isNotEmpty) {
    return settledCycleKey == currentCycleKey;
  }

  final paidDate = bill.paidDate;
  if (paidDate == null) return false;
  return billCycleKey(paidDate) == currentCycleKey;
}

bool billHasOutstandingBalance(
  BillItem bill, {
  DateTime? referenceDate,
}) {
  if (bill.isRecurring) {
    return !isBillSettledForCurrentCycle(
      bill,
      referenceDate: referenceDate,
    );
  }
  return !bill.isPaid;
}

String formatMonthDay(DateTime dateTime) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[dateTime.month - 1]} ${dateTime.day}';
}

DateTime? parseStoredIsoDate(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) return null;
  return DateTime.tryParse(normalized);
}

DateTime? _readStoredDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return parseStoredIsoDate(value);
  return null;
}

String _readStoredString(dynamic value, {String fallback = ''}) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return fallback;
}

bool _readStoredBool(dynamic value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return fallback;
}

int _readStoredInt(dynamic value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

double _readStoredMoney(dynamic value, {bool allowNegative = true}) {
  if (value is num) {
    return normalizeMoney(value, allowNegative: allowNegative);
  }
  if (value is String) {
    return parseMoneyInput(value, allowNegative: allowNegative) ?? 0;
  }
  return 0;
}

String _buildStableFallbackId(String prefix, Iterable<Object?> parts) {
  final normalized = parts
      .map((part) => '${part ?? ''}'.trim())
      .where((part) => part.isNotEmpty)
      .join('|');
  if (normalized.isEmpty) {
    return '$prefix-missing';
  }
  return '$prefix-${normalized.hashCode.abs()}';
}

int calculateRemainingSweldoDays({
  DateTime? nextPaydayDate,
  required int fallbackDaysUntilPayday,
  DateTime? referenceDate,
}) {
  final today = dateOnly(referenceDate ?? DateTime.now());
  if (nextPaydayDate != null) {
    final payday = dateOnly(nextPaydayDate);
    final difference = payday.difference(today).inDays;
    return max(0, difference);
  }
  return max(0, fallbackDaysUntilPayday);
}

class DailyBudgetSettings {
  final bool useManualDailyBudget;
  final double? manualDailyBudget;

  const DailyBudgetSettings({
    required this.useManualDailyBudget,
    this.manualDailyBudget,
  });
}

class BudgetSnapshot {
  final double upcomingBillsAmount;
  final double spendingAmount;
  final int remainingDays;
  final double incomeTotal;
  final double projectedAvailableBalance;
  final double availableBalance;
  final double savingsBalance;
  final double settledBillsAmount;
  final double savingsContributionsAmount;
  final double savingsWithdrawalsAmount;
  final double autoDailySpendingLimit;
  final double? manualDailyBudget;
  final bool usesManualDailyBudget;
  final bool isManualDailyBudgetSafe;
  final double dailySpendingLimit;

  const BudgetSnapshot({
    required this.upcomingBillsAmount,
    required this.spendingAmount,
    required this.remainingDays,
    required this.incomeTotal,
    required this.projectedAvailableBalance,
    required this.availableBalance,
    required this.savingsBalance,
    required this.settledBillsAmount,
    required this.savingsContributionsAmount,
    required this.savingsWithdrawalsAmount,
    required this.autoDailySpendingLimit,
    required this.manualDailyBudget,
    required this.usesManualDailyBudget,
    required this.isManualDailyBudgetSafe,
    required this.dailySpendingLimit,
  });

  double get totalBills => upcomingBillsAmount;
  double get totalIncomeAdded => incomeTotal;
  double get projectedBalance => projectedAvailableBalance;
  double get totalLoggedExpenses => spendingAmount;

  double get plannedBillsAmount => upcomingBillsAmount;
  double get savingsTransfersAmount =>
      savingsContributionsAmount - savingsWithdrawalsAmount;
  double get expensesAmount => spendingAmount;
  double get projectedBalanceAfterBills => projectedAvailableBalance;
  double get currentBalance => availableBalance;
  double get paidBillsAmount => settledBillsAmount;
  double get unpaidBillsAmount => upcomingBillsAmount;
  double get autoDailyBudget => autoDailySpendingLimit;
  double get dailyBudget => dailySpendingLimit;

  // Legacy compatibility aliases. Do not use in new UI.
  @Deprecated('Use totalIncomeAdded instead.')
  double get spendableSweldo => incomeTotal;

  @Deprecated('Use projectedBalance instead.')
  double get remainingBalance => projectedAvailableBalance;

  @Deprecated('Use availableBalance instead.')
  double get currentMoney => availableBalance;
}

class BalanceLedgerSnapshot {
  final double openingAvailableBalance;
  final double openingSavingsBalance;
  final double totalIncome;
  final double settledBillsTotal;
  final double upcomingBillsTotal;
  final double totalSpending;
  final double savingsContributionsTotal;
  final double savingsWithdrawalsTotal;
  final double availableBalance;
  final double savingsBalance;

  const BalanceLedgerSnapshot({
    required this.openingAvailableBalance,
    required this.openingSavingsBalance,
    required this.totalIncome,
    required this.settledBillsTotal,
    required this.upcomingBillsTotal,
    required this.totalSpending,
    required this.savingsContributionsTotal,
    required this.savingsWithdrawalsTotal,
    required this.availableBalance,
    required this.savingsBalance,
  });

  double get startingBalance => openingAvailableBalance;
  double get paidBillsTotal => settledBillsTotal;
  double get unpaidBillsTotal => upcomingBillsTotal;
  double get totalExpenses => totalSpending;
  double get savingsTransfersTotal =>
      savingsContributionsTotal - savingsWithdrawalsTotal;
  double get currentBalance => availableBalance;
}

class BudgetOverview {
  final BudgetSnapshot snapshot;
  final List<ExpenseItem> activeCycleExpenses;

  const BudgetOverview({
    required this.snapshot,
    required this.activeCycleExpenses,
  });
}

class BudgetCycleWindow {
  final DateTime? startInclusive;
  final DateTime? endExclusive;

  const BudgetCycleWindow({
    this.startInclusive,
    this.endExclusive,
  });
}

BudgetCycleWindow resolveBudgetCycleWindow({
  DateTime? cycleStartDate,
  DateTime? nextCutoffDate,
}) {
  final start = cycleStartDate == null ? null : dateOnly(cycleStartDate);
  final cutoff = nextCutoffDate == null ? null : dateOnly(nextCutoffDate);

  if (start == null) {
    // Without a known cycle start, avoid using a stale cutoff date to drop
    // recent expenses from the active-cycle totals.
    return const BudgetCycleWindow();
  }

  if (cutoff == null || !cutoff.isAfter(start)) {
    return BudgetCycleWindow(startInclusive: start);
  }

  return BudgetCycleWindow(
    startInclusive: start,
    endExclusive: cutoff,
  );
}

DateTime? resolveBudgetCycleEndExclusive({
  DateTime? cycleStartDate,
  DateTime? nextCutoffDate,
}) {
  final cutoff = nextCutoffDate == null ? null : dateOnly(nextCutoffDate);
  final start = cycleStartDate == null ? null : dateOnly(cycleStartDate);

  if (cutoff == null) return null;
  if (start != null && !cutoff.isAfter(start)) {
    return null;
  }
  return cutoff;
}

List<ExpenseItem> filterExpensesForActiveCycle(
  List<ExpenseItem> expenses, {
  DateTime? cycleStartDate,
  DateTime? nextCutoffDate,
}) {
  final today = dateOnly(DateTime.now());
  final effectiveCycleStartDate =
      cycleStartDate != null && dateOnly(cycleStartDate).isAfter(today)
          ? null
          : cycleStartDate;
  final effectiveNextCutoffDate =
      nextCutoffDate != null && !dateOnly(nextCutoffDate).isAfter(today)
          ? null
          : nextCutoffDate;

  final cycleWindow = resolveBudgetCycleWindow(
    cycleStartDate: effectiveCycleStartDate,
    nextCutoffDate: effectiveNextCutoffDate,
  );

  return expenses.where((item) {
    final expenseDate = dateOnly(item.createdAt);
    final matchesStart = cycleWindow.startInclusive == null ||
        !expenseDate.isBefore(cycleWindow.startInclusive!);
    final matchesEnd = cycleWindow.endExclusive == null ||
        expenseDate.isBefore(cycleWindow.endExclusive!);
    return matchesStart && matchesEnd;
  }).toList();
}

double calculateBudgetBillsAmount({
  required List<BillItem> bills,
  required DateTime? cycleStartDate,
  required DateTime? nextCutoffDate,
}) {
  return calculateUnpaidBillsForBudget(
    bills: bills,
    cycleStartDate: cycleStartDate,
    nextCutoffDate: nextCutoffDate,
  );
}

double calculateUnpaidBillsForBudget({
  required List<BillItem> bills,
  required DateTime? cycleStartDate,
  required DateTime? nextCutoffDate,
}) {
  final scopedBills = filterBillsForBudgetCycle(
    bills: bills,
    cycleStartDate: cycleStartDate,
    nextCutoffDate: nextCutoffDate,
  );
  return normalizeMoney(
    scopedBills.fold<double>(0, (sum, item) => sum + item.amount),
  );
}

List<BillItem> filterBillsForBudgetCycle({
  required List<BillItem> bills,
  required DateTime? cycleStartDate,
  required DateTime? nextCutoffDate,
}) {
  final cycleEndExclusive = resolveBudgetCycleEndExclusive(
    cycleStartDate: cycleStartDate,
    nextCutoffDate: nextCutoffDate,
  );

  return bills
      .where(
        (item) => billCountsTowardBudgetCycle(
          item,
          cycleEndExclusive: cycleEndExclusive,
        ),
      )
      .toList();
}

bool billCountsTowardBudgetCycle(
  BillItem bill, {
  DateTime? cycleEndExclusive,
}) {
  if (!billHasOutstandingBalance(bill)) return false;

  final dueDate = dateOnly(resolveUpcomingBillDate(bill) ?? bill.dueDate);
  if (cycleEndExclusive == null) {
    return true;
  }

  return dueDate.isBefore(cycleEndExclusive);
}

BudgetOverview recalculateBudget({
  required double startingBalance,
  required List<IncomeEntry> incomeEntries,
  required double savingsBalance,
  required List<SavingsContributionEntry> savingsHistory,
  required List<BillItem> bills,
  required List<ExpenseItem> expenses,
  required DateTime? cycleStartDate,
  required DateTime? nextCutoffDate,
  required int fallbackDaysUntilCutoff,
  bool useManualDailyBudget = false,
  double? manualDailyBudget,
}) {
  final activeCycleExpenses = filterExpensesForActiveCycle(
    expenses,
    cycleStartDate: cycleStartDate,
    nextCutoffDate: nextCutoffDate,
  );
  final totalBills = calculateBudgetBillsAmount(
    bills: bills,
    cycleStartDate: cycleStartDate,
    nextCutoffDate: nextCutoffDate,
  );
  final totalLoggedExpenses =
      activeCycleExpenses.fold<double>(0, (sum, item) => sum + item.amount);
  final remainingDays = calculateRemainingSweldoDays(
    nextPaydayDate: nextCutoffDate,
    fallbackDaysUntilPayday: fallbackDaysUntilCutoff,
  );
  final ledger = calculateBalanceLedgerSnapshot(
    startingBalance: startingBalance,
    incomeEntries: incomeEntries,
    bills: bills,
    expenses: expenses,
    savingsBalance: savingsBalance,
    savingsHistory: savingsHistory,
  );

  return BudgetOverview(
    snapshot: calculateBudgetSnapshot(
      incomeTotal: ledger.totalIncome,
      upcomingBillsAmount: totalBills,
      spendingAmount: totalLoggedExpenses,
      remainingDays: remainingDays,
      availableBalance: ledger.availableBalance,
      savingsBalance: ledger.savingsBalance,
      settledBillsAmount: ledger.settledBillsTotal,
      savingsContributionsAmount: ledger.savingsContributionsTotal,
      savingsWithdrawalsAmount: ledger.savingsWithdrawalsTotal,
      useManualDailyBudget: useManualDailyBudget,
      manualDailyBudget: manualDailyBudget,
    ),
    activeCycleExpenses: activeCycleExpenses,
  );
}

BalanceLedgerSnapshot calculateBalanceLedgerSnapshot({
  required double startingBalance,
  required List<IncomeEntry> incomeEntries,
  required List<BillItem> bills,
  required List<ExpenseItem> expenses,
  required double savingsBalance,
  required List<SavingsContributionEntry> savingsHistory,
}) {
  final totalIncome = normalizeMoney(
    incomeEntries.fold<double>(0, (sum, item) => sum + item.amount),
  );
  final settledBillsTotal = normalizeMoney(
    bills
        .where((item) => item.isPaid)
        .fold<double>(0, (sum, item) => sum + item.amount),
  );
  final upcomingBillsTotal = normalizeMoney(
    bills
        .where((item) => !item.isPaid)
        .fold<double>(0, (sum, item) => sum + item.amount),
  );
  final totalSpending = normalizeMoney(
    expenses.fold<double>(0, (sum, item) => sum + item.amount),
  );
  final savingsContributionsTotal = normalizeMoney(
    savingsHistory
        .where((item) => item.isContribution)
        .fold<double>(0, (sum, item) => sum + item.amount),
  );
  final savingsWithdrawalsTotal = normalizeMoney(
    savingsHistory
        .where((item) => item.isWithdrawal)
        .fold<double>(0, (sum, item) => sum + item.amount),
  );
  final normalizedSavingsBalance = normalizeMoney(
    max(0.0, savingsBalance),
    allowNegative: false,
  );
  final openingSavingsBalance = normalizeMoney(
    max(
      0.0,
      normalizedSavingsBalance -
          savingsContributionsTotal +
          savingsWithdrawalsTotal,
    ),
    allowNegative: false,
  );
  // Available Balance must remain opening balance + income - spending
  // - settled bills - savings contributions + savings withdrawals.
  final availableBalance = normalizeMoney(
    normalizeMoney(startingBalance) +
        totalIncome -
        settledBillsTotal -
        totalSpending -
        savingsContributionsTotal +
        savingsWithdrawalsTotal,
  );

  return BalanceLedgerSnapshot(
    openingAvailableBalance: normalizeMoney(startingBalance),
    openingSavingsBalance: openingSavingsBalance,
    totalIncome: totalIncome,
    settledBillsTotal: settledBillsTotal,
    upcomingBillsTotal: upcomingBillsTotal,
    totalSpending: totalSpending,
    savingsContributionsTotal: savingsContributionsTotal,
    savingsWithdrawalsTotal: savingsWithdrawalsTotal,
    availableBalance: availableBalance,
    savingsBalance: normalizedSavingsBalance,
  );
}

BudgetSnapshot calculateBudgetSnapshot({
  required double incomeTotal,
  required double upcomingBillsAmount,
  required double spendingAmount,
  required int remainingDays,
  required double availableBalance,
  required double savingsBalance,
  double settledBillsAmount = 0,
  double savingsContributionsAmount = 0,
  double savingsWithdrawalsAmount = 0,
  bool useManualDailyBudget = false,
  double? manualDailyBudget,
}) {
  final normalizedIncomeTotal = normalizeMoney(incomeTotal);
  final normalizedUpcomingBillsAmount = normalizeMoney(upcomingBillsAmount);
  final normalizedSpendingAmount = normalizeMoney(spendingAmount);
  final normalizedAvailableBalance = normalizeMoney(availableBalance);
  final normalizedSavingsBalance = normalizeMoney(
    max(0.0, savingsBalance),
    allowNegative: false,
  );
  final normalizedSettledBillsAmount = normalizeMoney(settledBillsAmount);
  final normalizedSavingsContributionsAmount =
      normalizeMoney(savingsContributionsAmount);
  final normalizedSavingsWithdrawalsAmount =
      normalizeMoney(savingsWithdrawalsAmount);
  // Projected Available Balance accounts for upcoming unpaid bills while
  // leaving settled bills and spending in the current available balance.
  final projectedAvailableBalance = normalizeMoney(
    normalizedAvailableBalance - normalizedUpcomingBillsAmount,
  );
  final autoDailySpendingLimit = remainingDays > 0
      ? normalizeMoney(projectedAvailableBalance / remainingDays)
      : projectedAvailableBalance;
  final normalizedManualDailyBudget =
      manualDailyBudget != null && manualDailyBudget > 0
          ? normalizeMoney(manualDailyBudget, allowNegative: false)
          : null;
  final usesManualDailyBudget =
      useManualDailyBudget && normalizedManualDailyBudget != null;
  final safeProjectedAvailableBalance = normalizeMoney(
    max(0.0, projectedAvailableBalance),
    allowNegative: false,
  );
  final safeDailyBudgetLimit = remainingDays > 0
      ? normalizeMoney(
          safeProjectedAvailableBalance / remainingDays,
          allowNegative: false,
        )
      : safeProjectedAvailableBalance;
  final isManualDailyBudgetSafe = !usesManualDailyBudget ||
      (normalizedManualDailyBudget <= safeDailyBudgetLimit + 0.01 &&
          normalizedManualDailyBudget <= safeProjectedAvailableBalance + 0.01);
  final dailySpendingLimit = usesManualDailyBudget
      ? normalizedManualDailyBudget
      : autoDailySpendingLimit;

  return BudgetSnapshot(
    upcomingBillsAmount: normalizedUpcomingBillsAmount,
    spendingAmount: normalizedSpendingAmount,
    remainingDays: remainingDays,
    incomeTotal: normalizedIncomeTotal,
    projectedAvailableBalance: projectedAvailableBalance,
    availableBalance: normalizedAvailableBalance,
    savingsBalance: normalizedSavingsBalance,
    settledBillsAmount: normalizedSettledBillsAmount,
    savingsContributionsAmount: normalizedSavingsContributionsAmount,
    savingsWithdrawalsAmount: normalizedSavingsWithdrawalsAmount,
    autoDailySpendingLimit: autoDailySpendingLimit,
    manualDailyBudget: normalizedManualDailyBudget,
    usesManualDailyBudget: usesManualDailyBudget,
    isManualDailyBudgetSafe: isManualDailyBudgetSafe,
    dailySpendingLimit: dailySpendingLimit,
  );
}

String dailyBudgetSummaryText(BudgetSnapshot snapshot, int remainingDays) {
  if (snapshot.usesManualDailyBudget) {
    return snapshot.isManualDailyBudgetSafe
        ? 'Manual daily spending limit is on track'
        : 'Manual daily spending limit is above safe cutoff pace';
  }

  if (remainingDays > 0) {
    return '$remainingDays days until next cutoff';
  }

  return 'Falls back to Anticipated Balance';
}

double calculateFinancialHealthScore({
  required double savingsSaved,
  required double currentBalance,
  required double unpaidBills,
  required double totalExpenses,
}) {
  final cushion = max(0.0, savingsSaved) + max(0.0, currentBalance);
  final pressure = max(0.0, unpaidBills) + max(0.0, totalExpenses * 0.35);
  if (cushion == 0 && pressure == 0) return 0.0;
  return (100 * cushion / (cushion + pressure + 1))
      .clamp(0.0, 100.0)
      .toDouble();
}

String financialHealthLabel(double score, bool hasAnyData) {
  if (!hasAnyData) return 'Getting Started';
  if (score >= 75) return 'Strong';
  if (score >= 50) return 'Stable';
  if (score >= 30) return 'Watchful';
  return 'Needs Attention';
}

String financialHealthMessage(String label) {
  switch (label) {
    case 'Strong':
      return 'Your savings cushion currently looks stronger than your spending pressure.';
    case 'Stable':
      return 'You still have breathing room, but keep an eye on bills and daily spending.';
    case 'Watchful':
      return 'Your budget is tighter now, so short-term spending needs closer attention.';
    case 'Needs Attention':
      return 'Your current obligations are heavier than your available cushion.';
    default:
      return 'Start logging expenses, bills, and savings to build your first health snapshot.';
  }
}

void showAppMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

// -----------------------------------------------------------------------------
// Smart Expense Detection
// -----------------------------------------------------------------------------

Widget buildPageLoadingState(String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: intelliumCyan),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: intelliumTextSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class SmartExpenseDetectionDraft {
  final double? amount;
  final String sourceApp;
  final String title;
  final String category;
  final double confidence;
  final bool shouldSuggest;

  const SmartExpenseDetectionDraft({
    required this.amount,
    required this.sourceApp,
    required this.title,
    required this.category,
    required this.confidence,
    required this.shouldSuggest,
  });
}

class SmartExpenseNotificationEvent {
  final String packageName;
  final String title;
  final String body;
  final String subText;
  final int notificationId;
  final int postTimeMillis;

  const SmartExpenseNotificationEvent({
    required this.packageName,
    required this.title,
    required this.body,
    required this.subText,
    required this.notificationId,
    required this.postTimeMillis,
  });

  factory SmartExpenseNotificationEvent.fromMap(Map<dynamic, dynamic> map) {
    return SmartExpenseNotificationEvent(
      packageName: '${map['packageName'] ?? ''}',
      title: '${map['title'] ?? ''}',
      body: '${map['text'] ?? ''}',
      subText: '${map['subText'] ?? ''}',
      notificationId: (map['notificationId'] as num?)?.toInt() ?? 0,
      postTimeMillis: (map['postTime'] as num?)?.toInt() ?? 0,
    );
  }
}

class SmartExpenseDetectionBridge {
  static const EventChannel _channel = EventChannel(
    'sweldotrack/smart_expense_detection/notifications',
  );
  static const MethodChannel _controlChannel = MethodChannel(
    'sweldotrack/smart_expense_detection/control',
  );

  static Stream<SmartExpenseNotificationEvent> notificationStream() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const Stream<SmartExpenseNotificationEvent>.empty();
    }

    return _channel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .cast<Map<dynamic, dynamic>>()
        .map(SmartExpenseNotificationEvent.fromMap);
  }

  static Future<bool> hasNotificationAccess() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    try {
      return await _controlChannel.invokeMethod<bool>(
            'isNotificationListenerEnabled',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openNotificationAccessSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      await _controlChannel.invokeMethod<void>(
        'openNotificationListenerSettings',
      );
    } on MissingPluginException {
      // Keep the UX fail-safe when the platform call is unavailable.
    } on PlatformException {
      // Keep the UX fail-safe when the platform call is unavailable.
    } catch (_) {
      // Keep the UX fail-safe when the platform call is unavailable.
    }
  }

  static Future<void> syncNativeMonitoringConfig({
    required bool detectionEnabled,
    required List<String> monitoredApps,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      await _controlChannel.invokeMethod<void>(
        'syncSmartExpenseDetectionConfig',
        <String, dynamic>{
          'enabled': detectionEnabled,
          'monitoredApps': monitoredApps,
        },
      );
    } on MissingPluginException {
      // Keep the UX fail-safe when the platform call is unavailable.
    } on PlatformException {
      // Keep the UX fail-safe when the platform call is unavailable.
    } catch (_) {
      // Keep the UX fail-safe when the platform call is unavailable.
    }
  }
}

const bool smartExpenseDetectionLaunchEnabled = true;
const double smartExpenseSuggestionConfidenceThreshold = 0.75;
const Duration smartExpenseNotificationRecencyWindow = Duration(minutes: 5);
const Duration smartExpenseDuplicatePromptCooldown = Duration(minutes: 10);

const Map<String, String> smartExpenseSupportedApps = {
  'com.globe.gcash.android': 'GCash',
  'com.maya.ph': 'Maya',
  'com.paymaya': 'Maya',
  'com.shopee.ph': 'Shopee',
  'com.lazada.android': 'Lazada',
  'com.global.foodpanda.android': 'Foodpanda',
  'com.deliveryhero.foodpanda': 'Foodpanda',
  'com.grabtaxi.passenger': 'Grab',
};

const List<String> smartExpenseSupportedAppLabels = [
  'GCash',
  'Maya',
  'Shopee',
  'Lazada',
  'Foodpanda',
  'Grab',
];

String? resolveSmartExpenseSourceApp(String packageName) {
  return smartExpenseSupportedApps[packageName];
}

SmartExpenseDetectionDraft? parseSmartExpenseNotification({
  required String sourceApp,
  String? notificationTitle,
  String? notificationBody,
}) {
  final rawTitle = (notificationTitle ?? '').trim();
  final rawBody = (notificationBody ?? '').trim();
  final combinedText = '$rawTitle $rawBody'.trim();
  if (combinedText.isEmpty) return null;

  final normalizedText = combinedText.toLowerCase();
  final normalizedSource = sourceApp.toLowerCase();

  const paymentKeywords = [
    'paid',
    'payment',
    'purchase',
    'spent',
    'debited',
    'checkout',
    'charged',
  ];
  const commerceKeywords = [
    'order',
    'delivery',
    'receipt',
    'transaction',
    'cash in',
    'cash-out',
    'cash out',
    'merchant',
  ];
  const confirmationKeywords = [
    'successful',
    'successfully',
    'confirmed',
    'completed',
    'processed',
  ];
  const directExpenseKeywords = [
    'you paid',
    'paid to',
    'paid via',
    'charged',
    'debited from',
    'was debited',
    'order total',
    'checkout total',
  ];
  const ignoreKeywords = [
    'otp',
    'one-time password',
    'verification code',
    'security code',
    'log in',
    'login',
    'sign in',
    'cash in',
    'cash-in',
    'cashin',
    'money received',
    'received money',
    'you received',
    'received from',
    'sent you',
    'incoming transfer',
    'incoming payment',
    'received',
    'credited',
    'deposit received',
    'wallet top up',
    'top up successful',
    'top-up successful',
    'refund',
    'reversal',
    'reversed',
    'voucher',
    'promo',
    'promotion',
    'promo code',
    'discount',
    'sale',
    'reminder',
    'due date',
    'due soon',
    'bill due',
    'cashback',
    'cash back',
    'reward',
    'points',
    'loan approved',
    'credit limit',
    'available credit',
  ];

  final hasPaymentKeyword = paymentKeywords.any(normalizedText.contains);
  final hasCommerceKeyword = commerceKeywords.any(normalizedText.contains);
  final hasConfirmationKeyword = confirmationKeywords.any(
    normalizedText.contains,
  );
  final hasDirectExpenseKeyword = directExpenseKeywords.any(
    normalizedText.contains,
  );
  if (ignoreKeywords.any(normalizedText.contains)) {
    return null;
  }

  final currencyMatch = RegExp(
    r'(?:\u20B1|php\s*)(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)',
    caseSensitive: false,
  ).firstMatch(combinedText);

  Match? plainAmountMatch;
  if (currencyMatch == null && hasPaymentKeyword) {
    plainAmountMatch = RegExp(
      r'\b(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})|\d+\.\d{1,2})\b',
      caseSensitive: false,
    ).firstMatch(combinedText);
  }

  final amountText = currencyMatch?.group(1) ?? plainAmountMatch?.group(1);
  final amount = double.tryParse((amountText ?? '').replaceAll(',', ''));

  var confidence = 0.0;
  if (sourceApp.isNotEmpty) confidence += 0.1;
  if (amount != null && amount > 0) {
    confidence += currencyMatch != null ? 0.4 : 0.28;
  }
  if (hasPaymentKeyword) confidence += 0.25;
  if (hasCommerceKeyword) confidence += 0.08;
  if (hasConfirmationKeyword) confidence += 0.1;
  if (hasDirectExpenseKeyword) confidence += 0.17;

  String category = 'Other';
  if (normalizedSource.contains('foodpanda') ||
      (normalizedSource.contains('grab') &&
          (normalizedText.contains('food') ||
              normalizedText.contains('mart')))) {
    category = 'Food';
  } else if (normalizedText.contains('ride') ||
      normalizedText.contains('trip') ||
      normalizedText.contains('transport')) {
    category = 'Transport';
  } else if (normalizedText.contains('bill') ||
      normalizedText.contains('due') ||
      normalizedText.contains('utilities')) {
    category = 'Bills';
  }

  final guessedTitle =
      rawTitle.isNotEmpty && rawTitle.toLowerCase() != normalizedSource
          ? rawTitle
          : rawBody.isNotEmpty
              ? rawBody.split('\n').first.trim()
              : '$sourceApp payment';

  final shouldSuggest = amount != null &&
      amount > 0 &&
      confidence >= smartExpenseSuggestionConfidenceThreshold;
  if (!shouldSuggest) return null;

  return SmartExpenseDetectionDraft(
    amount: amount,
    sourceApp: sourceApp,
    title: guessedTitle,
    category: category,
    confidence: confidence.clamp(0.0, 1.0).toDouble(),
    shouldSuggest: true,
  );
}

class SweldoTrackApp extends StatefulWidget {
  const SweldoTrackApp({super.key});

  @override
  State<SweldoTrackApp> createState() => _SweldoTrackAppState();
}

class _SweldoTrackAppState extends State<SweldoTrackApp> {
  final PremiumService premiumService = PremiumService();
  final AppThemeController themeController = AppThemeController();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final Set<String> handledSmartExpenseNotifications = <String>{};
  final Map<String, int> handledSmartExpensePromptFingerprints =
      <String, int>{};
  StreamSubscription<SmartExpenseNotificationEvent>? smartExpenseSubscription;
  bool smartExpensePromptOpen = false;

  @override
  void initState() {
    super.initState();
    premiumService.addListener(_handlePremiumServiceChanged);
    unawaited(_initializeAppState());
    _startSmartExpenseDetectionListener();
  }

  Future<void> _initializeAppState() async {
    await themeController.load();
    await premiumService.initialize();
    await _syncSmartExpenseDetectionNativeState();
  }

  void _handlePremiumServiceChanged() {
    unawaited(_syncSmartExpenseDetectionNativeState());
  }

  Future<void> _syncSmartExpenseDetectionNativeState() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final detectionEnabled =
        await FinanceRepository.isSmartExpenseDetectionEnabled();
    final monitoredApps =
        await FinanceRepository.getSmartExpenseMonitoredApps();
    final shouldEnableNativeFiltering = smartExpenseDetectionLaunchEnabled &&
        premiumService.isPremium &&
        detectionEnabled &&
        monitoredApps.isNotEmpty;

    await SmartExpenseDetectionBridge.syncNativeMonitoringConfig(
      detectionEnabled: shouldEnableNativeFiltering,
      monitoredApps:
          shouldEnableNativeFiltering ? monitoredApps : const <String>[],
    );
  }

  void _startSmartExpenseDetectionListener() {
    if (!smartExpenseDetectionLaunchEnabled ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    smartExpenseSubscription?.cancel();
    smartExpenseSubscription =
        SmartExpenseDetectionBridge.notificationStream().listen(
      (event) {
        unawaited(_handleSmartExpenseNotification(event));
      },
      onError: (Object error, StackTrace stackTrace) {
        // Keep this listener fail-safe. Platform channel availability should
        // never crash the app or surface notification contents in logs.
      },
    );
  }

  Future<void> _handleSmartExpenseNotification(
    SmartExpenseNotificationEvent event,
  ) async {
    if (!smartExpenseDetectionLaunchEnabled) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!premiumService.isPremium) return;

    final detectionEnabled =
        await FinanceRepository.isSmartExpenseDetectionEnabled();
    if (!detectionEnabled) return;

    final hasNotificationAccess =
        await SmartExpenseDetectionBridge.hasNotificationAccess();
    if (!hasNotificationAccess) {
      await FinanceRepository.setSmartExpenseDetectionEnabled(false);
      return;
    }

    final sourceApp = resolveSmartExpenseSourceApp(event.packageName);
    if (sourceApp == null) return;
    if (event.postTimeMillis > 0) {
      final notificationAge = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(event.postTimeMillis));
      if (notificationAge > smartExpenseNotificationRecencyWindow) {
        return;
      }
    }

    final monitoredApps =
        await FinanceRepository.getSmartExpenseMonitoredApps();
    if (monitoredApps.isEmpty) return;

    final normalizedMonitoredApps =
        monitoredApps.map((value) => value.trim().toLowerCase()).toSet();
    if (!normalizedMonitoredApps.contains(sourceApp.toLowerCase())) {
      return;
    }

    final notificationKey =
        '${event.packageName}:${event.notificationId}:${event.postTimeMillis}';
    if (!handledSmartExpenseNotifications.add(notificationKey)) {
      return;
    }
    if (handledSmartExpenseNotifications.length > 120) {
      handledSmartExpenseNotifications.clear();
      handledSmartExpenseNotifications.add(notificationKey);
    }

    final combinedBodyParts = <String>[
      if (event.body.isNotEmpty) event.body,
      if (event.subText.isNotEmpty && event.subText != event.body)
        event.subText,
    ];
    final draft = parseSmartExpenseNotification(
      sourceApp: sourceApp,
      notificationTitle: event.title,
      notificationBody: combinedBodyParts.join('\n'),
    );
    if (draft == null || !draft.shouldSuggest || smartExpensePromptOpen) {
      return;
    }
    if (draft.confidence < smartExpenseSuggestionConfidenceThreshold) {
      return;
    }

    final fingerprint = [
      event.packageName.toLowerCase(),
      draft.sourceApp.toLowerCase(),
      draft.amount?.toStringAsFixed(2) ?? '',
      draft.title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim(),
    ].join('|');
    final lastPromptAt = handledSmartExpensePromptFingerprints[fingerprint];
    if (lastPromptAt != null &&
        event.postTimeMillis - lastPromptAt <
            smartExpenseDuplicatePromptCooldown.inMilliseconds) {
      return;
    }
    handledSmartExpensePromptFingerprints[fingerprint] = event.postTimeMillis;
    if (handledSmartExpensePromptFingerprints.length > 160) {
      handledSmartExpensePromptFingerprints.removeWhere(
        (_, timestamp) =>
            event.postTimeMillis - timestamp >
            smartExpenseDuplicatePromptCooldown.inMilliseconds,
      );
      if (handledSmartExpensePromptFingerprints.length > 160) {
        handledSmartExpensePromptFingerprints.clear();
        handledSmartExpensePromptFingerprints[fingerprint] =
            event.postTimeMillis;
      }
    }

    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted || !mounted) return;

    smartExpensePromptOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: intelliumSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                const SizedBox(height: 20),
                const Text(
                  'Possible expense detected',
                  style: TextStyle(
                    color: intelliumTextPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  sourceApp,
                  style: const TextStyle(
                    color: intelliumCyan,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Nothing is saved automatically. Review the amount and details, then save only if everything looks right.',
                  style: TextStyle(
                    color: intelliumTextSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: intelliumCard,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.title.isEmpty
                            ? '$sourceApp payment'
                            : draft.title,
                        style: const TextStyle(
                          color: intelliumTextPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        draft.amount == null
                            ? 'Amount not detected'
                            : formatPhp(draft.amount!, decimals: 2),
                        style: const TextStyle(
                          color: intelliumTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Category guess: ${draft.category}',
                        style: const TextStyle(
                          color: intelliumTextSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Ignore'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Save Expense',
                        onPressed: () async {
                          final amount = draft.amount;
                          if (amount == null || amount <= 0) {
                            showAppMessage(
                              sheetContext,
                              'Amount was not clear enough to save this suggestion.',
                            );
                            return;
                          }

                          final expenses =
                              await FinanceRepository.loadExpenses();
                          expenses.insert(
                            0,
                            ExpenseItem(
                              id: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              title: draft.title.isEmpty
                                  ? '$sourceApp payment'
                                  : draft.title,
                              amount: amount,
                              category: draft.category,
                              paymentMethod: sourceApp,
                              createdAt: DateTime.now(),
                            ),
                          );
                          await FinanceRepository.saveExpenses(expenses);
                          if (!sheetContext.mounted) return;
                          Navigator.pop(sheetContext);
                          final rootContext = navigatorKey.currentContext;
                          if (rootContext != null) {
                            showAppMessage(
                              rootContext,
                              'Expense suggestion from $sourceApp saved after your review.',
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      smartExpensePromptOpen = false;
    }
  }

  @override
  void dispose() {
    premiumService.removeListener(_handlePremiumServiceChanged);
    smartExpenseSubscription?.cancel();
    premiumService.dispose();
    themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([premiumService, themeController]),
      builder: (context, _) {
        final theme = buildSweldoTheme(
          sweldoThemeFor(
            themeController.effectivePreset(
                hasPremium: premiumService.isPremium),
          ),
        );

        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'SweldoTrack',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          darkTheme: theme,
          theme: theme,
          home: MainNavigationScreen(
            premiumService: premiumService,
            themeController: themeController,
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Models
// -----------------------------------------------------------------------------

class AppKeys {
  static const installMarker = 'premium_install_marker_v1';
  static const preferredName = 'premium_preferred_name_v1';
  static const onboardingComplete = 'premium_onboarding_complete_v1';
  static const smartExpenseDetectionEnabled =
      'premium_smart_expense_detection_enabled_v1';
  static const smartExpenseMonitoredApps =
      'premium_smart_expense_monitored_apps_v1';
  static const expenses = 'premium_expenses_v1';
  static const startingBalance = 'premium_starting_balance_v1';
  static const incomeEntries = 'premium_income_entries_v1';
  static const legacySalaryMigratedToIncome =
      'premium_legacy_salary_migrated_to_income_v1';
  static const savingsGoal = 'premium_savings_goal_v1';
  static const savingsGoalName = 'premium_savings_goal_name_v1';
  static const savingsSaved = 'premium_savings_saved_v1';
  static const savingsHistory = 'premium_savings_history_v1';
  static const bills = 'premium_bills_v1';
  // Legacy migration source only. New balance logic should use
  // startingBalance + incomeEntries instead of treating salary as the
  // active money source.
  static const salary = 'premium_salary_v1';
  static const salaryReceivedDate = 'premium_salary_received_date_v1';
  static const nextPaydayDate = 'premium_next_payday_date_v1';
  static const daysUntilPayday = 'premium_days_until_payday_v1';
  static const targetSavings = 'premium_target_savings_v1';
  static const useManualDailyBudget = 'premium_use_manual_daily_budget_v1';
  static const manualDailyBudget = 'premium_manual_daily_budget_v1';
  static const fixedExpenses = 'premium_fixed_expenses_v1';
  static const referralCode = 'premium_referral_code_v1';
  static const referralInvites = 'premium_referral_invites_v1';
  static const referralActive = 'premium_referral_active_v1';
  static const referralPaid = 'premium_referral_paid_v1';
  static const referralEarnings = 'premium_referral_earnings_v1';
  static const referralHistory = 'premium_referral_history_v1';
  static const premiumActive = 'premium_subscription_active_v1';
  static const premiumLastProductId = 'premium_subscription_product_id_v1';
  static const premiumLastVerifiedAt = 'premium_subscription_verified_at_v1';
  static const premiumLastExpiryDate = 'premium_subscription_expiry_at_v1';
  static const premiumLastVerificationMode =
      'premium_subscription_verification_mode_v1';
  static const premiumTestOverride = 'premium_subscription_test_override_v1';
  static const toolTodoItems = 'premium_tools_todo_items_v1';
  static const selectedTheme = 'premium_selected_theme_v1';
}

class ExpenseItem {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String paymentMethod;
  final DateTime createdAt;

  ExpenseItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.paymentMethod,
    required this.createdAt,
  });

  ExpenseItem copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    String? paymentMethod,
    DateTime? createdAt,
  }) {
    return ExpenseItem(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'paymentMethod': paymentMethod,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    final createdAt = _readStoredDateTime(map['createdAt']) ?? DateTime.now();
    final title = _readStoredString(map['title']);
    final amount = _readStoredMoney(map['amount']);
    final category = _readStoredString(map['category'], fallback: 'Other');
    final paymentMethod =
        _readStoredString(map['paymentMethod'], fallback: 'Cash');

    return ExpenseItem(
      id: _readStoredString(
        map['id'],
        fallback: _buildStableFallbackId(
          'expense',
          <Object?>[
            title,
            amount.toStringAsFixed(2),
            category,
            paymentMethod,
            createdAt.toIso8601String(),
          ],
        ),
      ),
      title: title,
      amount: amount,
      category: category,
      paymentMethod: paymentMethod,
      createdAt: createdAt,
    );
  }
}

class FixedExpenseItem {
  final String id;
  final String name;
  final double amount;

  FixedExpenseItem({
    required this.id,
    required this.name,
    required this.amount,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'amount': amount,
      };

  factory FixedExpenseItem.fromMap(Map<String, dynamic> map) {
    final name = _readStoredString(map['name']);
    final amount = _readStoredMoney(map['amount']);
    return FixedExpenseItem(
      id: _readStoredString(
        map['id'],
        fallback: _buildStableFallbackId(
          'fixed-expense',
          <Object?>[name, amount.toStringAsFixed(2)],
        ),
      ),
      name: name,
      amount: amount,
    );
  }
}

const Object _billPaidDateUnset = Object();
const Object _billSettledCycleKeyUnset = Object();

class BillItem {
  final String id;
  final String title;
  final double amount;
  final DateTime dueDate;
  final DateTime? paidDate;
  final String? settledCycleKey;
  final String category;
  final bool isRecurring;
  final bool isPaid;

  BillItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.paidDate,
    required this.settledCycleKey,
    required this.category,
    required this.isRecurring,
    required this.isPaid,
  });

  BillItem copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? dueDate,
    Object? paidDate = _billPaidDateUnset,
    Object? settledCycleKey = _billSettledCycleKeyUnset,
    String? category,
    bool? isRecurring,
    bool? isPaid,
  }) {
    return BillItem(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      paidDate: identical(paidDate, _billPaidDateUnset)
          ? this.paidDate
          : paidDate as DateTime?,
      settledCycleKey: identical(
        settledCycleKey,
        _billSettledCycleKeyUnset,
      )
          ? this.settledCycleKey
          : settledCycleKey as String?,
      category: category ?? this.category,
      isRecurring: isRecurring ?? this.isRecurring,
      isPaid: isPaid ?? this.isPaid,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'dueDate': dueDate.toIso8601String(),
        'paidDate': paidDate?.toIso8601String(),
        'settledCycleKey': settledCycleKey,
        'category': category,
        'isRecurring': isRecurring,
        'isPaid': isPaid,
      };

  factory BillItem.fromMap(Map<String, dynamic> map) {
    final isRecurring = _readStoredBool(
      map['isRecurring'],
      fallback: true,
    );
    final isPaid = _readStoredBool(
      map['isPaid'],
      fallback: false,
    );
    final title = _readStoredString(map['title']);
    final amount = _readStoredMoney(map['amount']);
    final dueDate = parseBillDueDateValue(
      map['dueDate'],
      isRecurring: isRecurring,
    );
    final paidDate = _readStoredDateTime(map['paidDate']);
    final storedSettledCycleKey = _readStoredString(map['settledCycleKey']);
    final settledCycleKey = storedSettledCycleKey.isNotEmpty
        ? storedSettledCycleKey
        : (isRecurring && isPaid && paidDate != null
            ? billCycleKey(paidDate)
            : null);
    final category = _readStoredString(map['category'], fallback: 'Other');
    return BillItem(
      id: _readStoredString(
        map['id'],
        fallback: _buildStableFallbackId(
          'bill',
          <Object?>[
            title,
            amount.toStringAsFixed(2),
            map['dueDate'] ?? dueDate.toIso8601String(),
            category,
            isRecurring,
          ],
        ),
      ),
      title: title,
      amount: amount,
      dueDate: dueDate,
      paidDate: isPaid ? paidDate : null,
      settledCycleKey: isRecurring ? settledCycleKey : null,
      category: category,
      isRecurring: isRecurring,
      isPaid: isPaid,
    );
  }
}

class TodoTaskItem {
  final String id;
  final String title;
  final bool isCompleted;
  final DateTime createdAt;

  TodoTaskItem({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.createdAt,
  });

  TodoTaskItem copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return TodoTaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TodoTaskItem.fromMap(Map<String, dynamic> map) => TodoTaskItem(
        id: _readStoredString(
          map['id'],
          fallback: _buildStableFallbackId(
            'todo',
            <Object?>[
              map['title'],
              map['createdAt'],
            ],
          ),
        ),
        title: _readStoredString(map['title']),
        isCompleted: _readStoredBool(map['isCompleted'], fallback: false),
        createdAt: _readStoredDateTime(map['createdAt']) ?? DateTime.now(),
      );
}

class IncomeEntry {
  final String id;
  final double amount;
  final DateTime receivedAt;
  final String note;

  const IncomeEntry({
    required this.id,
    required this.amount,
    required this.receivedAt,
    required this.note,
  });

  IncomeEntry copyWith({
    String? id,
    double? amount,
    DateTime? receivedAt,
    String? note,
  }) {
    return IncomeEntry(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      receivedAt: receivedAt ?? this.receivedAt,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'receivedAt': receivedAt.toIso8601String(),
        'note': note,
      };

  factory IncomeEntry.fromMap(Map<String, dynamic> map) {
    final receivedAt = _readStoredDateTime(map['receivedAt']) ?? DateTime.now();
    final note = _readStoredString(map['note']);
    final amount = _readStoredMoney(map['amount']);
    return IncomeEntry(
      id: _readStoredString(
        map['id'],
        fallback: _buildStableFallbackId(
          'income',
          <Object?>[
            amount.toStringAsFixed(2),
            receivedAt.toIso8601String(),
            note,
          ],
        ),
      ),
      amount: amount,
      receivedAt: receivedAt,
      note: note,
    );
  }
}

class SavingsContributionEntry {
  final String id;
  final double amount;
  final DateTime createdAt;
  final SavingsTransferType type;

  const SavingsContributionEntry({
    required this.id,
    required this.amount,
    required this.createdAt,
    this.type = SavingsTransferType.contribution,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'createdAt': createdAt.toIso8601String(),
        'type': type.storageValue,
      };

  factory SavingsContributionEntry.fromMap(Map<String, dynamic> map) {
    final createdAt = _readStoredDateTime(map['createdAt']) ?? DateTime.now();
    final amount = _readStoredMoney(map['amount'], allowNegative: false);
    final type = SavingsTransferTypeX.fromStoredValue(
      _readStoredString(map['type']),
    );
    return SavingsContributionEntry(
      id: _readStoredString(
        map['id'],
        fallback: _buildStableFallbackId(
          'savings-transfer',
          <Object?>[
            amount.toStringAsFixed(2),
            createdAt.toIso8601String(),
            type.storageValue,
          ],
        ),
      ),
      amount: amount,
      createdAt: createdAt,
      type: type,
    );
  }

  bool get isContribution => type == SavingsTransferType.contribution;
  bool get isWithdrawal => type == SavingsTransferType.withdrawal;
  double get savingsBalanceEffect => isContribution ? amount : -amount;
  double get availableBalanceEffect => isContribution ? -amount : amount;
  String get label =>
      isContribution ? 'Add to Savings' : 'Withdraw from Savings';
}

enum SavingsTransferType {
  contribution,
  withdrawal,
}

extension SavingsTransferTypeX on SavingsTransferType {
  String get storageValue {
    switch (this) {
      case SavingsTransferType.contribution:
        return 'contribution';
      case SavingsTransferType.withdrawal:
        return 'withdrawal';
    }
  }

  static SavingsTransferType fromStoredValue(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'withdrawal':
      case 'withdraw':
      case 'out':
        return SavingsTransferType.withdrawal;
      case 'contribution':
      case 'deposit':
      case 'in':
      default:
        return SavingsTransferType.contribution;
    }
  }
}

// -----------------------------------------------------------------------------
// Repository / local storage
// -----------------------------------------------------------------------------

class FinanceRepository {
  static const String _backupAppName = 'SweldoTrack';
  static const int _backupSchemaVersion = 1;
  static const List<String> _financeResetKeys = [
    AppKeys.expenses,
    AppKeys.startingBalance,
    AppKeys.incomeEntries,
    AppKeys.legacySalaryMigratedToIncome,
    AppKeys.savingsGoal,
    AppKeys.savingsGoalName,
    AppKeys.savingsSaved,
    AppKeys.savingsHistory,
    AppKeys.bills,
    AppKeys.salary,
    AppKeys.salaryReceivedDate,
    AppKeys.nextPaydayDate,
    AppKeys.daysUntilPayday,
    AppKeys.targetSavings,
    AppKeys.useManualDailyBudget,
    AppKeys.manualDailyBudget,
    AppKeys.fixedExpenses,
    AppKeys.referralCode,
    AppKeys.referralInvites,
    AppKeys.referralActive,
    AppKeys.referralPaid,
    AppKeys.referralEarnings,
    AppKeys.referralHistory,
  ];
  static const List<String> _allLocalUserDataResetKeys = [
    AppKeys.installMarker,
    AppKeys.preferredName,
    AppKeys.onboardingComplete,
    AppKeys.smartExpenseDetectionEnabled,
    AppKeys.smartExpenseMonitoredApps,
    ..._financeResetKeys,
    AppKeys.premiumActive,
    AppKeys.premiumLastProductId,
    AppKeys.premiumLastVerifiedAt,
    AppKeys.premiumLastExpiryDate,
    AppKeys.premiumLastVerificationMode,
    AppKeys.premiumTestOverride,
    AppKeys.toolTodoItems,
    AppKeys.selectedTheme,
  ];
  static const List<String> _backupSafeLocalKeys = [
    AppKeys.installMarker,
    AppKeys.preferredName,
    AppKeys.onboardingComplete,
    AppKeys.smartExpenseDetectionEnabled,
    AppKeys.smartExpenseMonitoredApps,
    AppKeys.expenses,
    AppKeys.startingBalance,
    AppKeys.incomeEntries,
    AppKeys.legacySalaryMigratedToIncome,
    AppKeys.savingsGoal,
    AppKeys.savingsGoalName,
    AppKeys.savingsSaved,
    AppKeys.savingsHistory,
    AppKeys.bills,
    AppKeys.salary,
    AppKeys.salaryReceivedDate,
    AppKeys.nextPaydayDate,
    AppKeys.daysUntilPayday,
    AppKeys.targetSavings,
    AppKeys.useManualDailyBudget,
    AppKeys.manualDailyBudget,
    AppKeys.fixedExpenses,
    AppKeys.referralCode,
    AppKeys.referralInvites,
    AppKeys.referralActive,
    AppKeys.referralPaid,
    AppKeys.referralEarnings,
    AppKeys.referralHistory,
    AppKeys.toolTodoItems,
    AppKeys.selectedTheme,
  ];
  static const List<String> _backupExpensesOnlyKeys = [AppKeys.expenses];
  static const List<String> _backupBillsOnlyKeys = [AppKeys.bills];
  static const Set<String> _backupStringKeys = {
    AppKeys.installMarker,
    AppKeys.preferredName,
    AppKeys.savingsGoalName,
    AppKeys.salaryReceivedDate,
    AppKeys.nextPaydayDate,
    AppKeys.referralCode,
    AppKeys.selectedTheme,
  };
  static const Set<String> _backupStringListKeys = {
    AppKeys.smartExpenseMonitoredApps,
    AppKeys.expenses,
    AppKeys.incomeEntries,
    AppKeys.savingsHistory,
    AppKeys.bills,
    AppKeys.fixedExpenses,
    AppKeys.referralHistory,
    AppKeys.toolTodoItems,
  };
  static const Set<String> _backupBoolKeys = {
    AppKeys.onboardingComplete,
    AppKeys.smartExpenseDetectionEnabled,
    AppKeys.legacySalaryMigratedToIncome,
    AppKeys.useManualDailyBudget,
  };
  static const Set<String> _backupDoubleKeys = {
    AppKeys.startingBalance,
    AppKeys.savingsGoal,
    AppKeys.savingsSaved,
    AppKeys.salary,
    AppKeys.targetSavings,
    AppKeys.manualDailyBudget,
    AppKeys.referralEarnings,
  };
  static const Set<String> _backupIntKeys = {
    AppKeys.daysUntilPayday,
    AppKeys.referralInvites,
    AppKeys.referralActive,
    AppKeys.referralPaid,
  };

  static Map<String, dynamic>? _decodeStoredJsonMap(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return null;
    final decoded = jsonDecode(normalized);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    return null;
  }

  static List<T> _dedupeById<T>(
    Iterable<T> items,
    String Function(T item) readId,
  ) {
    final seen = <String>{};
    final deduped = <T>[];
    for (final item in items) {
      final key = readId(item).trim();
      if (key.isEmpty) {
        deduped.add(item);
        continue;
      }
      if (seen.add(key)) {
        deduped.add(item);
      }
    }
    return deduped;
  }

  static List<String> _dedupeNormalizedStrings(Iterable<String> values) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      normalized.add(trimmed);
    }
    return normalized;
  }

  static int _compareBillItems(BillItem a, BillItem b) {
    final aSettled = isBillSettledForCurrentCycle(a);
    final bSettled = isBillSettledForCurrentCycle(b);
    if (aSettled != bSettled) {
      return aSettled ? 1 : -1;
    }
    final aDate = dateOnly(
      aSettled
          ? (a.paidDate ?? a.dueDate)
          : (resolveUpcomingBillDate(a) ?? a.dueDate),
    );
    final bDate = dateOnly(
      bSettled
          ? (b.paidDate ?? b.dueDate)
          : (resolveUpcomingBillDate(b) ?? b.dueDate),
    );
    final dateComparison =
        aSettled ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
    if (dateComparison != 0) return dateComparison;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  static Future<bool> ensureInstallMarker() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(AppKeys.installMarker);
    if (existing != null && existing.isNotEmpty) {
      return false;
    }

    await prefs.setString(
        AppKeys.installMarker, DateTime.now().toIso8601String());
    return true;
  }

  static Future<bool> hasAnySavedFinanceData() async {
    final prefs = await SharedPreferences.getInstance();
    final hasExpenses =
        (prefs.getStringList(AppKeys.expenses) ?? const <String>[]).isNotEmpty;
    final hasIncomeEntries =
        (prefs.getStringList(AppKeys.incomeEntries) ?? const <String>[])
            .isNotEmpty;
    final hasBills =
        (prefs.getStringList(AppKeys.bills) ?? const <String>[]).isNotEmpty;
    final hasFixedExpenses =
        (prefs.getStringList(AppKeys.fixedExpenses) ?? const <String>[])
            .isNotEmpty;
    final hasStartingBalance =
        (prefs.getDouble(AppKeys.startingBalance) ?? 0) != 0;
    final hasSavingsGoal = (prefs.getDouble(AppKeys.savingsGoal) ?? 0) != 0;
    final hasSavingsSaved = (prefs.getDouble(AppKeys.savingsSaved) ?? 0) != 0;
    final hasSalary = (prefs.getDouble(AppKeys.salary) ?? 0) != 0;
    final hasDaysUntilPayday =
        (prefs.getInt(AppKeys.daysUntilPayday) ?? 0) != 0;
    final hasTargetSavings = (prefs.getDouble(AppKeys.targetSavings) ?? 0) != 0;
    final hasManualDailyBudget =
        (prefs.getDouble(AppKeys.manualDailyBudget) ?? 0) != 0;
    final usesManualDailyBudget =
        prefs.getBool(AppKeys.useManualDailyBudget) ?? false;

    return hasExpenses ||
        hasIncomeEntries ||
        hasBills ||
        hasFixedExpenses ||
        hasStartingBalance ||
        hasSavingsGoal ||
        hasSavingsSaved ||
        hasSalary ||
        hasDaysUntilPayday ||
        hasTargetSavings ||
        hasManualDailyBudget ||
        usesManualDailyBudget;
  }

  static Future<String> getPreferredName() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(AppKeys.preferredName) ?? '').trim();
  }

  static Future<void> setPreferredName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppKeys.preferredName, value.trim());
  }

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppKeys.onboardingComplete) ?? false;
  }

  static Future<void> setOnboardingComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppKeys.onboardingComplete, value);
  }

  static Future<bool> isSmartExpenseDetectionEnabled() async {
    if (!smartExpenseDetectionLaunchEnabled) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppKeys.smartExpenseDetectionEnabled) ?? false;
  }

  static Future<void> setSmartExpenseDetectionEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!smartExpenseDetectionLaunchEnabled) {
      await prefs.setBool(AppKeys.smartExpenseDetectionEnabled, false);
      await SmartExpenseDetectionBridge.syncNativeMonitoringConfig(
        detectionEnabled: false,
        monitoredApps: const <String>[],
      );
      return;
    }
    await prefs.setBool(AppKeys.smartExpenseDetectionEnabled, value);
    final monitoredApps =
        value ? await getSmartExpenseMonitoredApps() : const <String>[];
    await SmartExpenseDetectionBridge.syncNativeMonitoringConfig(
      detectionEnabled: value && monitoredApps.isNotEmpty,
      monitoredApps: monitoredApps,
    );
  }

  static Future<List<String>> getSmartExpenseMonitoredApps() async {
    if (!smartExpenseDetectionLaunchEnabled) return [];
    final prefs = await SharedPreferences.getInstance();
    final rawApps = prefs.getStringList(AppKeys.smartExpenseMonitoredApps) ??
        const <String>[];
    final normalizedApps = smartExpenseSupportedAppLabels
        .where(
          (label) => rawApps.any(
            (saved) => saved.trim().toLowerCase() == label.toLowerCase(),
          ),
        )
        .toList();
    final needsRewrite = rawApps.length != normalizedApps.length ||
        rawApps.asMap().entries.any(
              (entry) =>
                  entry.key >= normalizedApps.length ||
                  entry.value.trim() != normalizedApps[entry.key],
            );
    if (needsRewrite) {
      await prefs.setStringList(
          AppKeys.smartExpenseMonitoredApps, normalizedApps);
    }
    return normalizedApps;
  }

  static Future<void> setSmartExpenseMonitoredApps(List<String> apps) async {
    final prefs = await SharedPreferences.getInstance();
    if (!smartExpenseDetectionLaunchEnabled) {
      await prefs.remove(AppKeys.smartExpenseMonitoredApps);
      await SmartExpenseDetectionBridge.syncNativeMonitoringConfig(
        detectionEnabled: false,
        monitoredApps: const <String>[],
      );
      return;
    }
    final normalizedApps = smartExpenseSupportedAppLabels
        .where(
          (supportedLabel) => apps.any(
            (value) =>
                value.trim().toLowerCase() == supportedLabel.toLowerCase(),
          ),
        )
        .toList();
    await prefs.setStringList(
        AppKeys.smartExpenseMonitoredApps, normalizedApps);
    final detectionEnabled =
        prefs.getBool(AppKeys.smartExpenseDetectionEnabled) ?? false;
    await SmartExpenseDetectionBridge.syncNativeMonitoringConfig(
      detectionEnabled: detectionEnabled && normalizedApps.isNotEmpty,
      monitoredApps: normalizedApps,
    );
  }

  static Future<List<ExpenseItem>> loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(AppKeys.expenses) ?? const <String>[];
    final items = <ExpenseItem>[];
    for (final entry in raw) {
      try {
        final decoded = _decodeStoredJsonMap(entry);
        if (decoded == null) continue;
        items.add(ExpenseItem.fromMap(decoded));
      } catch (_) {
        // Skip corrupted local entries without failing the full load.
      }
    }
    final normalized = _dedupeById(items, (item) => item.id)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return normalized;
  }

  static Future<void> saveExpenses(List<ExpenseItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _dedupeById(items, (item) => item.id)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await prefs.setStringList(
      AppKeys.expenses,
      normalized.map((e) => jsonEncode(e.toMap())).toList(),
    );
  }

  static Future<List<BillItem>> loadBills() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(AppKeys.bills);
    if (raw == null) {
      return [];
    }
    final bills = <BillItem>[];
    for (final entry in raw) {
      try {
        final decoded = _decodeStoredJsonMap(entry);
        if (decoded == null) continue;
        bills.add(BillItem.fromMap(decoded));
      } catch (_) {
        // Skip corrupted local entries without failing the full load.
      }
    }
    final normalized = _dedupeById(bills, (item) => item.id)
      ..sort(_compareBillItems);
    return normalized;
  }

  static Future<void> saveBills(List<BillItem> bills) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _dedupeById(bills, (item) => item.id)
      ..sort(_compareBillItems);
    await prefs.setStringList(
      AppKeys.bills,
      normalized.map((e) => jsonEncode(e.toMap())).toList(),
    );
  }

  static Future<List<FixedExpenseItem>> loadFixedExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(AppKeys.fixedExpenses);
    if (raw == null) {
      return [];
    }
    final items = <FixedExpenseItem>[];
    for (final entry in raw) {
      try {
        final decoded = _decodeStoredJsonMap(entry);
        if (decoded == null) continue;
        items.add(FixedExpenseItem.fromMap(decoded));
      } catch (_) {
        // Skip corrupted local entries without failing the full load.
      }
    }
    return _dedupeById(items, (item) => item.id);
  }

  static Future<void> saveFixedExpenses(List<FixedExpenseItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _dedupeById(items, (item) => item.id);
    await prefs.setStringList(
      AppKeys.fixedExpenses,
      normalized.map((e) => jsonEncode(e.toMap())).toList(),
    );
  }

  static Future<List<TodoTaskItem>> loadToolTodoItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(AppKeys.toolTodoItems) ?? [];
    final items = <TodoTaskItem>[];
    for (final entry in raw) {
      try {
        final decoded = _decodeStoredJsonMap(entry);
        if (decoded == null) continue;
        items.add(TodoTaskItem.fromMap(decoded));
      } catch (_) {
        // Skip corrupted local entries without failing the full load.
      }
    }
    final normalized = _dedupeById(items, (item) => item.id)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return normalized;
  }

  static Future<void> saveToolTodoItems(List<TodoTaskItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      AppKeys.toolTodoItems,
      items.map((e) => jsonEncode(e.toMap())).toList(),
    );
  }

  static Future<double> getSavingsGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGoal = prefs.getDouble(AppKeys.savingsGoal);
    if (savedGoal != null) {
      return normalizeMoney(savedGoal, allowNegative: false);
    }

    final legacyTargetSavings = prefs.getDouble(AppKeys.targetSavings) ?? 0;
    if (legacyTargetSavings != 0) {
      await prefs.setDouble(
        AppKeys.savingsGoal,
        normalizeMoney(legacyTargetSavings, allowNegative: false),
      );
    }
    return normalizeMoney(legacyTargetSavings, allowNegative: false);
  }

  static Future<String> getSavingsGoalName() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(AppKeys.savingsGoalName) ?? 'Savings Target')
        .trim();
  }

  static Future<double> getTrackedSavingsAmount() async {
    final prefs = await SharedPreferences.getInstance();
    final storedSavings = prefs.getDouble(AppKeys.savingsSaved);
    final rawHistory =
        prefs.getStringList(AppKeys.savingsHistory) ?? const <String>[];
    if (rawHistory.isNotEmpty) {
      final inferredBalance = rawHistory
          .map((item) {
            try {
              final decoded = _decodeStoredJsonMap(item);
              if (decoded != null) {
                return SavingsContributionEntry.fromMap(decoded);
              }
            } catch (_) {}
            return null;
          })
          .whereType<SavingsContributionEntry>()
          .fold<double>(
            0,
            (sum, item) => sum + item.savingsBalanceEffect,
          );
      final normalizedBalance = normalizeMoney(
        max(0.0, inferredBalance),
        allowNegative: false,
      );
      if (storedSavings == null ||
          (normalizeMoney(storedSavings, allowNegative: false) -
                      normalizedBalance)
                  .abs() >
              0.009) {
        await prefs.setDouble(AppKeys.savingsSaved, normalizedBalance);
      }
      return normalizedBalance;
    }

    if (storedSavings != null) {
      return normalizeMoney(
        max(0.0, storedSavings),
        allowNegative: false,
      );
    }

    return 0;
  }

  static Future<double> getSavingsSaved() async {
    return getTrackedSavingsAmount();
  }

  static Future<void> setSavingsGoal(double value) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedValue = normalizeMoney(value, allowNegative: false);
    await prefs.setDouble(AppKeys.savingsGoal, normalizedValue);
    await prefs.setDouble(AppKeys.targetSavings, normalizedValue);
  }

  static Future<void> setSavingsGoalName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value.trim();
    await prefs.setString(
      AppKeys.savingsGoalName,
      trimmed.isEmpty ? 'Savings Target' : trimmed,
    );
  }

  static Future<void> setSavingsSaved(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
      AppKeys.savingsSaved,
      normalizeMoney(max(0.0, value), allowNegative: false),
    );
  }

  static Future<List<SavingsContributionEntry>> loadSavingsHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(AppKeys.savingsHistory) ?? const <String>[];
    final entries = raw
        .map((item) {
          try {
            final decoded = _decodeStoredJsonMap(item);
            if (decoded != null) {
              return SavingsContributionEntry.fromMap(decoded);
            }
          } catch (_) {}
          return null;
        })
        .whereType<SavingsContributionEntry>()
        .toList();
    final normalized = _dedupeById(entries, (item) => item.id)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return normalized;
  }

  static Future<void> saveSavingsHistory(
    List<SavingsContributionEntry> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _dedupeById(items, (item) => item.id)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await prefs.setStringList(
      AppKeys.savingsHistory,
      normalized.map((item) => jsonEncode(item.toMap())).toList(),
    );
  }

  static Future<void> addSavingsTransfer(SavingsContributionEntry item) async {
    final currentSaved = await getTrackedSavingsAmount();
    if (item.isWithdrawal && item.amount > currentSaved + 0.001) {
      return;
    }
    final nextSaved = normalizeMoney(
      currentSaved + item.savingsBalanceEffect,
      allowNegative: false,
    );
    final existingHistory = await loadSavingsHistory();
    final updated = <SavingsContributionEntry>[
      item,
      ...existingHistory,
    ];
    updated.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await setSavingsSaved(nextSaved);
    await saveSavingsHistory(updated);
  }

  static Future<void> clearSavingsProgress() async {
    await setSavingsSaved(0);
    await saveSavingsHistory(const <SavingsContributionEntry>[]);
  }

  static Future<void> addSavingsContribution(
      SavingsContributionEntry item) async {
    await addSavingsTransfer(
      item.type == SavingsTransferType.contribution
          ? item
          : SavingsContributionEntry(
              id: item.id,
              amount: item.amount,
              createdAt: item.createdAt,
              type: SavingsTransferType.contribution,
            ),
    );
  }

  @Deprecated(
    'Legacy income helper. Use getTotalIncomeAmount() for income history totals.',
  )
  static Future<double> getSalary() async {
    return getTotalIncomeAmount();
  }

  static Future<double> getStartingBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return normalizeMoney(prefs.getDouble(AppKeys.startingBalance) ?? 0);
  }

  static Future<void> setStartingBalance(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppKeys.startingBalance, normalizeMoney(value));
  }

  static Future<double> getTotalIncomeAmount() async {
    final entries = await loadIncomeEntries();
    return normalizeMoney(
        entries.fold<double>(0, (sum, item) => sum + item.amount));
  }

  static Future<double> getLegacySalarySeedAmount() async {
    final prefs = await SharedPreferences.getInstance();
    return normalizeMoney(prefs.getDouble(AppKeys.salary) ?? 0);
  }

  static Future<bool> hasMigratedLegacySalarySeed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppKeys.legacySalaryMigratedToIncome) ?? false;
  }

  static Future<void> markLegacySalarySeedMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppKeys.legacySalaryMigratedToIncome, true);
  }

  static Future<void> _migrateLegacySalarySeedToIncomeEntriesIfNeeded() async {
    final alreadyMigrated = await hasMigratedLegacySalarySeed();
    if (alreadyMigrated) return;

    final legacySalarySeed = await getLegacySalarySeedAmount();
    if (legacySalarySeed <= 0) {
      await markLegacySalarySeedMigrated();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final existingEntriesRaw =
        prefs.getStringList(AppKeys.incomeEntries) ?? const <String>[];
    if (existingEntriesRaw.isNotEmpty) {
      await markLegacySalarySeedMigrated();
      return;
    }

    final legacyReceivedDateRaw = prefs.getString(AppKeys.salaryReceivedDate);
    final migratedEntry = IncomeEntry(
      id: 'legacy-${DateTime.now().microsecondsSinceEpoch}',
      amount: legacySalarySeed,
      receivedAt: parseStoredIsoDate(legacyReceivedDateRaw) ?? DateTime.now(),
      note: 'Legacy salary import',
    );
    await saveIncomeEntries(<IncomeEntry>[migratedEntry]);
    await markLegacySalarySeedMigrated();
  }

  static Future<List<IncomeEntry>> loadIncomeEntries() async {
    await _migrateLegacySalarySeedToIncomeEntriesIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(AppKeys.incomeEntries) ?? const <String>[];
    final entries = raw
        .map((item) {
          try {
            final decoded = _decodeStoredJsonMap(item);
            if (decoded != null) {
              return IncomeEntry.fromMap(decoded);
            }
          } catch (_) {}
          return null;
        })
        .whereType<IncomeEntry>()
        .toList();
    final normalized = _dedupeById(entries, (item) => item.id)
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return normalized;
  }

  static Future<void> saveIncomeEntries(List<IncomeEntry> items) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _dedupeById(items, (item) => item.id)
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    await prefs.setStringList(
      AppKeys.incomeEntries,
      normalized.map((item) => jsonEncode(item.toMap())).toList(),
    );
    await markLegacySalarySeedMigrated();
  }

  static Future<void> addIncomeEntry(IncomeEntry item) async {
    final existingEntries = await loadIncomeEntries();
    final updated = <IncomeEntry>[item, ...existingEntries];
    await saveIncomeEntries(updated);
  }

  static Future<int> getDaysUntilPayday() async {
    final prefs = await SharedPreferences.getInstance();
    return max(0, prefs.getInt(AppKeys.daysUntilPayday) ?? 0);
  }

  static Future<DateTime?> getSalaryReceivedDate() async {
    final prefs = await SharedPreferences.getInstance();
    return parseStoredIsoDate(prefs.getString(AppKeys.salaryReceivedDate));
  }

  static Future<DateTime?> getNextPaydayDate() async {
    final prefs = await SharedPreferences.getInstance();
    return parseStoredIsoDate(prefs.getString(AppKeys.nextPaydayDate));
  }

  static Future<DailyBudgetSettings> getDailyBudgetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final useManualDailyBudget =
        prefs.getBool(AppKeys.useManualDailyBudget) ?? false;
    final manualDailyBudget = prefs.getDouble(AppKeys.manualDailyBudget);

    if (!useManualDailyBudget ||
        manualDailyBudget == null ||
        manualDailyBudget <= 0) {
      return DailyBudgetSettings(
        useManualDailyBudget: false,
        manualDailyBudget: manualDailyBudget,
      );
    }

    return DailyBudgetSettings(
      useManualDailyBudget: true,
      manualDailyBudget: normalizeMoney(
        manualDailyBudget,
        allowNegative: false,
      ),
    );
  }

  static Future<double> getTargetSavings() async {
    return getSavingsGoal();
  }

  static Future<void> saveBalanceSetup({
    required double startingBalance,
    required int daysUntilPayday,
    required double savingsGoalTarget,
    required DateTime? cycleStartDate,
    required DateTime? nextCutoffDate,
    required bool useManualDailyBudget,
    double? manualDailyBudget,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedDaysUntilPayday = max(0, daysUntilPayday);
    await prefs.setDouble(
      AppKeys.startingBalance,
      normalizeMoney(startingBalance),
    );
    await prefs.setInt(AppKeys.daysUntilPayday, normalizedDaysUntilPayday);
    await prefs.setDouble(
      AppKeys.savingsGoal,
      normalizeMoney(savingsGoalTarget, allowNegative: false),
    );
    await prefs.setDouble(
      AppKeys.targetSavings,
      normalizeMoney(savingsGoalTarget, allowNegative: false),
    );
    await prefs.setBool(AppKeys.useManualDailyBudget, useManualDailyBudget);
    if (useManualDailyBudget &&
        manualDailyBudget != null &&
        manualDailyBudget > 0) {
      await prefs.setDouble(
        AppKeys.manualDailyBudget,
        normalizeMoney(manualDailyBudget, allowNegative: false),
      );
    } else {
      await prefs.remove(AppKeys.manualDailyBudget);
    }
    if (cycleStartDate != null) {
      await prefs.setString(
        AppKeys.salaryReceivedDate,
        cycleStartDate.toIso8601String(),
      );
    } else {
      await prefs.remove(AppKeys.salaryReceivedDate);
    }
    if (nextCutoffDate != null) {
      await prefs.setString(
        AppKeys.nextPaydayDate,
        nextCutoffDate.toIso8601String(),
      );
    } else {
      await prefs.remove(AppKeys.nextPaydayDate);
    }
  }

  @Deprecated(
    'Legacy setup wrapper. Use saveBalanceSetup() with startingBalance instead.',
  )
  static Future<void> saveSweldoSetup({
    required double salary,
    required int daysUntilPayday,
    required double targetSavings,
    required DateTime? salaryReceivedDate,
    required DateTime? nextPaydayDate,
    required bool useManualDailyBudget,
    double? manualDailyBudget,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedDaysUntilPayday = max(0, daysUntilPayday);
    await prefs.setDouble(AppKeys.startingBalance, normalizeMoney(salary));
    await prefs.setInt(AppKeys.daysUntilPayday, normalizedDaysUntilPayday);
    await prefs.setDouble(
      AppKeys.savingsGoal,
      normalizeMoney(targetSavings, allowNegative: false),
    );
    await prefs.setDouble(
      AppKeys.targetSavings,
      normalizeMoney(targetSavings, allowNegative: false),
    );
    await prefs.setBool(AppKeys.useManualDailyBudget, useManualDailyBudget);
    if (useManualDailyBudget &&
        manualDailyBudget != null &&
        manualDailyBudget > 0) {
      await prefs.setDouble(
        AppKeys.manualDailyBudget,
        normalizeMoney(manualDailyBudget, allowNegative: false),
      );
    } else {
      await prefs.remove(AppKeys.manualDailyBudget);
    }
    if (salaryReceivedDate == null) {
      await prefs.remove(AppKeys.salaryReceivedDate);
    } else {
      await prefs.setString(
          AppKeys.salaryReceivedDate, salaryReceivedDate.toIso8601String());
    }
    if (nextPaydayDate == null) {
      await prefs.remove(AppKeys.nextPaydayDate);
    } else {
      await prefs.setString(
          AppKeys.nextPaydayDate, nextPaydayDate.toIso8601String());
    }
  }

  static Future<String> getReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = (prefs.getString(AppKeys.referralCode) ?? '').trim();
    if (existing.isNotEmpty) return existing;

    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ123456789';
    final random = Random();
    final code =
        List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
    await prefs.setString(AppKeys.referralCode, code);
    return code;
  }

  static Future<int> getReferralInvites() async {
    final prefs = await SharedPreferences.getInstance();
    return max(0, prefs.getInt(AppKeys.referralInvites) ?? 0);
  }

  static Future<int> getReferralActive() async {
    final prefs = await SharedPreferences.getInstance();
    return max(0, prefs.getInt(AppKeys.referralActive) ?? 0);
  }

  static Future<int> getReferralPaid() async {
    final prefs = await SharedPreferences.getInstance();
    return max(0, prefs.getInt(AppKeys.referralPaid) ?? 0);
  }

  static Future<double> getReferralEarnings() async {
    final prefs = await SharedPreferences.getInstance();
    return normalizeMoney(
      prefs.getDouble(AppKeys.referralEarnings) ?? 0,
      allowNegative: false,
    );
  }

  static Future<List<String>> getReferralHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHistory =
        prefs.getStringList(AppKeys.referralHistory) ?? const <String>[];
    final normalizedHistory = _dedupeNormalizedStrings(rawHistory);
    if (rawHistory.length != normalizedHistory.length ||
        rawHistory.asMap().entries.any(
              (entry) =>
                  entry.key >= normalizedHistory.length ||
                  entry.value.trim() != normalizedHistory[entry.key],
            )) {
      await prefs.setStringList(AppKeys.referralHistory, normalizedHistory);
    }
    return normalizedHistory;
  }

  static Future<void> saveReferralData({
    required int invites,
    required int active,
    required int paid,
    required double earnings,
    required List<String> history,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppKeys.referralInvites, max(0, invites));
    await prefs.setInt(AppKeys.referralActive, max(0, active));
    await prefs.setInt(AppKeys.referralPaid, max(0, paid));
    await prefs.setDouble(
      AppKeys.referralEarnings,
      normalizeMoney(earnings, allowNegative: false),
    );
    await prefs.setStringList(
      AppKeys.referralHistory,
      _dedupeNormalizedStrings(history),
    );
  }

  static Future<void> recordSuccessfulPaidReferral({
    required String referralCode,
  }) async {
    final invites = await getReferralInvites();
    final active = await getReferralActive();
    final paid = await getReferralPaid();
    final earnings = await getReferralEarnings();
    final history = await getReferralHistory();

    history.insert(
      0,
      '+ ${formatPhp(referralPaidRewardAmount)} | Successful paid referral using $referralCode',
    );

    await saveReferralData(
      invites: invites + 1,
      active: active + 1,
      paid: paid + 1,
      earnings: earnings + referralPaidRewardAmount,
      history: history,
    );
  }

  // Manual QA:
  // - Fresh install shows onboarding
  // - Onboarding images load
  // - Welcome setup image loads
  // - Name and opening balance save
  // - Reset Finance Data clears finance only
  // - Reset All Data clears profile/onboarding/theme/finance/smart detection
  // - Reset All Data does not cancel subscription
  // - Restore Purchases remains available
  // - Release hides debug controls
  // - Premium cannot unlock without verifier
  // - APK installs on physical phone
  // - AAB builds with versionCode 8
  static Future<void> resetFinanceData() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _financeResetKeys) {
      await prefs.remove(key);
    }
  }

  static Future<void> resetAllLocalUserData() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _allLocalUserDataResetKeys) {
      await prefs.remove(key);
    }
    await SmartExpenseDetectionBridge.syncNativeMonitoringConfig(
      detectionEnabled: false,
      monitoredApps: const <String>[],
    );
  }

  static Future<void> resetLocalTestingState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await SmartExpenseDetectionBridge.syncNativeMonitoringConfig(
      detectionEnabled: false,
      monitoredApps: const <String>[],
    );
  }

  static Future<String> exportAllLocalDataJson() async {
    return _buildBackupJson(
      scope: 'all_data',
      keys: _backupSafeLocalKeys,
    );
  }

  static Future<String> exportExpensesOnlyJson() async {
    return _buildBackupJson(
      scope: 'expenses_only',
      keys: _backupExpensesOnlyKeys,
    );
  }

  static Future<String> exportBillsOnlyJson() async {
    return _buildBackupJson(
      scope: 'bills_only',
      keys: _backupBillsOnlyKeys,
    );
  }

  static Future<String> _buildBackupJson({
    required String scope,
    required List<String> keys,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final key in keys) {
      final value = prefs.get(key);
      if (value == null) continue;
      data[key] = value;
    }
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'schemaVersion': _backupSchemaVersion,
      'app': _backupAppName,
      'scope': scope,
      'exportedAt': DateTime.now().toIso8601String(),
      'keys': keys,
      'data': data,
    });
  }

  static ({Map<String, dynamic> data, List<String> keys, String scope})
      parseLocalBackupJson(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Backup is empty.');
    }

    final decoded = jsonDecode(normalized);
    if (decoded is! Map) {
      throw const FormatException('Backup must be a JSON object.');
    }

    final wrapper = decoded.cast<String, dynamic>();
    final backupAppName = _readStoredString(wrapper['app']);
    if (backupAppName.isNotEmpty && backupAppName != _backupAppName) {
      throw const FormatException('Backup is for a different app.');
    }
    final schemaVersion = _readStoredInt(
      wrapper['schemaVersion'],
      fallback: -1,
    );
    if (schemaVersion != _backupSchemaVersion) {
      throw const FormatException('Unsupported backup schema version.');
    }
    final scope = _readStoredString(wrapper['scope'], fallback: 'custom');
    if (!wrapper.containsKey('data')) {
      throw const FormatException('Backup data is missing.');
    }
    final rawData = wrapper['data'];
    final rawKeys = wrapper['keys'];

    late final Map<String, dynamic> data;
    if (rawData is Map<String, dynamic>) {
      data = rawData;
    } else if (rawData is Map) {
      data = rawData.cast<String, dynamic>();
    } else {
      throw const FormatException('Backup data is missing.');
    }

    final keys = <String>[
      if (rawKeys is List)
        ...rawKeys
            .map((value) => '$value'.trim())
            .where((value) => _backupSafeLocalKeys.contains(value))
    ];
    if (keys.isEmpty) {
      keys.addAll(
        data.keys.where((key) => _backupSafeLocalKeys.contains(key)),
      );
    }
    if (keys.isEmpty) {
      throw const FormatException('Backup does not contain supported data.');
    }

    final sanitized = <String, dynamic>{};
    for (final key in keys) {
      if (data.containsKey(key)) {
        sanitized[key] = data[key];
      }
    }
    return (data: sanitized, keys: keys, scope: scope);
  }

  static Future<void> importLocalBackupJson(String raw) async {
    final parsed = parseLocalBackupJson(raw);
    final prefs = await SharedPreferences.getInstance();

    for (final key in parsed.keys) {
      await prefs.remove(key);
    }

    for (final entry in parsed.data.entries) {
      await _writeImportedBackupValue(
        prefs,
        key: entry.key,
        value: entry.value,
      );
    }

    final detectionEnabled =
        prefs.getBool(AppKeys.smartExpenseDetectionEnabled) ?? false;
    final monitoredApps =
        prefs.getStringList(AppKeys.smartExpenseMonitoredApps) ??
            const <String>[];
    await SmartExpenseDetectionBridge.syncNativeMonitoringConfig(
      detectionEnabled: detectionEnabled && monitoredApps.isNotEmpty,
      monitoredApps: monitoredApps,
    );
  }

  static Future<void> _writeImportedBackupValue(
    SharedPreferences prefs, {
    required String key,
    required dynamic value,
  }) async {
    if (_backupStringKeys.contains(key)) {
      final normalized = '$value'.trim();
      if (normalized.isNotEmpty) {
        await prefs.setString(key, normalized);
      }
      return;
    }
    if (_backupStringListKeys.contains(key)) {
      if (value is! List) return;
      final normalized = value.map((item) => '$item').toList();
      await prefs.setStringList(key, normalized);
      return;
    }
    if (_backupBoolKeys.contains(key)) {
      await prefs.setBool(key, _readStoredBool(value, fallback: false));
      return;
    }
    if (_backupDoubleKeys.contains(key)) {
      final normalized = value is num
          ? value.toDouble()
          : double.tryParse('${value ?? ''}'.trim());
      if (normalized != null) {
        await prefs.setDouble(key, normalized);
      }
      return;
    }
    if (_backupIntKeys.contains(key)) {
      final normalized =
          value is num ? value.toInt() : int.tryParse('${value ?? ''}'.trim());
      if (normalized != null) {
        await prefs.setInt(key, normalized);
      }
    }
  }
}

class AppThemeController extends ChangeNotifier {
  SweldoThemePreset _selectedPreset = SweldoThemePreset.emerald;

  SweldoThemePreset get selectedPreset => _selectedPreset;

  SweldoThemePreset effectivePreset({required bool hasPremium}) {
    if (isFreeSweldoTheme(_selectedPreset)) {
      return _selectedPreset;
    }
    if (hasPremium) return _selectedPreset;
    return SweldoThemePreset.emerald;
  }

  String currentThemeLabel({required bool hasPremium}) {
    return sweldoThemeFor(effectivePreset(hasPremium: hasPremium)).label;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedValue = prefs.getString(AppKeys.selectedTheme);
    _selectedPreset = SweldoThemePreset.values.firstWhere(
      (value) => value.name == storedValue,
      orElse: () => SweldoThemePreset.emerald,
    );
    notifyListeners();
  }

  Future<void> setTheme(SweldoThemePreset preset) async {
    _selectedPreset = preset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppKeys.selectedTheme, preset.name);
    notifyListeners();
  }
}

// -----------------------------------------------------------------------------
// Premium verification
// -----------------------------------------------------------------------------

enum PremiumVerificationMode { backend, localStub }

enum PremiumVerificationFailureKind {
  none,
  verifierMissing,
  backendFailed,
  receiptRejected,
}

void _debugPremiumLog(String message) {
  if (kDebugMode) {
    debugPrint('[Premium] $message');
  }
}

class PremiumVerificationResult {
  final bool isVerified;
  final bool isActive;
  final PremiumVerificationMode mode;
  final String? message;
  final String? purchasedProductId;
  final DateTime? expiryDate;

  const PremiumVerificationResult._({
    required this.isVerified,
    required this.isActive,
    required this.mode,
    this.message,
    this.purchasedProductId,
    this.expiryDate,
  });

  const PremiumVerificationResult.verified({
    required PremiumVerificationMode mode,
    String? purchasedProductId,
    String? message,
    DateTime? expiryDate,
  }) : this._(
          isVerified: true,
          isActive: true,
          mode: mode,
          purchasedProductId: purchasedProductId,
          message: message,
          expiryDate: expiryDate,
        );

  const PremiumVerificationResult.rejected({
    required PremiumVerificationMode mode,
    String? message,
    String? purchasedProductId,
    bool isActive = false,
    DateTime? expiryDate,
  }) : this._(
          isVerified: false,
          isActive: isActive,
          mode: mode,
          message: message,
          purchasedProductId: purchasedProductId,
          expiryDate: expiryDate,
        );
}

abstract class PremiumPurchaseVerificationRepository {
  const PremiumPurchaseVerificationRepository();

  Future<PremiumVerificationResult> verifyPurchase({
    required PurchaseDetails purchase,
    required String expectedProductId,
  });
}

class PremiumBackendVerificationPayload {
  final String productId;
  final String purchaseToken;
  final String localReceipt;
  final String verificationSource;
  final String purchaseStatus;
  final String purchaseId;
  final int? transactionDateMillis;

  const PremiumBackendVerificationPayload({
    required this.productId,
    required this.purchaseToken,
    required this.localReceipt,
    required this.verificationSource,
    required this.purchaseStatus,
    required this.purchaseId,
    required this.transactionDateMillis,
  });

  factory PremiumBackendVerificationPayload.fromPurchase(
    PurchaseDetails purchase,
  ) {
    final purchaseToken =
        purchase.verificationData.serverVerificationData.trim();
    final localReceipt = purchase.verificationData.localVerificationData.trim();

    return PremiumBackendVerificationPayload(
      productId: purchase.productID,
      purchaseToken: purchaseToken,
      localReceipt: localReceipt,
      verificationSource: purchase.verificationData.source,
      purchaseStatus: purchase.status.name,
      purchaseId: (purchase.purchaseID ?? '').trim(),
      transactionDateMillis: int.tryParse(
        (purchase.transactionDate ?? '').trim(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'purchaseToken': purchaseToken,
      'localReceipt': localReceipt,
      'verificationSource': verificationSource,
      'purchaseStatus': purchaseStatus,
      'purchaseId': purchaseId,
      'transactionDateMillis': transactionDateMillis,
      'platform': defaultTargetPlatform.name,
    };
  }
}

class PremiumBackendEntitlementStatus {
  final bool isVerified;
  final bool isActive;
  final String? productId;
  final DateTime? expiryDate;
  final String? message;

  const PremiumBackendEntitlementStatus({
    required this.isVerified,
    required this.isActive,
    this.productId,
    this.expiryDate,
    this.message,
  });

  factory PremiumBackendEntitlementStatus.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> entitlement = const {};
    final entitlementValue = json['entitlement'];
    if (entitlementValue is Map<String, dynamic>) {
      entitlement = entitlementValue;
    } else if (entitlementValue is Map) {
      entitlement = Map<String, dynamic>.from(entitlementValue);
    }

    dynamic pickValue(String key) {
      if (entitlement.containsKey(key)) return entitlement[key];
      return json[key];
    }

    String? pickString(List<String> keys) {
      for (final key in keys) {
        final value = pickValue(key);
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return null;
    }

    bool pickBool(List<String> keys, {required bool fallback}) {
      for (final key in keys) {
        final value = pickValue(key);
        if (value is bool) return value;
        if (value is num) return value != 0;
        if (value is String) {
          final normalized = value.trim().toLowerCase();
          if (normalized == 'true' || normalized == '1') return true;
          if (normalized == 'false' || normalized == '0') return false;
        }
      }
      return fallback;
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        return DateTime.tryParse(value.trim());
      }
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      }
      if (value is double) {
        return DateTime.fromMillisecondsSinceEpoch(
          value.toInt(),
          isUtc: true,
        );
      }
      return null;
    }

    final verified = pickBool(
      const ['verified', 'isVerified', 'entitled', 'isEntitled'],
      fallback: false,
    );
    final active = pickBool(
      const ['active', 'isActive'],
      fallback: verified,
    );

    return PremiumBackendEntitlementStatus(
      isVerified: verified,
      isActive: active,
      productId: pickString(const ['productId', 'product_id']),
      expiryDate: parseDate(
        pickValue('expiryDate') ??
            pickValue('expiry_date') ??
            pickValue('expiresAt') ??
            pickValue('expires_at'),
      ),
      message: pickString(const ['message', 'detail', 'reason']),
    );
  }
}

class PremiumBackendVerificationConfig {
  final String verificationUrl;
  final String bearerToken;
  final String apiKey;
  final Duration timeout;

  const PremiumBackendVerificationConfig({
    required this.verificationUrl,
    required this.bearerToken,
    required this.apiKey,
    this.timeout = const Duration(seconds: 15),
  });

  factory PremiumBackendVerificationConfig.fromEnvironment() {
    const configuredVerificationUrl = String.fromEnvironment(
      'SWELDOTRACK_PREMIUM_VERIFY_URL',
    );

    return const PremiumBackendVerificationConfig(
      verificationUrl: configuredVerificationUrl,
      bearerToken: String.fromEnvironment(
        'SWELDOTRACK_PREMIUM_VERIFY_BEARER_TOKEN',
      ),
      apiKey: String.fromEnvironment(
        'SWELDOTRACK_PREMIUM_VERIFY_API_KEY',
      ),
    );
  }

  Uri? get verificationUri {
    final rawUrl = verificationUrl.trim();
    if (rawUrl.isEmpty) return null;

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return null;
    }
    final normalizedScheme = uri.scheme.toLowerCase();
    final allowsHttpInDebug = kDebugMode && normalizedScheme == 'http';
    if (normalizedScheme != 'https' && !allowsHttpInDebug) {
      return null;
    }

    return uri;
  }

  bool get hasValidVerificationUrl => verificationUri != null;
  bool get hasAuthenticationConfig =>
      bearerToken.trim().isNotEmpty || apiKey.trim().isNotEmpty;

  bool get isConfigured => hasValidVerificationUrl && hasAuthenticationConfig;

  String get missingConfigurationMessage {
    final rawUrl = verificationUrl.trim();
    final parsedUrl = rawUrl.isEmpty ? null : Uri.tryParse(rawUrl);
    final isMalformedUrl = rawUrl.isNotEmpty &&
        (parsedUrl == null || !parsedUrl.hasScheme || !parsedUrl.hasAuthority);
    final usesInsecureScheme = parsedUrl != null &&
        parsedUrl.hasScheme &&
        parsedUrl.scheme.toLowerCase() != 'https' &&
        !(kDebugMode && parsedUrl.scheme.toLowerCase() == 'http');

    if (isMalformedUrl && !hasAuthenticationConfig) {
      return 'Premium verifier URL is malformed and authentication config is missing.';
    }
    if (rawUrl.isEmpty && !hasAuthenticationConfig) {
      return 'Premium verifier is missing a secure URL and authentication config.';
    }
    if (isMalformedUrl) {
      return 'Premium verifier URL is malformed.';
    }
    if (usesInsecureScheme) {
      return 'Premium verifier URL must use HTTPS outside debug builds.';
    }
    if (!hasValidVerificationUrl && !hasAuthenticationConfig) {
      return 'Premium verifier is missing a secure URL and authentication config.';
    }
    if (!hasValidVerificationUrl) {
      return 'Premium verifier is missing a secure URL.';
    }
    return 'Premium verifier is missing authentication config.';
  }

  Map<String, String> buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final normalizedBearerToken = bearerToken.trim();
    if (normalizedBearerToken.isNotEmpty) {
      final lowerToken = normalizedBearerToken.toLowerCase();
      headers['Authorization'] = lowerToken.startsWith('bearer ')
          ? normalizedBearerToken
          : 'Bearer $normalizedBearerToken';
    }
    if (apiKey.trim().isNotEmpty) {
      headers['x-api-key'] = apiKey.trim();
    }

    return headers;
  }
}

abstract class PremiumBackendApiClient {
  const PremiumBackendApiClient();

  bool get isConfigured;
  String get unavailableMessage;

  Future<PremiumBackendEntitlementStatus> verifyEntitlement(
    PremiumBackendVerificationPayload payload,
  );
}

class HttpPremiumBackendApiClient implements PremiumBackendApiClient {
  final PremiumBackendVerificationConfig config;
  final http.Client _httpClient;

  HttpPremiumBackendApiClient({
    required this.config,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  bool get isConfigured => config.isConfigured;

  @override
  String get unavailableMessage => isConfigured
      ? 'Premium verification is currently unavailable.'
      : premiumPurchasesUnavailableMessage;

  @override
  Future<PremiumBackendEntitlementStatus> verifyEntitlement(
    PremiumBackendVerificationPayload payload,
  ) async {
    final uri = config.verificationUri;
    if (uri == null) {
      _debugPremiumLog('verification skipped: invalid verifier URL');
      return PremiumBackendEntitlementStatus(
        isVerified: false,
        isActive: false,
        productId: payload.productId,
        message: unavailableMessage,
      );
    }

    _debugPremiumLog(
      'verification request started: source=${payload.verificationSource}, purchaseStatus=${payload.purchaseStatus}',
    );
    final response = await _httpClient
        .post(
          uri,
          headers: config.buildHeaders(),
          body: jsonEncode(payload.toJson()),
        )
        .timeout(config.timeout);
    _debugPremiumLog(
      'verification response received: statusCode=${response.statusCode}',
    );

    Map<String, dynamic> body = const {};
    if (response.body.trim().isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      } else if (decoded is Map) {
        body = Map<String, dynamic>.from(decoded);
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final status = PremiumBackendEntitlementStatus.fromJson(body);
      final backendMessage = (status.message ?? '').trim();
      final fallbackMessage = _looksLikeReceiptRejectedMessage(backendMessage)
          ? backendMessage
          : 'Verification failed. Please try again.';
      return PremiumBackendEntitlementStatus(
        isVerified: false,
        isActive: false,
        productId: status.productId ?? payload.productId,
        expiryDate: status.expiryDate,
        message: fallbackMessage,
      );
    }

    final status = PremiumBackendEntitlementStatus.fromJson(body);
    return PremiumBackendEntitlementStatus(
      isVerified: status.isVerified,
      isActive: status.isActive,
      productId: status.productId ?? payload.productId,
      expiryDate: status.expiryDate,
      message: status.message,
    );
  }
}

abstract class PremiumBackendVerificationService {
  const PremiumBackendVerificationService();

  bool get isAvailableForVerification;
  String get unavailableMessage;

  Future<PremiumVerificationResult> verifyPremiumPurchase(
    PremiumBackendVerificationPayload payload,
  );
}

// Premium app-side launch flag. UI stays visible when enabled, but release
// builds must still fail closed until backend receipt verification can verify.
const bool premiumLaunchEnabled = true;
const String premiumTemporarilyUnavailableLabel =
    'Premium Temporarily Unavailable';
const String premiumTemporarilyUnavailableActionLabel =
    'Premium Temporarily Unavailable';
const String premiumPurchasesUnavailableMessage =
    'Premium purchases are temporarily unavailable. Please try again later.';
const String premiumRestoreUnavailableMessage =
    'Premium purchases are temporarily unavailable. Please try again later.';
const String premiumBillingUnavailableMessage =
    'Google Play Billing is unavailable on this device.';
const String premiumPricingUnavailableMessage =
    'Premium pricing is unavailable right now. Please try again later.';
const String premiumPurchaseStartFailedMessage =
    'Premium purchase could not be started. Please try again.';
const String premiumPurchaseCanceledMessage =
    'Purchase canceled. You were not charged.';
const String premiumPurchaseNotConfirmedMessage =
    'Premium purchase could not be confirmed.';
const String premiumNoPreviousPurchaseMessage =
    'No previous premium purchase was found for this Google Play account.';
const double referralPaidRewardAmount = 20;

bool _looksLikeReceiptRejectedMessage(String rawMessage) {
  final message = rawMessage.trim().toLowerCase();
  if (message.isEmpty) return false;
  return message.contains('reject') ||
      message.contains('receipt') ||
      message.contains('entitlement') ||
      message.contains('expired') ||
      message.contains('unexpected product id') ||
      message.contains('unexpected premium product id') ||
      message.contains('no longer active') ||
      message.contains('already has this premium purchase') ||
      message.contains('unexpected product');
}

class BackendApiPremiumVerificationService
    implements PremiumBackendVerificationService {
  final PremiumBackendApiClient apiClient;

  BackendApiPremiumVerificationService({
    required this.apiClient,
  });

  @override
  bool get isAvailableForVerification => apiClient.isConfigured;

  @override
  String get unavailableMessage => apiClient.unavailableMessage;

  @override
  Future<PremiumVerificationResult> verifyPremiumPurchase(
    PremiumBackendVerificationPayload payload,
  ) async {
    if (!isAvailableForVerification) {
      _debugPremiumLog('verification blocked: verifier not configured');
      return PremiumVerificationResult.rejected(
        mode: PremiumVerificationMode.backend,
        purchasedProductId: payload.productId,
        message: unavailableMessage,
      );
    }

    try {
      final entitlement = await apiClient.verifyEntitlement(payload);
      final resolvedProductId = entitlement.productId?.trim().isNotEmpty == true
          ? entitlement.productId!.trim()
          : payload.productId;
      final expiryDateUtc = entitlement.expiryDate?.toUtc();

      if (resolvedProductId != payload.productId) {
        _debugPremiumLog('verification rejected: unexpected product id');
        return PremiumVerificationResult.rejected(
          mode: PremiumVerificationMode.backend,
          purchasedProductId: resolvedProductId,
          expiryDate: entitlement.expiryDate,
          message: 'Receipt rejected.',
        );
      }

      if (!entitlement.isVerified) {
        _debugPremiumLog(
            'verification rejected: backend did not verify receipt');
        return PremiumVerificationResult.rejected(
          mode: PremiumVerificationMode.backend,
          purchasedProductId: resolvedProductId,
          expiryDate: entitlement.expiryDate,
          message: entitlement.message?.trim().isNotEmpty == true
              ? entitlement.message!.trim()
              : 'Receipt rejected.',
        );
      }

      if (!entitlement.isActive) {
        _debugPremiumLog('verification rejected: entitlement inactive');
        return PremiumVerificationResult.rejected(
          mode: PremiumVerificationMode.backend,
          purchasedProductId: resolvedProductId,
          expiryDate: entitlement.expiryDate,
          message:
              entitlement.message ?? 'Premium entitlement is no longer active.',
        );
      }

      if (expiryDateUtc != null &&
          !expiryDateUtc.isAfter(DateTime.now().toUtc())) {
        _debugPremiumLog('verification rejected: entitlement expired');
        return PremiumVerificationResult.rejected(
          mode: PremiumVerificationMode.backend,
          purchasedProductId: resolvedProductId,
          expiryDate: entitlement.expiryDate,
          message:
              entitlement.message ?? 'Premium entitlement has already expired.',
        );
      }

      _debugPremiumLog('verification succeeded: entitlement active');
      return PremiumVerificationResult.verified(
        mode: PremiumVerificationMode.backend,
        purchasedProductId: resolvedProductId,
        expiryDate: entitlement.expiryDate,
        message: entitlement.message ??
            'Premium entitlement verified by the backend.',
      );
    } on TimeoutException {
      _debugPremiumLog('verification failed: timeout');
      return PremiumVerificationResult.rejected(
        mode: PremiumVerificationMode.backend,
        purchasedProductId: payload.productId,
        message: 'Verification failed. Please try again.',
      );
    } on FormatException {
      _debugPremiumLog('verification failed: invalid backend response');
      return PremiumVerificationResult.rejected(
        mode: PremiumVerificationMode.backend,
        purchasedProductId: payload.productId,
        message: 'Verification failed. Please try again.',
      );
    } catch (_) {
      _debugPremiumLog('verification failed: backend unreachable or errored');
      return PremiumVerificationResult.rejected(
        mode: PremiumVerificationMode.backend,
        purchasedProductId: payload.productId,
        message: 'Verification failed. Please try again.',
      );
    }
  }
}

class BackendPremiumPurchaseVerificationRepository
    implements PremiumPurchaseVerificationRepository {
  final PremiumBackendVerificationService backendVerificationService;

  const BackendPremiumPurchaseVerificationRepository({
    required this.backendVerificationService,
  });

  @override
  Future<PremiumVerificationResult> verifyPurchase({
    required PurchaseDetails purchase,
    required String expectedProductId,
  }) async {
    if (purchase.productID != expectedProductId) {
      return const PremiumVerificationResult.rejected(
        mode: PremiumVerificationMode.backend,
        message: 'Unexpected premium product ID.',
      );
    }

    final payload = PremiumBackendVerificationPayload.fromPurchase(purchase);

    if (payload.purchaseToken.isEmpty && payload.localReceipt.isEmpty) {
      return const PremiumVerificationResult.rejected(
        mode: PremiumVerificationMode.backend,
        message: 'Purchase receipt data is missing.',
      );
    }

    return backendVerificationService.verifyPremiumPurchase(payload);
  }
}

class LocalStubPremiumPurchaseVerificationRepository
    implements PremiumPurchaseVerificationRepository {
  final bool allowVerification;

  const LocalStubPremiumPurchaseVerificationRepository({
    this.allowVerification = kDebugMode,
  });

  @override
  Future<PremiumVerificationResult> verifyPurchase({
    required PurchaseDetails purchase,
    required String expectedProductId,
  }) async {
    final canUseLocalStub = kDebugMode && allowVerification;
    if (!canUseLocalStub) {
      return const PremiumVerificationResult.rejected(
        mode: PremiumVerificationMode.localStub,
        message:
            'Local premium verification is unavailable outside debug builds.',
      );
    }

    if (purchase.productID != expectedProductId) {
      return const PremiumVerificationResult.rejected(
        mode: PremiumVerificationMode.localStub,
        message: 'Unexpected premium product ID.',
      );
    }

    final receiptPayload =
        purchase.verificationData.serverVerificationData.trim().isNotEmpty
            ? purchase.verificationData.serverVerificationData.trim()
            : purchase.verificationData.localVerificationData.trim();

    if (receiptPayload.isEmpty) {
      return const PremiumVerificationResult.rejected(
        mode: PremiumVerificationMode.localStub,
        message: 'Purchase receipt data is missing.',
      );
    }

    // Temporary development bridge only. Keep this separate from the backend
    // verification implementation until server receipt validation is wired.
    return PremiumVerificationResult.verified(
      mode: PremiumVerificationMode.localStub,
      purchasedProductId: purchase.productID,
      message: 'Temporary local stub verification is active.',
    );
  }
}

abstract class PremiumBillingGateway {
  const PremiumBillingGateway();

  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> completePurchase(PurchaseDetails purchase);
  Future<void> restorePurchases();
}

class InAppPurchasePremiumBillingGateway implements PremiumBillingGateway {
  final InAppPurchase _inAppPurchase;

  InAppPurchasePremiumBillingGateway({
    InAppPurchase? inAppPurchase,
  }) : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _inAppPurchase.purchaseStream;

  @override
  Future<bool> isAvailable() => _inAppPurchase.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _inAppPurchase.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _inAppPurchase.completePurchase(purchase);

  @override
  Future<void> restorePurchases() => _inAppPurchase.restorePurchases();
}

class PremiumService extends ChangeNotifier {
  static const productId = 'sweldotrack_premium_monthly';
  static const Duration _defaultRestoreTimeout = Duration(seconds: 15);

  // Google Play IAP QA:
  // - Product ID in Play Console equals sweldotrack_premium_monthly
  // - AAB uploaded to Internal testing
  // - Tester Gmail added under Play Console license testing
  // - Tester opts in through internal testing link
  // - App installed from Google Play, not random APK, for final billing test
  // - Test card purchase approves
  // - Test card purchase declines
  // - Pending purchase does not unlock
  // - Canceled purchase does not unlock
  // - Wrong product ID does not unlock
  // - Backend rejected purchase does not unlock
  // - Verified purchase unlocks premium
  // - Restore purchase works with same Google account
  // - Restore with no purchase shows safe message
  // - Release build hides debug override
  // - No purchase tokens or receipts shown in UI/logs

  final PremiumBillingGateway _billingGateway;
  final PremiumPurchaseVerificationRepository _verificationRepository;
  final bool _allowNonBackendVerification;
  final Duration _restoreTimeout;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Completer<void>? _restorePurchasesCompleter;
  bool _initialized = false;
  bool _hasVerifiedEntitlement = false;
  bool _hasCachedPremiumState = false;
  bool _isTestPremiumOverride = false;
  bool _isPurchaseLaunchInProgress = false;
  bool _restorePurchaseDeliveredUpdate = false;
  bool _restoreStoreReportedFailure = false;
  PremiumVerificationMode? _lastVerificationMode;
  PremiumVerificationFailureKind _lastVerificationFailureKind =
      PremiumVerificationFailureKind.none;
  DateTime? _lastVerifiedAt;
  DateTime? _verifiedEntitlementExpiryDate;
  String? _lastVerificationMessage;
  bool isAvailable = false;
  bool isLoadingProduct = true;
  bool isPurchasePending = false;
  bool isRestorePending = false;
  ProductDetails? productDetails;
  String? errorMessage;
  final Set<String> _processedPurchaseUpdateKeys = <String>{};

  PremiumService({
    PremiumPurchaseVerificationRepository? verificationRepository,
    PremiumBillingGateway? billingGateway,
    bool allowNonBackendVerification = kDebugMode,
    Duration restoreTimeout = _defaultRestoreTimeout,
  })  : _verificationRepository =
            verificationRepository ?? _defaultVerificationRepository(),
        _billingGateway =
            billingGateway ?? InAppPurchasePremiumBillingGateway(),
        _allowNonBackendVerification = allowNonBackendVerification,
        _restoreTimeout = restoreTimeout;

  bool get _canUseNonBackendVerification =>
      kDebugMode && _allowNonBackendVerification;

  static PremiumPurchaseVerificationRepository
      _defaultVerificationRepository() {
    return BackendPremiumPurchaseVerificationRepository(
      backendVerificationService: BackendApiPremiumVerificationService(
        apiClient: HttpPremiumBackendApiClient(
          config: PremiumBackendVerificationConfig.fromEnvironment(),
        ),
      ),
    );
  }

  bool get isPremium => hasValidVerifiedEntitlement || _isTestPremiumOverride;
  bool get _isVerifiedEntitlementExpired {
    final expiryDate = _verifiedEntitlementExpiryDate?.toUtc();
    if (expiryDate == null) return false;
    return !expiryDate.isAfter(DateTime.now().toUtc());
  }

  bool get hasValidVerifiedEntitlement =>
      _hasVerifiedEntitlement && !_isVerifiedEntitlementExpired;

  BackendPremiumPurchaseVerificationRepository?
      get _backendVerificationRepositoryOrNull {
    final repository = _verificationRepository;
    if (repository is BackendPremiumPurchaseVerificationRepository) {
      return repository;
    }
    return null;
  }

  PremiumBackendVerificationService? get _backendVerificationServiceOrNull =>
      _backendVerificationRepositoryOrNull?.backendVerificationService;

  bool get isVerifierConfigured {
    final backendService = _backendVerificationServiceOrNull;
    if (backendService == null) return _canUseNonBackendVerification;
    return backendService.isAvailableForVerification;
  }

  bool get isAnyPremiumActionPending =>
      _isPurchaseLaunchInProgress || isPurchasePending || isRestorePending;

  bool get canPurchasePremium {
    if (!premiumLaunchEnabled) return false;
    if (isPremium) return false;
    if (isAnyPremiumActionPending) return false;
    if (!isVerifierConfigured) return false;
    if (!isAvailable) return false;
    if (productDetails == null) return false;
    return true;
  }

  bool get canRestorePremium {
    if (!premiumLaunchEnabled) return false;
    if (isAnyPremiumActionPending) return false;
    if (!isVerifierConfigured) return false;
    if (!isAvailable) return false;
    return true;
  }

  bool get isPremiumPurchaseAvailable => canPurchasePremium;

  bool get usesPendingBackendVerification => !isVerifierConfigured;

  bool get requiresBackendVerificationSetup =>
      premiumLaunchEnabled && !isVerifierConfigured;

  String get priceLabel => _normalizePremiumPriceLabel(productDetails?.price);
  PremiumVerificationMode? get lastVerificationMode => _lastVerificationMode;
  DateTime? get lastVerifiedAt => _lastVerifiedAt;
  bool get hasCachedPremiumState => _hasCachedPremiumState;
  bool get isTestPremiumOverrideEnabled => _isTestPremiumOverride;
  bool get isProductLoaded => productDetails != null;
  String get loadedProductId => productDetails?.id ?? '';
  String get loadedProductPrice => productDetails?.price.trim() ?? '';
  String? get lastVerificationMessage => _lastVerificationMessage;

  String? get purchaseUnavailableReason {
    if (!premiumLaunchEnabled) return premiumPurchasesUnavailableMessage;
    if (isPremium) return 'Premium is active on this device.';
    if (_isPurchaseLaunchInProgress || isPurchasePending) {
      return 'A premium purchase is already in progress. Please wait.';
    }
    if (isRestorePending) {
      return 'A premium restore is already in progress. Please wait.';
    }
    if (!isVerifierConfigured) return premiumPurchasesUnavailableMessage;
    if (!isAvailable) return premiumBillingUnavailableMessage;
    if (isLoadingProduct && productDetails == null) {
      return 'Premium pricing is still loading from Google Play.';
    }
    if (productDetails == null) return premiumPricingUnavailableMessage;
    return null;
  }

  String? get restoreUnavailableReason {
    if (!premiumLaunchEnabled) return premiumRestoreUnavailableMessage;
    if (_isPurchaseLaunchInProgress || isPurchasePending) {
      return 'A premium purchase is already in progress. Please wait.';
    }
    if (isRestorePending) return 'Restore is already in progress. Please wait.';
    if (!isVerifierConfigured) return premiumRestoreUnavailableMessage;
    if (!isAvailable) return premiumBillingUnavailableMessage;
    return null;
  }

  String get premiumStatusLabel {
    if (!premiumLaunchEnabled) return premiumTemporarilyUnavailableLabel;
    if (isPremium) return 'Premium Active';
    if (_isPurchaseLaunchInProgress || isPurchasePending) {
      return 'Purchase Pending';
    }
    if (isRestorePending) return 'Checking Premium';
    if (requiresBackendVerificationSetup) {
      return premiumTemporarilyUnavailableLabel;
    }
    if (isLoadingProduct) return 'Loading Pricing';
    if (!isAvailable || !isProductLoaded) {
      return premiumTemporarilyUnavailableLabel;
    }
    switch (_lastVerificationFailureKind) {
      case PremiumVerificationFailureKind.backendFailed:
        return premiumTemporarilyUnavailableLabel;
      case PremiumVerificationFailureKind.receiptRejected:
        return 'Purchase Not Confirmed';
      case PremiumVerificationFailureKind.verifierMissing:
        return premiumTemporarilyUnavailableLabel;
      case PremiumVerificationFailureKind.none:
        break;
    }
    return 'Free';
  }

  String get premiumStatusDetail {
    if (!premiumLaunchEnabled) return premiumPurchasesUnavailableMessage;
    if (isPremium) return 'Premium is active on this device.';
    if (_isPurchaseLaunchInProgress || isPurchasePending) {
      return 'Your premium purchase is still pending in Google Play.';
    }
    if (isRestorePending) {
      return 'Checking Google Play for a previous premium purchase.';
    }
    if (requiresBackendVerificationSetup) {
      return premiumPurchasesUnavailableMessage;
    }
    if (isLoadingProduct) {
      return 'Loading the latest premium pricing from Google Play.';
    }
    if (!isAvailable) {
      return premiumBillingUnavailableMessage;
    }
    if (!isProductLoaded) {
      return premiumPricingUnavailableMessage;
    }
    if (_lastVerificationFailureKind ==
        PremiumVerificationFailureKind.verifierMissing) {
      return premiumPurchasesUnavailableMessage;
    }
    if (_lastVerificationFailureKind ==
        PremiumVerificationFailureKind.backendFailed) {
      return 'Premium verification could not be completed right now. Please try again later.';
    }
    if (_lastVerificationMessage?.trim().isNotEmpty == true) {
      return _lastVerificationMessage!.trim();
    }
    return 'Premium is available at $priceLabel.';
  }

  List<(String, String)> get developerDiagnostics => <(String, String)>[
        ('Billing available', isAvailable ? 'yes' : 'no'),
        ('Product loaded', isProductLoaded ? 'yes' : 'no'),
        (
          'Product ID loaded',
          loadedProductId.isEmpty ? 'none' : loadedProductId
        ),
        (
          'Product price loaded',
          loadedProductPrice.isEmpty ? 'none' : loadedProductPrice
        ),
        ('Verifier configured', isVerifierConfigured ? 'yes' : 'no'),
        ('Premium active', isPremium ? 'yes' : 'no'),
        ('Purchase pending', isPurchasePending ? 'yes' : 'no'),
        ('Restore pending', isRestorePending ? 'yes' : 'no'),
        ('Last verification mode', verificationModeLabel),
        (
          'Last verification message',
          (_lastVerificationMessage?.trim().isNotEmpty == true)
              ? _lastVerificationMessage!.trim()
              : 'Not available',
        ),
      ];

  String _normalizePremiumPriceLabel(String? rawPriceLabel) {
    const fallbackLabel = '\u20B1120/month';
    final label = rawPriceLabel?.trim();
    if (label == null || label.isEmpty) {
      return fallbackLabel;
    }

    final slashIndex = label.indexOf('/');
    final pricePortion =
        slashIndex >= 0 ? label.substring(0, slashIndex).trim() : label;
    final normalizedPricePortion = pricePortion.replaceFirst(
      RegExp(r'\s+$'),
      '',
    );
    final lowercaseLabel = label.toLowerCase();

    if (lowercaseLabel.contains('/month') ||
        lowercaseLabel.contains('monthly')) {
      return slashIndex >= 0
          ? '$normalizedPricePortion/month'
          : normalizedPricePortion;
    }

    // Google Play test subscriptions can expose accelerated intervals
    // like "5 minutes"; keep the customer-facing label monthly in the UI.
    if (slashIndex >= 0 ||
        lowercaseLabel.contains('minute') ||
        lowercaseLabel.contains('hour') ||
        lowercaseLabel.contains('day') ||
        lowercaseLabel.contains('week') ||
        lowercaseLabel.contains('test')) {
      return '$normalizedPricePortion/month';
    }

    return '$normalizedPricePortion/month';
  }

  String get premiumActionLabel {
    if (isPremium) return 'Premium Active';
    if (_isPurchaseLaunchInProgress || isPurchasePending) {
      return 'Purchase Pending';
    }
    if (!premiumLaunchEnabled) {
      return premiumTemporarilyUnavailableActionLabel;
    }
    if (requiresBackendVerificationSetup) {
      return premiumTemporarilyUnavailableActionLabel;
    }
    if (isLoadingProduct) return 'Loading Pricing';
    if (!isAvailable || productDetails == null) {
      return premiumTemporarilyUnavailableActionLabel;
    }
    if (_lastVerificationFailureKind ==
            PremiumVerificationFailureKind.backendFailed ||
        _lastVerificationFailureKind ==
            PremiumVerificationFailureKind.verifierMissing) {
      return premiumTemporarilyUnavailableActionLabel;
    }
    return 'Upgrade to Premium - $priceLabel';
  }

  String get premiumPurchaseAvailabilityMessage {
    return purchaseUnavailableReason ?? premiumStatusDetail;
  }

  String get premiumRestoreAvailabilityMessage {
    final unavailableReason = restoreUnavailableReason;
    if (unavailableReason != null) {
      return unavailableReason;
    }
    if (_lastVerificationFailureKind ==
        PremiumVerificationFailureKind.backendFailed) {
      return 'Premium verification could not be completed right now. Please try Restore again later.';
    }
    return 'Restore your previous premium purchase from Google Play.';
  }

  String get verificationModeLabel {
    if (_isTestPremiumOverride) return 'Debug Override';
    switch (_lastVerificationMode) {
      case PremiumVerificationMode.backend:
        return 'Backend';
      case PremiumVerificationMode.localStub:
        return 'Local Stub';
      case null:
        return _hasCachedPremiumState ? 'Cached Only' : 'Not verified';
    }
  }

  PremiumVerificationFailureKind _classifyVerificationFailure(
    String? message,
  ) {
    final normalized = (message ?? '').trim();
    if (normalized.isEmpty) {
      return PremiumVerificationFailureKind.backendFailed;
    }
    final lower = normalized.toLowerCase();
    if (lower.contains('missing authentication') ||
        lower.contains('missing a secure https url') ||
        lower.contains('missing a secure url') ||
        lower.contains('must use https') ||
        lower.contains('malformed') ||
        lower.contains('secure purchase verification is not ready yet') ||
        lower.contains('verification is unavailable in this build')) {
      return PremiumVerificationFailureKind.verifierMissing;
    }
    if (_looksLikeReceiptRejectedMessage(normalized)) {
      return PremiumVerificationFailureKind.receiptRejected;
    }
    return PremiumVerificationFailureKind.backendFailed;
  }

  void _recordVerificationResult(PremiumVerificationResult verification) {
    _lastVerificationMode = verification.mode;
    final normalizedMessage = verification.message?.trim();
    _lastVerificationMessage = verification.isVerified && verification.isActive
        ? 'Premium activated successfully.'
        : normalizedMessage == null || normalizedMessage.isEmpty
            ? null
            : normalizedMessage;
    _lastVerificationFailureKind =
        verification.isVerified && verification.isActive
            ? PremiumVerificationFailureKind.none
            : _classifyVerificationFailure(_lastVerificationMessage);
    _debugPremiumLog(
      'verification result: mode=${verification.mode.name}, verified=${verification.isVerified}, active=${verification.isActive}, failure=${_lastVerificationFailureKind.name}',
    );
  }

  void _clearVerificationFailureState() {
    _lastVerificationFailureKind = PremiumVerificationFailureKind.none;
    _lastVerificationMessage = null;
  }

  Future<void> initialize() async {
    if (_initialized) {
      await refreshStoreState();
      return;
    }

    _initialized = true;
    await _loadLocalStatus();

    if (!premiumLaunchEnabled) {
      isAvailable = false;
      isLoadingProduct = false;
      isPurchasePending = false;
      isRestorePending = false;
      productDetails = null;
      errorMessage = null;
      notifyListeners();
      return;
    }

    _purchaseSubscription = _billingGateway.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (Object error) {
        _debugPremiumLog('billing stream error');
        _isPurchaseLaunchInProgress = false;
        isPurchasePending = false;
        isRestorePending = false;
        errorMessage = premiumBillingUnavailableMessage;
        _completeRestoreFlow(storeReportedFailure: true);
        notifyListeners();
      },
    );

    await refreshStoreState();
    await _restoreOwnedPurchasesOnStartup();
  }

  Future<void> refreshStoreState() async {
    if (!premiumLaunchEnabled) {
      isAvailable = false;
      isLoadingProduct = false;
      isPurchasePending = false;
      isRestorePending = false;
      productDetails = null;
      errorMessage = null;
      notifyListeners();
      return;
    }

    errorMessage = null;
    isLoadingProduct = true;
    notifyListeners();

    try {
      isAvailable = await _billingGateway.isAvailable();
      _debugPremiumLog('billing availability checked: available=$isAvailable');
      if (!isAvailable) {
        productDetails = null;
        errorMessage = premiumBillingUnavailableMessage;
        isLoadingProduct = false;
        notifyListeners();
        return;
      }

      final response = await _billingGateway.queryProductDetails({productId});
      _debugPremiumLog(
        'product query completed: found=${response.productDetails.isNotEmpty}, notFoundCount=${response.notFoundIDs.length}, errorPresent=${response.error != null}',
      );
      if (response.error != null) {
        errorMessage = premiumPricingUnavailableMessage;
      }
      if (response.productDetails.isEmpty) {
        productDetails = null;
        errorMessage ??= premiumPricingUnavailableMessage;
      } else {
        final matchingProducts = response.productDetails
            .where((product) => product.id == productId)
            .toList();
        if (matchingProducts.isEmpty) {
          productDetails = null;
          errorMessage = premiumPricingUnavailableMessage;
          _debugPremiumLog('product query mismatch: expected=$productId');
        } else {
          final matchingProduct = matchingProducts.first;
          productDetails = matchingProduct;
          _debugPremiumLog(
            'product loaded: id=${matchingProduct.id}, priceLabel=${_normalizePremiumPriceLabel(matchingProduct.price)}',
          );
          errorMessage = null;
        }
      }
    } catch (_) {
      productDetails = null;
      isAvailable = false;
      errorMessage = premiumBillingUnavailableMessage;
    }

    isLoadingProduct = false;
    notifyListeners();
  }

  Future<void> reloadLocalStatus() async {
    await _loadLocalStatus();
    notifyListeners();
  }

  Future<void> setTestPremiumEnabled(bool value) async {
    if (!kDebugMode) return;
    await _setTestPremiumOverride(value);
    notifyListeners();
  }

  Future<void> clearLocalPremiumTestingCache() async {
    if (!kDebugMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppKeys.premiumActive);
    await prefs.remove(AppKeys.premiumLastProductId);
    await prefs.remove(AppKeys.premiumLastVerifiedAt);
    await prefs.remove(AppKeys.premiumLastExpiryDate);
    await prefs.remove(AppKeys.premiumLastVerificationMode);
    await prefs.remove(AppKeys.premiumTestOverride);

    _hasVerifiedEntitlement = false;
    _hasCachedPremiumState = false;
    _isTestPremiumOverride = false;
    _lastVerificationMode = null;
    _lastVerifiedAt = null;
    _verifiedEntitlementExpiryDate = null;
    _clearVerificationFailureState();
    errorMessage = null;
    notifyListeners();
  }

  Future<void> buyPremium() async {
    errorMessage = null;
    _debugPremiumLog(
      'purchase requested: premium=$isPremium, pending=$isPurchasePending, verifierConfigured=$isVerifierConfigured, billingAvailable=$isAvailable, productLoaded=$isProductLoaded',
    );

    final unavailableReason = purchaseUnavailableReason;
    if (unavailableReason != null) {
      errorMessage = unavailableReason;
      notifyListeners();
      return;
    }

    _clearVerificationFailureState();
    _isPurchaseLaunchInProgress = true;
    notifyListeners();

    try {
      final purchaseParam = PurchaseParam(productDetails: productDetails!);
      final launched = await _billingGateway.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      _debugPremiumLog('purchase launch result: launched=$launched');
      if (!launched) {
        _isPurchaseLaunchInProgress = false;
        isPurchasePending = false;
        errorMessage = premiumPurchaseStartFailedMessage;
        notifyListeners();
        return;
      }
      _isPurchaseLaunchInProgress = false;
      isPurchasePending = true;
      notifyListeners();
    } catch (_) {
      _isPurchaseLaunchInProgress = false;
      isPurchasePending = false;
      errorMessage = premiumPurchaseStartFailedMessage;
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    errorMessage = null;
    final unavailableReason = restoreUnavailableReason;
    if (unavailableReason != null) {
      errorMessage = unavailableReason;
      notifyListeners();
      return;
    }

    _debugPremiumLog(
      'restore requested: verifierConfigured=$isVerifierConfigured, billingAvailable=$isAvailable',
    );

    await _restorePurchasesInternal(
      showBusyState: true,
      showNoPurchasesMessage: true,
    );
  }

  Future<void> _loadLocalStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _hasCachedPremiumState = prefs.getBool(AppKeys.premiumActive) ?? false;
    _isTestPremiumOverride =
        kDebugMode && (prefs.getBool(AppKeys.premiumTestOverride) ?? false);
    _lastVerifiedAt = parseStoredIsoDate(
      prefs.getString(AppKeys.premiumLastVerifiedAt),
    );
    _verifiedEntitlementExpiryDate = parseStoredIsoDate(
      prefs.getString(AppKeys.premiumLastExpiryDate),
    )?.toUtc();
    final storedMode = prefs.getString(AppKeys.premiumLastVerificationMode);
    PremiumVerificationMode? resolvedMode;
    for (final mode in PremiumVerificationMode.values) {
      if (mode.name == storedMode) {
        resolvedMode = mode;
        break;
      }
    }
    _lastVerificationMode = resolvedMode;
    _clearVerificationFailureState();

    final cachedProductId =
        (prefs.getString(AppKeys.premiumLastProductId) ?? '').trim();
    final cachedModeIsInvalid = _hasCachedPremiumState &&
        (resolvedMode == null ||
            (resolvedMode == PremiumVerificationMode.localStub && !kDebugMode));
    final cachedProductIsInvalid =
        _hasCachedPremiumState && cachedProductId != productId;

    if (_isVerifiedEntitlementExpired ||
        cachedModeIsInvalid ||
        cachedProductIsInvalid) {
      await prefs.remove(AppKeys.premiumActive);
      await prefs.remove(AppKeys.premiumLastProductId);
      await prefs.remove(AppKeys.premiumLastVerifiedAt);
      await prefs.remove(AppKeys.premiumLastExpiryDate);
      await prefs.remove(AppKeys.premiumLastVerificationMode);
      _hasCachedPremiumState = false;
      _lastVerificationMode = null;
      _lastVerifiedAt = null;
      _verifiedEntitlementExpiryDate = null;
    }

    _hasVerifiedEntitlement = _hasCachedPremiumState &&
        (resolvedMode == PremiumVerificationMode.backend ||
            (resolvedMode == PremiumVerificationMode.localStub && kDebugMode));
  }

  Future<void> _setTestPremiumOverride(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppKeys.premiumTestOverride, value);
    _isTestPremiumOverride = value;
  }

  Future<void> _persistPremiumCache(
    bool value, {
    String? purchasedProductId,
    PremiumVerificationMode? verificationMode,
    DateTime? expiryDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppKeys.premiumActive, value);
    final normalizedProductId = value
        ? ((purchasedProductId ?? '').trim().isEmpty
            ? productId
            : purchasedProductId!.trim())
        : (purchasedProductId ?? '').trim();
    if (normalizedProductId.isEmpty) {
      await prefs.remove(AppKeys.premiumLastProductId);
    } else {
      await prefs.setString(AppKeys.premiumLastProductId, normalizedProductId);
    }
    if (verificationMode == null) {
      await prefs.remove(AppKeys.premiumLastVerificationMode);
    } else {
      await prefs.setString(
        AppKeys.premiumLastVerificationMode,
        verificationMode.name,
      );
    }
    if (value) {
      _lastVerificationMode = verificationMode;
      _lastVerifiedAt = DateTime.now();
      _verifiedEntitlementExpiryDate = expiryDate?.toUtc();
      _lastVerificationFailureKind = PremiumVerificationFailureKind.none;
      await prefs.setString(
        AppKeys.premiumLastVerifiedAt,
        _lastVerifiedAt!.toIso8601String(),
      );
      if (_verifiedEntitlementExpiryDate != null) {
        await prefs.setString(
          AppKeys.premiumLastExpiryDate,
          _verifiedEntitlementExpiryDate!.toIso8601String(),
        );
      } else {
        await prefs.remove(AppKeys.premiumLastExpiryDate);
      }
    } else {
      _lastVerificationMode = verificationMode;
      _lastVerifiedAt = null;
      _verifiedEntitlementExpiryDate = null;
      await prefs.remove(AppKeys.premiumLastVerifiedAt);
      await prefs.remove(AppKeys.premiumLastExpiryDate);
    }
    _hasCachedPremiumState = value;
  }

  Future<void> _revokePremiumAccess({
    PremiumVerificationMode? verificationMode,
    String? message,
  }) async {
    _hasVerifiedEntitlement = false;
    await _persistPremiumCache(
      false,
      verificationMode: verificationMode,
    );
    if (message != null && message.trim().isNotEmpty) {
      final normalizedMessage = message.trim();
      _lastVerificationMessage = normalizedMessage;
      _lastVerificationFailureKind = _classifyVerificationFailure(
        normalizedMessage,
      );
      errorMessage = normalizedMessage;
    }
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    if (purchases.isEmpty) {
      _completeRestoreFlow();
      notifyListeners();
      return;
    }

    for (final purchase in purchases) {
      _debugPremiumLog(
          'purchase update received: status=${purchase.status.name}');
      if (purchase.productID != productId) {
        if (purchase.pendingCompletePurchase &&
            purchase.status != PurchaseStatus.pending) {
          await _completePurchaseSafely(purchase);
        }
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          errorMessage = null;
          _isPurchaseLaunchInProgress = false;
          isPurchasePending = true;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final purchaseUpdateKey = _purchaseUpdateKey(purchase);
          final isDuplicateUpdate = _processedPurchaseUpdateKeys.contains(
            purchaseUpdateKey,
          );
          if (isDuplicateUpdate) {
            _debugPremiumLog(
              'purchase update ignored: duplicate ${purchase.status.name}',
            );
            if (purchase.status == PurchaseStatus.restored) {
              _completeRestoreFlow(restoredPurchaseDelivered: true);
            }
            break;
          }
          _processedPurchaseUpdateKeys.add(purchaseUpdateKey);
          errorMessage = null;
          _isPurchaseLaunchInProgress = false;
          final verification = await _verifyPurchase(purchase);
          _recordVerificationResult(verification);
          if (verification.isVerified && verification.isActive) {
            _hasVerifiedEntitlement = true;
            await _persistPremiumCache(
              true,
              purchasedProductId:
                  verification.purchasedProductId ?? purchase.productID,
              verificationMode: verification.mode,
              expiryDate: verification.expiryDate,
            );
          } else {
            await _revokePremiumAccess(
              verificationMode: verification.mode,
              message: _resolveVerificationFailureMessage(
                verification,
                useRestoreCopy: purchase.status == PurchaseStatus.restored,
              ),
            );
          }
          isPurchasePending = false;
          if (purchase.status == PurchaseStatus.restored) {
            _completeRestoreFlow(restoredPurchaseDelivered: true);
          }
          break;
        case PurchaseStatus.error:
          _isPurchaseLaunchInProgress = false;
          isPurchasePending = false;
          errorMessage = _resolvePurchaseFailureMessage(purchase);
          if (isRestorePending) {
            _completeRestoreFlow(storeReportedFailure: true);
          }
          break;
        case PurchaseStatus.canceled:
          _isPurchaseLaunchInProgress = false;
          isPurchasePending = false;
          errorMessage = premiumPurchaseCanceledMessage;
          if (isRestorePending) {
            _completeRestoreFlow(storeReportedFailure: true);
          }
          break;
      }

      if (purchase.pendingCompletePurchase &&
          purchase.status != PurchaseStatus.pending) {
        await _completePurchaseSafely(purchase);
      }
    }

    notifyListeners();
  }

  Future<PremiumVerificationResult> _verifyPurchase(
    PurchaseDetails purchase,
  ) async {
    if (_verificationRepository
            is! BackendPremiumPurchaseVerificationRepository &&
        !_canUseNonBackendVerification) {
      _debugPremiumLog(
          'verification rejected: local stub blocked outside debug');
      return const PremiumVerificationResult.rejected(
        mode: PremiumVerificationMode.localStub,
        message: premiumPurchasesUnavailableMessage,
      );
    }
    if (!_canUseNonBackendVerification &&
        _backendVerificationServiceOrNull == null) {
      _debugPremiumLog(
          'verification rejected: no backend verification service');
      return const PremiumVerificationResult.rejected(
        mode: PremiumVerificationMode.backend,
        message: premiumPurchasesUnavailableMessage,
      );
    }
    return _verificationRepository.verifyPurchase(
      purchase: purchase,
      expectedProductId: productId,
    );
  }

  Future<void> _restoreOwnedPurchasesOnStartup() async {
    if (defaultTargetPlatform != TargetPlatform.android || !isAvailable) {
      return;
    }
    if (!isVerifierConfigured) {
      _debugPremiumLog('startup restore skipped: verifier not configured');
      return;
    }

    await _restorePurchasesInternal(
      showBusyState: false,
      showNoPurchasesMessage: false,
    );
  }

  Future<void> _restorePurchasesInternal({
    required bool showBusyState,
    required bool showNoPurchasesMessage,
  }) async {
    errorMessage = null;

    if (!isAvailable) {
      if (showBusyState) {
        errorMessage = premiumBillingUnavailableMessage;
        notifyListeners();
      }
      return;
    }

    if (_restorePurchasesCompleter != null) {
      if (showBusyState) {
        isRestorePending = true;
        notifyListeners();
      }
      await _restorePurchasesCompleter!.future;
      return;
    }

    _restorePurchasesCompleter = Completer<void>();
    _restorePurchaseDeliveredUpdate = false;
    _restoreStoreReportedFailure = false;

    if (showBusyState) {
      isRestorePending = true;
      notifyListeners();
    }

    try {
      await _billingGateway.restorePurchases();
      await _restorePurchasesCompleter!.future.timeout(_restoreTimeout);

      if (!_restorePurchaseDeliveredUpdate &&
          !_restoreStoreReportedFailure &&
          showNoPurchasesMessage) {
        errorMessage = premiumNoPreviousPurchaseMessage;
      }
    } on TimeoutException {
      if (showNoPurchasesMessage) {
        errorMessage = premiumNoPreviousPurchaseMessage;
      }
    } catch (_) {
      errorMessage = 'Restore failed. Please try again.';
    } finally {
      if (_restorePurchasesCompleter != null &&
          !_restorePurchasesCompleter!.isCompleted) {
        _restorePurchasesCompleter!.complete();
      }
      _restorePurchasesCompleter = null;
      _restorePurchaseDeliveredUpdate = false;
      _restoreStoreReportedFailure = false;
      isRestorePending = false;

      if (showBusyState) {
        notifyListeners();
      } else if (errorMessage != null) {
        notifyListeners();
      }
    }
  }

  void _completeRestoreFlow({
    bool restoredPurchaseDelivered = false,
    bool storeReportedFailure = false,
  }) {
    if (_restorePurchasesCompleter == null) return;
    if (restoredPurchaseDelivered) {
      _restorePurchaseDeliveredUpdate = true;
    }
    if (storeReportedFailure) {
      _restoreStoreReportedFailure = true;
    }
    if (!_restorePurchasesCompleter!.isCompleted) {
      _restorePurchasesCompleter!.complete();
    }
  }

  String _resolvePurchaseFailureMessage(PurchaseDetails purchase) {
    final errorCode = purchase.error?.code.toLowerCase() ?? '';
    final errorText = (purchase.error?.message ?? '').trim();
    final normalizedError = '$errorCode $errorText'.toLowerCase();
    _debugPremiumLog(
      'purchase failure resolved: code=${purchase.error?.code ?? 'unknown'}, status=${purchase.status.name}',
    );

    if (normalizedError.contains('cancel')) {
      return premiumPurchaseCanceledMessage;
    }

    if (normalizedError.contains('billing unavailable') ||
        normalizedError.contains('billing_unavailable')) {
      return premiumBillingUnavailableMessage;
    }

    if (normalizedError.contains('item already owned') ||
        normalizedError.contains('already_owned')) {
      return 'This Google Play account already has this premium purchase. Try Restore.';
    }

    if (normalizedError.contains('network')) {
      return 'Purchase could not be confirmed because the network is unavailable.';
    }

    return 'Purchase failed. Please try again.';
  }

  String _purchaseUpdateKey(PurchaseDetails purchase) {
    final purchaseId = (purchase.purchaseID ?? '').trim();
    final transactionDate = (purchase.transactionDate ?? '').trim();
    return '${purchase.productID}|$purchaseId|$transactionDate|${purchase.status.name}';
  }

  String _resolveVerificationFailureMessage(
    PremiumVerificationResult verification, {
    required bool useRestoreCopy,
  }) {
    switch (_classifyVerificationFailure(verification.message)) {
      case PremiumVerificationFailureKind.verifierMissing:
        return useRestoreCopy
            ? premiumRestoreUnavailableMessage
            : premiumPurchasesUnavailableMessage;
      case PremiumVerificationFailureKind.receiptRejected:
        return premiumPurchaseNotConfirmedMessage;
      case PremiumVerificationFailureKind.backendFailed:
        return useRestoreCopy
            ? 'Premium restore could not be confirmed right now. Please try again later.'
            : 'Premium verification could not be completed right now. Please try again later.';
      case PremiumVerificationFailureKind.none:
        final normalizedMessage = verification.message?.trim();
        if (normalizedMessage != null && normalizedMessage.isNotEmpty) {
          return normalizedMessage;
        }
        return premiumPurchaseNotConfirmedMessage;
    }
  }

  Future<void> _completePurchaseSafely(PurchaseDetails purchase) async {
    try {
      await _billingGateway.completePurchase(purchase);
    } catch (_) {
      errorMessage ??=
          'Your purchase needs a moment to finish syncing with Google Play.';
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}

// -----------------------------------------------------------------------------
// Onboarding / Welcome setup
// -----------------------------------------------------------------------------

// Asset-backed onboarding and welcome setup illustrations.
const bool _useOnboardingAssetIllustrations = true;
const String _welcomeSetupAssetPath = 'assets/images/setup_profile.png';
const Color _premiumOnboardingBackground = Color(0xFF050B1D);

class _OnboardingPageData {
  final String assetPath;

  const _OnboardingPageData({
    required this.assetPath,
  });
}

class _PremiumFlowBackground extends StatelessWidget {
  final Widget child;

  const _PremiumFlowBackground({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF081127),
            _premiumOnboardingBackground,
            Color(0xFF030714),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -40,
            child: IgnorePointer(
              child: Container(
                height: 260,
                width: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: intelliumBlue.withValues(alpha: .14),
                  boxShadow: [
                    BoxShadow(
                      color: intelliumBlue.withValues(alpha: .24),
                      blurRadius: 90,
                      spreadRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 180,
            right: -70,
            child: IgnorePointer(
              child: Container(
                height: 240,
                width: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: intelliumPurple.withValues(alpha: .12),
                  boxShadow: [
                    BoxShadow(
                      color: intelliumPurple.withValues(alpha: .22),
                      blurRadius: 96,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: 40,
            child: IgnorePointer(
              child: Container(
                height: 220,
                width: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: intelliumCyan.withValues(alpha: .10),
                  boxShadow: [
                    BoxShadow(
                      color: intelliumCyan.withValues(alpha: .18),
                      blurRadius: 88,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _OnboardingFlowSheet extends StatefulWidget {
  final Future<void> Function() onFinish;

  const _OnboardingFlowSheet({
    required this.onFinish,
  });

  @override
  State<_OnboardingFlowSheet> createState() => _OnboardingFlowSheetState();
}

const List<_OnboardingPageData> _onboardingPages = <_OnboardingPageData>[
  _OnboardingPageData(
    assetPath: 'assets/images/onboarding_bills.png',
  ),
  _OnboardingPageData(
    assetPath: 'assets/images/onboarding_budget.png',
  ),
  _OnboardingPageData(
    assetPath: 'assets/images/onboarding_expenses.png',
  ),
  _OnboardingPageData(
    assetPath: 'assets/images/onboarding_premium.png',
  ),
  _OnboardingPageData(
    assetPath: 'assets/images/onboarding_income.png',
  ),
  _OnboardingPageData(
    assetPath: 'assets/images/onboarding_dashboard.png',
  ),
];

class _OnboardingFlowSheetState extends State<_OnboardingFlowSheet> {
  late final PageController _pageController;
  int _currentPage = 0;
  bool _finishing = false;

  bool get _isLastPage => _currentPage == _onboardingPages.length - 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToNextPage() async {
    if (_finishing) return;
    if (_isLastPage) {
      setState(() => _finishing = true);
      await widget.onFinish();
      if (!mounted) return;
      setState(() => _finishing = false);
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _skipOnboarding() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await widget.onFinish();
    if (!mounted) return;
    setState(() => _finishing = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = min(screenHeight * .96, 920.0);

    return ColoredBox(
      color: const Color(0xFF030714),
      child: SizedBox(
        height: sheetHeight,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _onboardingPages.length,
                      onPageChanged: (index) {
                        if (!mounted) return;
                        setState(() => _currentPage = index);
                      },
                      itemBuilder: (context, index) {
                        return _OnboardingPageView(
                          page: _onboardingPages[index],
                        );
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _finishing ? null : _skipOnboarding,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _finishing ? null : _goToNextPage,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        _finishing
                            ? 'Please wait...'
                            : _isLastPage
                                ? 'Get Started'
                                : 'Next',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPageData page;

  const _OnboardingPageView({
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Center(
            child: Image.asset(
              page.assetPath,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        );
      },
    );
  }
}

class _PremiumIllustrationAsset extends StatelessWidget {
  final String assetPath;
  final String? fallbackAssetPath;
  final BoxFit fit;
  final Alignment alignment;

  const _PremiumIllustrationAsset({
    required this.assetPath,
    this.fallbackAssetPath,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    if (!_useOnboardingAssetIllustrations) {
      return const _OnboardingIllustrationPlaceholder();
    }

    Widget placeholder() {
      return const _OnboardingIllustrationPlaceholder();
    }

    return Image.asset(
      assetPath,
      fit: fit,
      alignment: alignment,
      errorBuilder: (context, error, stackTrace) {
        final fallbackPath = fallbackAssetPath;
        if (fallbackPath == null || fallbackPath == assetPath) {
          return placeholder();
        }
        return Image.asset(
          fallbackPath,
          fit: fit,
          alignment: alignment,
          errorBuilder: (context, error, stackTrace) {
            return placeholder();
          },
        );
      },
    );
  }
}

class _OnboardingIllustrationPlaceholder extends StatelessWidget {
  const _OnboardingIllustrationPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF071224),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white70,
          size: 42,
        ),
      ),
    );
  }
}

class _PremiumGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final List<Color> gradientColors;
  final IconData? trailingIcon;
  final bool isLoading;

  const _PremiumGradientButton({
    required this.label,
    required this.onPressed,
    required this.gradientColors,
    this.trailingIcon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: gradientColors.last.withValues(alpha: .26),
                  blurRadius: 26,
                  spreadRadius: -6,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white.withValues(alpha: .72),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(60),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            if (trailingIcon != null && !isLoading) ...[
              const SizedBox(width: 10),
              Icon(trailingIcon, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _PremiumInfoCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _PremiumInfoCard({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .045),
            _premiumOnboardingBackground.withValues(alpha: .18),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [intelliumBlue, intelliumPurple],
              ),
              boxShadow: [
                BoxShadow(
                  color: intelliumPurple.withValues(alpha: .22),
                  blurRadius: 14,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: ui.textSecondary,
                fontSize: 12.9,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeHeroCard extends StatelessWidget {
  final double height;

  const _WelcomeHeroCard({
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _PremiumIllustrationAsset(
              assetPath: _welcomeSetupAssetPath,
              fallbackAssetPath: _onboardingPages.first.assetPath,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      _premiumOnboardingBackground.withValues(alpha: .10),
                      _premiumOnboardingBackground.withValues(alpha: .85),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumFieldLabel extends StatelessWidget {
  final String text;

  const _PremiumFieldLabel({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13.8,
        fontWeight: FontWeight.w800,
        letterSpacing: .15,
      ),
    );
  }
}

InputDecoration _buildPremiumWelcomeInputDecoration({
  String? labelText,
  required String hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide(color: color, width: 1.15),
    );
  }

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    floatingLabelBehavior: labelText == null
        ? FloatingLabelBehavior.never
        : FloatingLabelBehavior.auto,
    labelStyle: const TextStyle(
      color: intelliumTextPrimary,
      fontWeight: FontWeight.w600,
    ),
    hintStyle: const TextStyle(
      color: intelliumTextMuted,
      fontWeight: FontWeight.w500,
    ),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xFF0A1531),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
    enabledBorder: border(intelliumBlue.withValues(alpha: .32)),
    focusedBorder: border(intelliumCyan.withValues(alpha: .82)),
    errorBorder: border(const Color(0xFFFF7FA3)),
    focusedErrorBorder: border(const Color(0xFFFF7FA3)),
    border: border(intelliumBlue.withValues(alpha: .28)),
  );
}

// -----------------------------------------------------------------------------
// Main navigation
// -----------------------------------------------------------------------------

class MainNavigationScreen extends StatefulWidget {
  final PremiumService premiumService;
  final AppThemeController themeController;

  const MainNavigationScreen({
    super.key,
    required this.premiumService,
    required this.themeController,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  static const int _navHome = 0;
  static const int _navAnalytics = 1;
  static const int _navTrack = 2;
  static const int _navTools = 3;
  static const int _navSettings = 4;

  static const int _pageHome = 0;
  static const int _pageAnalytics = 1;
  static const int _pageTools = 2;
  static const int _pageSettings = 3;

  int currentIndex = 0;
  int refreshKey = 0;
  bool welcomeDialogOpen = false;
  bool onboardingDialogOpen = false;

  int get activeNavIndex {
    switch (currentIndex) {
      case _pageHome:
        return _navHome;
      case _pageAnalytics:
        return _navAnalytics;
      case _pageTools:
        return _navTools;
      case _pageSettings:
        return _navSettings;
      default:
        return _navHome;
    }
  }

  int? _pageIndexForNavSlot(int navIndex) {
    switch (navIndex) {
      case _navHome:
        return _pageHome;
      case _navAnalytics:
        return _pageAnalytics;
      case _navTools:
        return _pageTools;
      case _navSettings:
        return _pageSettings;
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    maybeShowOnboarding();
  }

  void refreshAll() {
    if (!mounted) return;
    setState(() {
      refreshKey++;
    });
    unawaited(widget.premiumService.reloadLocalStatus());
    unawaited(widget.themeController.load());
    maybeShowOnboarding();
  }

  Future<void> maybeShowOnboarding() async {
    final isFirstLaunch = await FinanceRepository.ensureInstallMarker();
    final onboardingComplete = await FinanceRepository.isOnboardingComplete();
    final hasSavedFinanceData =
        await FinanceRepository.hasAnySavedFinanceData();
    final preferredName = await FinanceRepository.getPreferredName();
    if (!mounted || onboardingDialogOpen) return;

    if (kDebugMode) {
      debugPrint(
        'SweldoTrack launch state: '
        'firstLaunch=$isFirstLaunch, '
        'onboardingComplete=$onboardingComplete, '
        'preferredNameEmpty=${preferredName.isEmpty}, '
        'hasSavedFinanceData=$hasSavedFinanceData',
      );
    }

    if (onboardingComplete) {
      await maybeShowWelcome();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || onboardingDialogOpen || welcomeDialogOpen) return;
      showOnboardingDialog();
    });
  }

  Future<void> maybeShowWelcome() async {
    final onboardingComplete = await FinanceRepository.isOnboardingComplete();
    final preferredName = await FinanceRepository.getPreferredName();
    if (!onboardingComplete ||
        preferredName.isNotEmpty ||
        welcomeDialogOpen ||
        onboardingDialogOpen ||
        !mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || welcomeDialogOpen || onboardingDialogOpen) {
        return;
      }
      showWelcomeDialog();
    });
  }

  Future<void> showOnboardingDialog() async {
    onboardingDialogOpen = true;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        builder: (sheetContext) => PopScope(
          canPop: false,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: _OnboardingFlowSheet(
                onFinish: () async {
                  await FinanceRepository.setOnboardingComplete(true);
                  if (!sheetContext.mounted) return;
                  Navigator.pop(sheetContext);
                },
              ),
            ),
          ),
        ),
      );
    } finally {
      onboardingDialogOpen = false;
    }

    await maybeShowWelcome();
  }

  Future<void> showWelcomeDialog() async {
    final controller = TextEditingController();
    final startingBalanceController = TextEditingController();
    final cutoffDateController = TextEditingController();
    final existingPreferredName = await FinanceRepository.getPreferredName();
    final existingStartingBalance =
        await FinanceRepository.getStartingBalance();
    final existingNextCutoffDate = await FinanceRepository.getNextPaydayDate();
    if (existingPreferredName.isNotEmpty) {
      controller.text = existingPreferredName;
    }
    if (existingStartingBalance > 0) {
      startingBalanceController.text =
          NumberFormat('#,##0.##').format(existingStartingBalance);
    }
    if (existingNextCutoffDate != null) {
      cutoffDateController.text =
          formatCalendarDate(dateOnly(existingNextCutoffDate));
    }
    if (!mounted) {
      controller.dispose();
      startingBalanceController.dispose();
      cutoffDateController.dispose();
      return;
    }
    final ui = SweldoVisualStyle.fromContext(context);
    welcomeDialogOpen = true;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        builder: (sheetContext) {
          DateTime? nextCutoffDate = existingNextCutoffDate == null
              ? null
              : dateOnly(existingNextCutoffDate);
          String? validationMessage;
          var saving = false;

          return StatefulBuilder(
            builder: (context, setSheetState) {
              void syncCutoffDateField() {
                cutoffDateController.text = nextCutoffDate == null
                    ? ''
                    : formatCalendarDate(nextCutoffDate!);
              }

              Future<void> pickNextCutoffDate() async {
                if (saving) return;
                FocusScope.of(sheetContext).unfocus();
                final now = dateOnly(DateTime.now());
                final initialDate =
                    nextCutoffDate ?? now.add(const Duration(days: 14));
                final pickedDate = await showDatePicker(
                  context: sheetContext,
                  initialDate: initialDate,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 3650)),
                );
                if (!sheetContext.mounted) return;
                if (pickedDate == null) return;
                setSheetState(() {
                  nextCutoffDate = dateOnly(pickedDate);
                  syncCutoffDateField();
                });
              }

              Future<void> submitWelcome() async {
                if (saving) return;
                final name = controller.text.trim();
                final amountError = validatePesoAmountInput(
                  startingBalanceController.text,
                  fieldLabel: 'opening available balance',
                  allowZero: true,
                );
                if (name.isEmpty) {
                  setSheetState(
                    () => validationMessage = 'Preferred name is required',
                  );
                  return;
                }
                if (amountError != null) {
                  setSheetState(() => validationMessage = amountError);
                  return;
                }
                final startingBalance = parseMoneyInput(
                  startingBalanceController.text,
                )!;
                setSheetState(() => saving = true);
                FocusScope.of(context).unfocus();
                await FinanceRepository.setPreferredName(name);
                await FinanceRepository.setStartingBalance(startingBalance);
                await FinanceRepository.saveBalanceSetup(
                  startingBalance: startingBalance,
                  daysUntilPayday: nextCutoffDate == null
                      ? 0
                      : calculateRemainingSweldoDays(
                          nextPaydayDate: nextCutoffDate,
                          fallbackDaysUntilPayday: 0,
                        ),
                  savingsGoalTarget: await FinanceRepository.getSavingsGoal(),
                  cycleStartDate: dateOnly(DateTime.now()),
                  nextCutoffDate: nextCutoffDate,
                  useManualDailyBudget: false,
                );
                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);
              }

              final typedName = controller.text.trim();
              final welcomeName = typedName.isEmpty ? 'User' : typedName;
              final heroHeight = (MediaQuery.of(context).size.height * .36)
                  .clamp(230.0, 340.0)
                  .toDouble();

              return PopScope(
                canPop: false,
                child: _PremiumFlowBackground(
                  child: SafeArea(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        10,
                        20,
                        MediaQuery.of(sheetContext).viewInsets.bottom + 22,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 0),
                              _WelcomeHeroCard(height: heroHeight),
                              const SizedBox(height: 14),
                              const Text(
                                'Getting Started',
                                style: TextStyle(
                                  color: intelliumCyan,
                                  fontSize: 13.2,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .28,
                                ),
                              ),
                              const SizedBox(height: 8),
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: ui.textPrimary,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    height: 1.02,
                                    letterSpacing: -.8,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Welcome, '),
                                    TextSpan(
                                      text: welcomeName,
                                      style: const TextStyle(
                                        color: intelliumCyan,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Set up your profile and starting balance so SweldoTrack can track your money accurately.',
                                style: TextStyle(
                                  color: ui.textSecondary,
                                  fontSize: 14.2,
                                  height: 1.48,
                                ),
                              ),
                              const SizedBox(height: 22),
                              const _PremiumFieldLabel(
                                text: 'Preferred Name',
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: controller,
                                autofocus: true,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                                style: TextStyle(color: ui.textPrimary),
                                onChanged: (_) {
                                  setSheetState(() {
                                    if (validationMessage != null) {
                                      validationMessage = null;
                                    }
                                  });
                                },
                                decoration: _buildPremiumWelcomeInputDecoration(
                                  hintText: 'Dave',
                                  suffixIcon: const Icon(
                                    Icons.person_outline_rounded,
                                    color: intelliumCyan,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const _PremiumFieldLabel(
                                text: 'Opening Available Balance',
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: startingBalanceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                style: TextStyle(color: ui.textPrimary),
                                onChanged: (_) {
                                  setSheetState(() {
                                    if (validationMessage != null) {
                                      validationMessage = null;
                                    }
                                  });
                                },
                                decoration: _buildPremiumWelcomeInputDecoration(
                                  hintText: '10,000',
                                  prefixIcon: const Padding(
                                    padding: EdgeInsets.only(
                                      left: 18,
                                      right: 8,
                                    ),
                                    child: Center(
                                      widthFactor: 1,
                                      child: Text(
                                        '\u20B1',
                                        style: TextStyle(
                                          color: intelliumTextPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  suffixIcon: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: intelliumBlue,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'This is the money you currently have available to spend.',
                                style: TextStyle(
                                  color: ui.textMuted,
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const _PremiumFieldLabel(
                                text: 'Next Cutoff or Payday',
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: cutoffDateController,
                                readOnly: true,
                                showCursor: false,
                                enableInteractiveSelection: false,
                                onTap: saving ? null : pickNextCutoffDate,
                                style: TextStyle(color: ui.textPrimary),
                                decoration: _buildPremiumWelcomeInputDecoration(
                                  hintText: 'Optional',
                                  suffixIcon: SizedBox(
                                    width: nextCutoffDate == null ? 56 : 104,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (nextCutoffDate != null)
                                          IconButton(
                                            onPressed: saving
                                                ? null
                                                : () {
                                                    setSheetState(() {
                                                      nextCutoffDate = null;
                                                      syncCutoffDateField();
                                                    });
                                                  },
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              color: intelliumTextMuted,
                                            ),
                                            tooltip: 'Clear date',
                                          ),
                                        IconButton(
                                          onPressed: saving
                                              ? null
                                              : pickNextCutoffDate,
                                          icon: const Icon(
                                            Icons.calendar_month_outlined,
                                            color: intelliumCyan,
                                          ),
                                          tooltip: 'Select date',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _PremiumInfoCard(
                                icon: Icons.info_outline_rounded,
                                message:
                                    'Your Available Balance, Anticipated Balance, and Daily Spending Limit will be based on the details you enter here.',
                              ),
                              if (validationMessage != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  validationMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFFFF8A8A),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: _PremiumGradientButton(
                                  label:
                                      saving ? 'Saving...' : 'Save & Continue',
                                  onPressed: saving
                                      ? null
                                      : () {
                                          unawaited(submitWelcome());
                                        },
                                  trailingIcon: Icons.arrow_forward_rounded,
                                  gradientColors: const [
                                    intelliumCyan,
                                    intelliumBlue,
                                    intelliumPurple,
                                  ],
                                  isLoading: saving,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: TextButton(
                                  onPressed: saving
                                      ? null
                                      : () {
                                          Navigator.pop(sheetContext);
                                        },
                                  child: Text(
                                    'Skip for Now',
                                    style: TextStyle(
                                      color: intelliumPurple.withValues(
                                          alpha: .88),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      welcomeDialogOpen = false;
      controller.dispose();
      startingBalanceController.dispose();
      cutoffDateController.dispose();
    }

    if (!mounted) return;
    setState(() {
      refreshKey++;
    });
  }

  void openTrackSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: intelliumSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => TrackStarterSheet(onChanged: refreshAll),
    );
  }

  void onNavTap(int index) {
    if (index == _navTrack) {
      // Track is a center action that opens the sheet instead of switching tabs.
      openTrackSheet();
      return;
    }

    final targetPageIndex = _pageIndexForNavSlot(index);
    if (targetPageIndex == null) return;
    if (targetPageIndex == currentIndex) return;

    setState(() => currentIndex = targetPageIndex);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        refreshKey: refreshKey,
        premiumService: widget.premiumService,
      ),
      PremiumAnalyticsDashboardScreen(
        refreshKey: refreshKey,
        premiumService: widget.premiumService,
      ),
      ToolsScreen(
        premiumService: widget.premiumService,
        refreshKey: refreshKey,
      ),
      SettingsScreen(
        onChanged: refreshAll,
        premiumService: widget.premiumService,
        themeController: widget.themeController,
      ),
    ];
    final safeIndex = currentIndex.clamp(0, pages.length - 1).toInt();

    return Scaffold(
      backgroundColor: intelliumBackground,
      body: IndexedStack(
        index: safeIndex,
        children: pages,
      ),
      bottomNavigationBar: widget.premiumService.isPremium
          ? _PremiumBottomNavigationBar(
              activeNavIndex: activeNavIndex,
              onNavTap: onNavTap,
            )
          : Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(24),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 72,
                  child: Row(
                    children: [
                      Expanded(
                        child: NavItem(
                          icon: Icons.home_rounded,
                          label: 'Home',
                          active: activeNavIndex == _navHome,
                          onTap: () => onNavTap(_navHome),
                        ),
                      ),
                      Expanded(
                        child: NavItem(
                          icon: Icons.bar_chart_rounded,
                          label: 'Analytics',
                          active: activeNavIndex == _navAnalytics,
                          onTap: () => onNavTap(_navAnalytics),
                        ),
                      ),
                      Expanded(
                        child: NavItem(
                          icon: Icons.add_rounded,
                          label: 'Track',
                          active: false,
                          highlight: true,
                          iconSize: 30,
                          onTap: () => onNavTap(_navTrack),
                        ),
                      ),
                      Expanded(
                        child: NavItem(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Tools',
                          active: activeNavIndex == _navTools,
                          onTap: () => onNavTap(_navTools),
                        ),
                      ),
                      Expanded(
                        child: NavItem(
                          icon: Icons.settings_rounded,
                          label: 'Settings',
                          active: activeNavIndex == _navSettings,
                          onTap: () => onNavTap(_navSettings),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class ToolsScreen extends StatelessWidget {
  final PremiumService premiumService;
  final int refreshKey;

  const ToolsScreen({
    super.key,
    required this.premiumService,
    required this.refreshKey,
  });

  Future<void> openInviteEarn(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InviteEarnScreen(refreshKey: refreshKey),
      ),
    );
  }

  Future<void> openTool(BuildContext context, String title) async {
    Widget? screen;

    switch (title) {
      case 'Monthly Report Card':
        screen = const MonthlyReportCardScreen();
        break;
      case 'Calculator':
        screen = const PremiumCalculatorScreen();
        break;
      case 'To-Do List':
        screen = const PremiumTodoListScreen();
        break;
    }

    if (screen == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tools',
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Calculator and task tools for your premium workspace',
              style: TextStyle(
                color: ui.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: premiumService,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeroCard(
                  colors: const [
                    Color(0xFF153048),
                    intelliumBlue,
                    intelliumPurple,
                  ],
                  title: 'Premium Tools',
                  value: premiumService.isPremium
                      ? '3 Live Tools'
                      : '1 Live + 2 Premium',
                  badge: premiumService.isPremium
                      ? 'Invite & Earn, Calculator, and To-Do List are ready inside your SweldoTrack workspace.'
                      : 'Invite & Earn is live now. Upgrade to Premium to unlock Calculator and To-Do List.',
                ),
                const SizedBox(height: 18),
                ToolAccessCard(
                  title: 'Invite & Earn',
                  subtitle:
                      'Share your referral code, track paid referrals, and monitor your earnings in one live screen.',
                  icon: Icons.card_giftcard_rounded,
                  color: intelliumBlue,
                  onTap: () => openInviteEarn(context),
                  actionLabel: 'Open',
                ),
                const SizedBox(height: 18),
                ToolAccessCard(
                  title: 'Monthly Report Card',
                  subtitle:
                      'View your monthly income, spending, bills, and savings summary.',
                  icon: Icons.workspace_premium_rounded,
                  color: const Color(0xFFFFC857),
                  onTap: () => openTool(context, 'Monthly Report Card'),
                  actionLabel: 'Open',
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: ui.sectionContainerDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: ui.iconChipBackground(
                              premiumService.isPremium
                                  ? intelliumCyan
                                  : intelliumPurple,
                            ),
                            child: Icon(
                              premiumService.isPremium
                                  ? Icons.auto_awesome_rounded
                                  : Icons.lock_rounded,
                              color: premiumService.isPremium
                                  ? intelliumCyan
                                  : intelliumPurple,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              premiumService.isPremium
                                  ? 'Your live tools are ready'
                                  : 'Live tools and premium unlocks',
                              style: TextStyle(
                                color: ui.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        premiumService.isPremium
                            ? 'Open Invite & Earn, use Calculator for quick budget checks, or manage reminders in To-Do List.'
                            : 'Invite & Earn is live for all users. Calculator and To-Do List stay visible here with premium access when you are ready.',
                        style: TextStyle(
                          color: ui.textSecondary,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ToolAccessCard(
                  title: 'Calculator',
                  subtitle:
                      'Quick budget math and financial what-if checks inside SweldoTrack.',
                  icon: Icons.calculate_rounded,
                  color: intelliumCyan,
                  isLocked: !premiumService.isPremium,
                  onTap: () => openTool(context, 'Calculator'),
                  actionLabel: 'Open',
                  lockedMessage:
                      'Unlock SweldoTrack Premium to use Calculator.',
                ),
                const SizedBox(height: 14),
                ToolAccessCard(
                  title: 'To-Do List',
                  subtitle:
                      'Track reminders, errands, and bill follow-ups in one premium task space.',
                  icon: Icons.checklist_rounded,
                  color: intelliumPurple,
                  isLocked: !premiumService.isPremium,
                  onTap: () => openTool(context, 'To-Do List'),
                  actionLabel: 'Open',
                  lockedMessage:
                      'Unlock SweldoTrack Premium to use To-Do List.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MonthlyReportCardScreen extends StatefulWidget {
  const MonthlyReportCardScreen({super.key});

  @override
  State<MonthlyReportCardScreen> createState() =>
      _MonthlyReportCardScreenState();
}

class _MonthlyReportCardScreenState extends State<MonthlyReportCardScreen> {
  bool loading = true;
  late String monthLabel;
  double totalIncome = 0;
  double totalExpenses = 0;
  double savingsBalance = 0;
  int billsPaidCount = 0;
  int unpaidBillsCount = 0;
  double billsPaidAmount = 0;
  double unpaidBillsAmount = 0;
  String? topCategory;
  double topCategoryAmount = 0;
  int healthScore = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final now = dateOnly(DateTime.now());
    final expenses = await FinanceRepository.loadExpenses();
    final bills = await FinanceRepository.loadBills();
    final incomeEntries = await FinanceRepository.loadIncomeEntries();
    final trackedSavings = await FinanceRepository.getTrackedSavingsAmount();

    final monthExpenses = expenses
        .where((item) =>
            item.createdAt.year == now.year &&
            item.createdAt.month == now.month)
        .toList();
    final monthIncome = incomeEntries
        .where(
          (item) =>
              item.receivedAt.year == now.year &&
              item.receivedAt.month == now.month,
        )
        .toList();
    final paidBillsThisMonth = bills
        .where(
          (bill) =>
              bill.paidDate != null &&
              bill.paidDate!.year == now.year &&
              bill.paidDate!.month == now.month,
        )
        .toList();
    final outstandingBills = bills
        .where((bill) => billHasOutstandingBalance(bill, referenceDate: now))
        .toList();

    final categoryTotals = <String, double>{};
    for (final item in monthExpenses) {
      categoryTotals[item.category] =
          (categoryTotals[item.category] ?? 0) + item.amount;
    }
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final monthlyIncomeTotal = normalizeMoney(
      monthIncome.fold<double>(0, (sum, item) => sum + item.amount),
    );
    final monthlyExpenseTotal = normalizeMoney(
      monthExpenses.fold<double>(0, (sum, item) => sum + item.amount),
    );
    final monthlyPaidBillsAmount = normalizeMoney(
      paidBillsThisMonth.fold<double>(0, (sum, item) => sum + item.amount),
    );
    final currentUnpaidBillsAmount = normalizeMoney(
      outstandingBills.fold<double>(0, (sum, item) => sum + item.amount),
    );

    final score = _buildFinancialHealthScore(
      income: monthlyIncomeTotal,
      expenses: monthlyExpenseTotal,
      unpaidBills: outstandingBills.length,
      savingsBalance: trackedSavings,
    );

    if (!mounted) return;
    setState(() {
      monthLabel = DateFormat('MMMM yyyy').format(now);
      totalIncome = monthlyIncomeTotal;
      totalExpenses = monthlyExpenseTotal;
      savingsBalance = trackedSavings;
      billsPaidCount = paidBillsThisMonth.length;
      unpaidBillsCount = outstandingBills.length;
      billsPaidAmount = monthlyPaidBillsAmount;
      unpaidBillsAmount = currentUnpaidBillsAmount;
      topCategory =
          sortedCategories.isEmpty ? null : sortedCategories.first.key;
      topCategoryAmount = sortedCategories.isEmpty
          ? 0
          : normalizeMoney(sortedCategories.first.value);
      healthScore = score;
      loading = false;
    });
  }

  int _buildFinancialHealthScore({
    required double income,
    required double expenses,
    required int unpaidBills,
    required double savingsBalance,
  }) {
    var score = 50;
    if (income > 0) {
      final expenseRatio = expenses / max(income, 1);
      if (expenseRatio <= 0.55) {
        score += 20;
      } else if (expenseRatio <= 0.8) {
        score += 12;
      } else if (expenseRatio <= 1.0) {
        score += 4;
      } else {
        score -= 14;
      }
    } else if (expenses > 0) {
      score -= 12;
    }

    score += unpaidBills == 0 ? 15 : max(-18, 10 - (unpaidBills * 6));
    if (savingsBalance > 0) {
      score += savingsBalance >= max(income * 0.1, 500) ? 15 : 8;
    }
    return score.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    if (loading) {
      return PremiumToolScaffold(
        title: 'Monthly Report Card',
        subtitle:
            'View your monthly income, spending, bills, and savings summary.',
        child: buildPageLoadingState('Loading your monthly report...'),
      );
    }

    Widget metricGrid() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final cards = <Widget>[
            SummaryCard(
              title: 'Total Income',
              value: formatPhp(totalIncome),
              subtitle: 'Income added during $monthLabel',
              color: const Color(0xFF57E9C3),
              icon: Icons.payments_rounded,
            ),
            SummaryCard(
              title: 'Total Expenses',
              value: formatPhp(totalExpenses),
              subtitle: 'Saved spending entries for this month',
              color: intelliumPink,
              icon: Icons.receipt_long_rounded,
            ),
            SummaryCard(
              title: 'Bills Paid',
              value: '$billsPaidCount',
              subtitle: '${formatPhp(billsPaidAmount)} settled this month',
              color: const Color(0xFF6C8CFF),
              icon: Icons.check_circle_rounded,
            ),
            SummaryCard(
              title: 'Unpaid Bills',
              value: '$unpaidBillsCount',
              subtitle: '${formatPhp(unpaidBillsAmount)} currently outstanding',
              color: const Color(0xFFFF8A5B),
              icon: Icons.pending_actions_rounded,
            ),
            SummaryCard(
              title: 'Savings Balance',
              value: formatPhp(savingsBalance),
              subtitle: 'Current tracked savings on this device',
              color: intelliumCyan,
              icon: Icons.savings_rounded,
            ),
            SummaryCard(
              title: 'Health Score',
              value: '$healthScore / 100',
              subtitle:
                  'Simple monthly signal from savings, bills, and spending',
              color: const Color(0xFFFFC857),
              icon: Icons.favorite_rounded,
            ),
          ];

          if (compact) {
            return Column(
              children: [
                for (var index = 0; index < cards.length; index++) ...[
                  cards[index],
                  if (index != cards.length - 1) const SizedBox(height: 12),
                ],
              ],
            );
          }

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map(
                  (card) => SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: card,
                  ),
                )
                .toList(),
          );
        },
      );
    }

    return PremiumToolScaffold(
      title: 'Monthly Report Card',
      subtitle:
          'View your monthly income, spending, bills, and savings summary.',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeroCard(
              colors: const [
                Color(0xFF122238),
                intelliumBlue,
                intelliumPurple,
              ],
              title: 'Month Snapshot',
              value: monthLabel,
              badge:
                  'Financial Health Score: $healthScore / 100 | ${topCategory == null ? 'No top category yet' : '$topCategory leads spending'}',
            ),
            const SizedBox(height: 18),
            metricGrid(),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: ui.sectionContainerDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top Spending Category',
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    topCategory == null
                        ? 'No expense category has spending data for this month yet.'
                        : '$topCategory recorded the highest spending in $monthLabel at ${formatPhp(topCategoryAmount)}.',
                    style: TextStyle(
                      color: ui.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ToolAccessCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isLocked;
  final VoidCallback onTap;
  final String actionLabel;
  final String? lockedMessage;

  const ToolAccessCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isLocked = false,
    required this.onTap,
    this.actionLabel = 'Open',
    this.lockedMessage,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final badgeLabel = isLocked ? 'Upgrade' : actionLabel;
    final badgeColor = isLocked ? intelliumPurple : color;
    final supportingCopy =
        isLocked ? '$subtitle Upgrade to Premium to open this tool.' : subtitle;
    final effectiveLockedMessage =
        lockedMessage ?? 'Unlock SweldoTrack Premium to use $title.';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: !isLocked
            ? onTap
            : () => showAppMessage(
                  context,
                  effectiveLockedMessage,
                ),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: ui.cardDecoration(radius: 24),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: ui.iconChipBackground(color, radius: 16),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  if (isLocked)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        height: 22,
                        width: 22,
                        decoration: BoxDecoration(
                          color: intelliumBackground,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .08),
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: intelliumPurple,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      supportingCopy,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ui.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: .24),
                  ),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: isLocked ? badgeColor : ui.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool highlight;
  final double iconSize;

  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.highlight = false,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        active || highlight ? const Color(0xFF00C896) : const Color(0xFF8B9AB0);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: iconSize),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class TrackStarterSheet extends StatefulWidget {
  final VoidCallback onChanged;

  const TrackStarterSheet({super.key, required this.onChanged});

  @override
  State<TrackStarterSheet> createState() => _TrackStarterSheetState();
}

class _TrackStarterSheetState extends State<TrackStarterSheet> {
  bool loading = true;
  bool hasSavedFinanceData = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hasSavedData = await FinanceRepository.hasAnySavedFinanceData();
    if (!mounted) return;
    setState(() {
      hasSavedFinanceData = hasSavedData;
      loading = false;
    });
  }

  Future<void> _openScreen(BuildContext context, Widget screen) async {
    final navigator = Navigator.of(context);
    navigator.pop();
    await navigator.push(
      MaterialPageRoute(builder: (_) => screen),
    );
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final headline = loading
        ? 'Loading your tracker shortcuts'
        : hasSavedFinanceData
            ? 'Choose what to track next'
            : 'Set up your balance first';
    final supportingCopy = loading
        ? 'Checking your saved finance data so the Track action opens the right next step.'
        : hasSavedFinanceData
            ? 'Jump straight into spending, bills, savings, or update your balance setup without leaving Home.'
            : 'Start with your opening available balance and cutoff details so Income, Spending, Savings Balance, and Upcoming Bills stay accurate.';
    final primaryLabel =
        hasSavedFinanceData ? 'Open Spending Tracker' : 'Open Balance Setup';
    final primaryScreen = hasSavedFinanceData
        ? const ExpenseTrackerScreen()
        : const SweldoBudgetScreen();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 20),
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                gradient: ui.accentGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: ui.isJade
                    ? [
                        const BoxShadow(
                          color: Color(0x662EE6A6),
                          blurRadius: 22,
                          spreadRadius: 1,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: intelliumCyan.withValues(alpha: .20),
                          blurRadius: 26,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: Icon(
                Icons.payments_rounded,
                color: ui.isJade ? ui.textPrimary : intelliumBackground,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              headline,
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              supportingCopy,
              style: TextStyle(
                color: ui.textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: ui.sectionContainerDecoration(radius: 24),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _TrackStarterActionCard(
                                title: 'Spending',
                                subtitle: 'Log a new expense',
                                icon: Icons.wallet_rounded,
                                color: intelliumCyan,
                                onTap: () => _openScreen(
                                  context,
                                  const ExpenseTrackerScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TrackStarterActionCard(
                                title: 'Bills',
                                subtitle: 'Manage due dates',
                                icon: Icons.receipt_long_rounded,
                                color: intelliumPink,
                                onTap: () => _openScreen(
                                  context,
                                  const BillsTrackerScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _TrackStarterActionCard(
                                title: 'Savings',
                                subtitle: 'Update savings progress',
                                icon: Icons.savings_rounded,
                                color: intelliumPurple,
                                onTap: () => _openScreen(
                                  context,
                                  const UnifiedSavingsGoalScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TrackStarterActionCard(
                                title: 'Balance Setup',
                                subtitle: hasSavedFinanceData
                                    ? 'Adjust balance and cutoff'
                                    : 'Set up your finance base',
                                icon: Icons.account_balance_wallet_rounded,
                                color: intelliumBlue,
                                onTap: () => _openScreen(
                                  context,
                                  const SweldoBudgetScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              label: primaryLabel,
              onPressed: () async {
                await _openScreen(context, primaryScreen);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackStarterActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TrackStarterActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: ui.cardDecoration(radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: ui.iconChipBackground(color, radius: 14),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: ui.textMuted,
                  fontSize: 11.75,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final int refreshKey;
  final PremiumService premiumService;

  const HomeScreen({
    super.key,
    required this.refreshKey,
    required this.premiumService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool loading = true;
  String preferredName = '';
  DateTime currentDateTime = DateTime.now();
  Timer? clockTimer;
  double startingBalance = 0;
  double totalExpenses = 0;
  double savingsGoal = 0;
  double savingsSaved = 0;
  double targetSavings = 0;
  double totalBills = 0;
  double totalIncomeAdded = 0;
  double currentBalance = 0;
  double projectedAvailableBalance = 0;
  double settledBillsTotal = 0;
  double dailyBudget = 0;
  bool usesManualDailyBudget = false;
  bool isManualDailyBudgetSafe = true;
  int remainingSweldoDays = 0;
  int expenseCount = 0;
  List<double> weeklyExpenseTrend = List<double>.filled(7, 0);
  int billCount = 0;
  List<BillItem> upcomingBills = [];
  List<ExpenseItem> recentExpenses = [];

  // Legacy compatibility aliases. Do not use in new UI.
  @Deprecated('Use startingBalance instead.')
  double get salary => startingBalance;

  @Deprecated('Use totalIncomeAdded instead.')
  double get spendableMoney => totalIncomeAdded;

  @override
  void initState() {
    super.initState();
    startClock();
    load();
  }

  void startClock() {
    currentDateTime = DateTime.now();
    clockTimer?.cancel();
    clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {
        currentDateTime = DateTime.now();
      });
    });
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      load();
    }
  }

  Future<void> load() async {
    final name = await FinanceRepository.getPreferredName();
    final expenses = await FinanceRepository.loadExpenses();
    final bills = await FinanceRepository.loadBills();
    final startingBalance = await FinanceRepository.getStartingBalance();
    final incomeEntries = await FinanceRepository.loadIncomeEntries();
    final trackedSavings = await FinanceRepository.getTrackedSavingsAmount();
    final savingsHistory = await FinanceRepository.loadSavingsHistory();
    final dailyBudgetSettings =
        await FinanceRepository.getDailyBudgetSettings();
    final daysUntilPayday = await FinanceRepository.getDaysUntilPayday();
    final salaryReceivedDate = await FinanceRepository.getSalaryReceivedDate();
    final nextPaydayDate = await FinanceRepository.getNextPaydayDate();
    final goal = await FinanceRepository.getSavingsGoal();
    final unpaidItems = filterBillsForBudgetCycle(
      bills: bills,
      cycleStartDate: salaryReceivedDate,
      nextCutoffDate: nextPaydayDate,
    )..sort((a, b) {
        final aDate = resolveUpcomingBillDate(a) ?? DateTime(9999);
        final bDate = resolveUpcomingBillDate(b) ?? DateTime(9999);
        return aDate.compareTo(bDate);
      });
    final overview = recalculateBudget(
      startingBalance: startingBalance,
      incomeEntries: incomeEntries,
      savingsBalance: trackedSavings,
      savingsHistory: savingsHistory,
      bills: bills,
      expenses: expenses,
      cycleStartDate: salaryReceivedDate,
      nextCutoffDate: nextPaydayDate,
      fallbackDaysUntilCutoff: daysUntilPayday,
      useManualDailyBudget: dailyBudgetSettings.useManualDailyBudget,
      manualDailyBudget: dailyBudgetSettings.manualDailyBudget,
    );
    final recentItems = overview.activeCycleExpenses.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final activeCycleExpenseTotal = overview.snapshot.totalLoggedExpenses;
    final rollingSevenDayTrend = buildSevenDayExpenseTrend(expenses);

    if (!mounted) return;
    setState(() {
      preferredName = name;
      this.startingBalance = startingBalance;
      totalExpenses = activeCycleExpenseTotal;
      savingsGoal = goal;
      savingsSaved = trackedSavings;
      targetSavings = goal;
      totalBills = overview.snapshot.totalBills;
      totalIncomeAdded = overview.snapshot.totalIncomeAdded;
      currentBalance = overview.snapshot.availableBalance;
      projectedAvailableBalance = overview.snapshot.projectedAvailableBalance;
      settledBillsTotal = overview.snapshot.settledBillsAmount;
      dailyBudget = overview.snapshot.dailySpendingLimit;
      usesManualDailyBudget = overview.snapshot.usesManualDailyBudget;
      isManualDailyBudgetSafe = overview.snapshot.isManualDailyBudgetSafe;
      remainingSweldoDays = overview.snapshot.remainingDays;
      expenseCount = overview.activeCycleExpenses.length;
      weeklyExpenseTrend = rollingSevenDayTrend;
      billCount = unpaidItems.length;
      upcomingBills = unpaidItems.take(3).toList();
      recentExpenses = recentItems.take(4).toList();
      loading = false;
    });
  }

  Future<void> openAnalytics() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PremiumAnalyticsDashboardScreen(
          refreshKey: widget.refreshKey,
          premiumService: widget.premiumService,
        ),
      ),
    );

    if (!mounted) return;
    await load();
  }

  Future<void> openTracker(String title) async {
    Widget? screen;

    switch (title) {
      case 'SweldoTrack':
        screen = const ExpenseTrackerScreen();
        break;
      case 'Sweldo Budget':
        screen = const SweldoBudgetScreen();
        break;
      case 'Savings Goal':
        screen = const UnifiedSavingsGoalScreen();
        break;
      case 'Bills Tracker':
        screen = const BillsTrackerScreen();
        break;
    }

    if (screen == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen!),
    );

    if (!mounted) return;
    final navigationState =
        context.findAncestorStateOfType<_MainNavigationScreenState>();
    if (navigationState != null) {
      navigationState.refreshAll();
      return;
    }
    await load();
  }

  Future<void> openTool(String title) async {
    Widget? screen;

    switch (title) {
      case 'Calculator':
        screen = const PremiumCalculatorScreen();
        break;
      case 'To-Do List':
        screen = const PremiumTodoListScreen();
        break;
    }

    if (screen == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen!),
    );
  }

  @override
  void dispose() {
    clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final healthScore = calculateFinancialHealthScore(
      savingsSaved: savingsSaved,
      currentBalance: currentBalance,
      unpaidBills: totalBills,
      totalExpenses: totalExpenses,
    );
    final hasAnyData = expenseCount > 0 ||
        savingsSaved > 0 ||
        billCount > 0 ||
        currentBalance != 0;
    final healthLabel = financialHealthLabel(healthScore, hasAnyData);
    final ui = SweldoVisualStyle.fromContext(context);
    final dashboardData = _HomeDashboardData(
      preferredName: preferredName,
      currentDateTime: currentDateTime,
      startingBalance: startingBalance,
      totalExpenses: totalExpenses,
      savingsSaved: savingsSaved,
      targetSavings: targetSavings,
      totalBills: totalBills,
      totalIncomeAdded: totalIncomeAdded,
      currentBalance: currentBalance,
      projectedAvailableBalance: projectedAvailableBalance,
      settledBillsTotal: settledBillsTotal,
      dailyBudget: dailyBudget,
      usesManualDailyBudget: usesManualDailyBudget,
      isManualDailyBudgetSafe: isManualDailyBudgetSafe,
      remainingSweldoDays: remainingSweldoDays,
      expenseCount: expenseCount,
      weeklyExpenseTrend: weeklyExpenseTrend,
      billCount: billCount,
      upcomingBills: upcomingBills,
      recentExpenses: recentExpenses,
      healthScore: healthScore,
      healthLabel: healthLabel,
    );

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: loading
            ? buildPageLoadingState('Loading your money overview...')
            : RefreshIndicator(
                color: intelliumCyan,
                backgroundColor: ui.sectionFill,
                onRefresh: load,
                child: AnimatedBuilder(
                  animation: widget.premiumService,
                  builder: (context, _) {
                    if (widget.premiumService.isPremium) {
                      return _PremiumHomeDashboard(
                        data: dashboardData,
                        onOpenAnalytics: openAnalytics,
                        onOpenSweldo: () => openTracker('Sweldo Budget'),
                        onOpenBills: () => openTracker('Bills Tracker'),
                        onOpenSavings: () => openTracker('Savings Goal'),
                        onOpenExpenses: () => openTracker('SweldoTrack'),
                        onOpenCalculator: () => openTool('Calculator'),
                        onOpenTodo: () => openTool('To-Do List'),
                      );
                    }

                    return _FreeHomeDashboard(
                      data: dashboardData,
                      premiumService: widget.premiumService,
                      onOpenSweldo: () => openTracker('Sweldo Budget'),
                      onOpenBills: () => openTracker('Bills Tracker'),
                      onOpenSavings: () => openTracker('Savings Goal'),
                      onOpenExpenses: () => openTracker('SweldoTrack'),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _PremiumBottomNavigationBar extends StatelessWidget {
  final int activeNavIndex;
  final ValueChanged<int> onNavTap;

  const _PremiumBottomNavigationBar({
    required this.activeNavIndex,
    required this.onNavTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xE0081024),
            Color(0xED0C1631),
            Color(0xE9101432),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
        boxShadow: [
          BoxShadow(
            color: _PremiumPalette.cyan.withValues(alpha: .10),
            blurRadius: 28,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: _PremiumPalette.violet.withValues(alpha: .10),
            blurRadius: 32,
            spreadRadius: -2,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .28),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Positioned(
              left: -30,
              bottom: -48,
              child: _PremiumAmbientGlow(
                size: 160,
                color: _PremiumPalette.cyan.withValues(alpha: .12),
              ),
            ),
            Positioned(
              right: -30,
              top: -44,
              child: _PremiumAmbientGlow(
                size: 160,
                color: _PremiumPalette.lilac.withValues(alpha: .12),
              ),
            ),
            SafeArea(
              top: false,
              child: SizedBox(
                height: 82,
                child: Row(
                  children: [
                    Expanded(
                      child: _PremiumNavItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        active: activeNavIndex ==
                            _MainNavigationScreenState._navHome,
                        onTap: () =>
                            onNavTap(_MainNavigationScreenState._navHome),
                      ),
                    ),
                    Expanded(
                      child: _PremiumNavItem(
                        icon: Icons.bar_chart_rounded,
                        label: 'Analytics',
                        active: activeNavIndex ==
                            _MainNavigationScreenState._navAnalytics,
                        onTap: () =>
                            onNavTap(_MainNavigationScreenState._navAnalytics),
                      ),
                    ),
                    Expanded(
                      child: _PremiumNavItem(
                        icon: Icons.add_rounded,
                        label: 'Track',
                        active: false,
                        highlight: true,
                        iconSize: 31,
                        onTap: () =>
                            onNavTap(_MainNavigationScreenState._navTrack),
                      ),
                    ),
                    Expanded(
                      child: _PremiumNavItem(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Tools',
                        active: activeNavIndex ==
                            _MainNavigationScreenState._navTools,
                        onTap: () =>
                            onNavTap(_MainNavigationScreenState._navTools),
                      ),
                    ),
                    Expanded(
                      child: _PremiumNavItem(
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        active: activeNavIndex ==
                            _MainNavigationScreenState._navSettings,
                        onTap: () =>
                            onNavTap(_MainNavigationScreenState._navSettings),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool highlight;
  final double iconSize;
  final VoidCallback onTap;

  const _PremiumNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.highlight = false,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final accent = highlight
        ? _PremiumPalette.cyan
        : active
            ? Colors.white
            : _PremiumPalette.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.symmetric(
                horizontal: highlight ? 14 : 10,
                vertical: highlight ? 11 : 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(highlight ? 20 : 18),
                gradient: highlight
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1A3A7D),
                          Color(0xFF2656CB),
                          Color(0xFF6D4DFF),
                        ],
                      )
                    : active
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: .10),
                              Colors.white.withValues(alpha: .04),
                            ],
                          )
                        : null,
                color: !highlight && !active ? Colors.transparent : null,
                border: Border.all(
                  color: highlight
                      ? Colors.white.withValues(alpha: .16)
                      : active
                          ? Colors.white.withValues(alpha: .08)
                          : Colors.transparent,
                ),
                boxShadow: highlight
                    ? [
                        BoxShadow(
                          color: _PremiumPalette.cyan.withValues(alpha: .22),
                          blurRadius: 20,
                          spreadRadius: -2,
                        ),
                        BoxShadow(
                          color: _PremiumPalette.violet.withValues(alpha: .22),
                          blurRadius: 22,
                          spreadRadius: -4,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : active
                        ? [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: .05),
                              blurRadius: 14,
                              spreadRadius: -4,
                            ),
                          ]
                        : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: highlight ? Colors.white : accent,
                    size: iconSize,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: highlight ? Colors.white : accent,
                      fontSize: 10.5,
                      fontWeight: active || highlight
                          ? FontWeight.w700
                          : FontWeight.w600,
                      letterSpacing: .15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class _HomeDashboardData {
  final String preferredName;
  final DateTime currentDateTime;
  final double startingBalance;
  final double totalExpenses;
  final double savingsSaved;
  final double targetSavings;
  final double totalBills;
  final double totalIncomeAdded;
  final double currentBalance;
  final double projectedAvailableBalance;
  final double settledBillsTotal;
  final double dailyBudget;
  final bool usesManualDailyBudget;
  final bool isManualDailyBudgetSafe;
  final int remainingSweldoDays;
  final int expenseCount;
  final List<double> weeklyExpenseTrend;
  final int billCount;
  final List<BillItem> upcomingBills;
  final List<ExpenseItem> recentExpenses;
  final double healthScore;
  final String healthLabel;

  const _HomeDashboardData({
    required this.preferredName,
    required this.currentDateTime,
    required this.startingBalance,
    required this.totalExpenses,
    required this.savingsSaved,
    required this.targetSavings,
    required this.totalBills,
    required this.totalIncomeAdded,
    required this.currentBalance,
    required this.projectedAvailableBalance,
    required this.settledBillsTotal,
    required this.dailyBudget,
    required this.usesManualDailyBudget,
    required this.isManualDailyBudgetSafe,
    required this.remainingSweldoDays,
    required this.expenseCount,
    required this.weeklyExpenseTrend,
    required this.billCount,
    required this.upcomingBills,
    required this.recentExpenses,
    required this.healthScore,
    required this.healthLabel,
  });
}

class _FreeHomeDashboard extends StatelessWidget {
  final _HomeDashboardData data;
  final PremiumService premiumService;
  final VoidCallback onOpenSweldo;
  final VoidCallback onOpenBills;
  final VoidCallback onOpenSavings;
  final VoidCallback onOpenExpenses;

  const _FreeHomeDashboard({
    required this.data,
    required this.premiumService,
    required this.onOpenSweldo,
    required this.onOpenBills,
    required this.onOpenSavings,
    required this.onOpenExpenses,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            right: -32,
            child: Container(
              height: 150,
              width: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ui.isJade
                    ? const Color(0xFF2EE6A6).withValues(alpha: .12)
                    : intelliumPurple.withValues(alpha: .16),
                boxShadow: [
                  BoxShadow(
                    color: ui.isJade
                        ? const Color(0xFF2EE6A6).withValues(alpha: .24)
                        : intelliumPurple.withValues(alpha: .28),
                    blurRadius: 90,
                    spreadRadius: 16,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 176,
            left: -46,
            child: Container(
              height: 140,
              width: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ui.isJade
                    ? const Color(0xFF9DFFE0).withValues(alpha: .10)
                    : intelliumCyan.withValues(alpha: .14),
                boxShadow: [
                  BoxShadow(
                    color: ui.isJade
                        ? const Color(0xFF45F5B6).withValues(alpha: .18)
                        : intelliumCyan.withValues(alpha: .22),
                    blurRadius: 88,
                    spreadRadius: 14,
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IntelliumTopHeader(
                preferredName: data.preferredName,
                currentDateTime: data.currentDateTime,
              ),
              const SizedBox(height: 22),
              IntelliumBalanceCard(
                startingBalance: data.startingBalance,
                totalIncomeAdded: data.totalIncomeAdded,
                availableBalance: data.currentBalance,
                savingsBalance: data.savingsSaved,
                projectedAvailableBalance: data.projectedAvailableBalance,
                upcomingBillsAmount: data.totalBills,
                onStartingBalanceTap: onOpenSweldo,
                onIncomeTap: onOpenSweldo,
                onSavingsTap: onOpenSavings,
                onBillsTap: onOpenBills,
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final useWrap = constraints.maxWidth < 380;
                  final buttons = [
                    HomeQuickActionButton(
                      label: 'Budget',
                      icon: Icons.payments_rounded,
                      color: intelliumBlue,
                      onTap: onOpenSweldo,
                    ),
                    HomeQuickActionButton(
                      label: 'Upcoming Bills',
                      icon: Icons.receipt_long_rounded,
                      color: intelliumPink,
                      onTap: onOpenBills,
                    ),
                    HomeQuickActionButton(
                      label: 'Savings',
                      icon: Icons.savings_rounded,
                      color: intelliumPurple,
                      onTap: onOpenSavings,
                    ),
                    HomeQuickActionButton(
                      label: 'Spending',
                      icon: Icons.wallet_rounded,
                      color: intelliumCyan,
                      onTap: onOpenExpenses,
                    ),
                  ];
                  if (useWrap) {
                    final cardWidth = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final button in buttons)
                          SizedBox(width: cardWidth, child: button),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      for (var index = 0; index < buttons.length; index++) ...[
                        if (index > 0) const SizedBox(width: 12),
                        Expanded(child: buttons[index]),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 26),
              const HomeSectionHeader(
                title: 'Overview',
                subtitle: 'Live snapshot from your local data',
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - 14) / 2;
                  final cardHeight = constraints.maxWidth < 380 ? 172.0 : 164.0;

                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: HomeOverviewCard(
                          title: 'Opening Balance',
                          value: formatPhp(data.startingBalance),
                          subtitle: 'Money available before recorded income',
                          icon: Icons.payments_rounded,
                          color: intelliumBlue,
                          onTap: onOpenSweldo,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: HomeOverviewCard(
                          title: 'Upcoming Bills',
                          value: formatPhp(data.totalBills),
                          subtitle: data.billCount == 0
                              ? 'No upcoming bills saved yet'
                              : '${data.billCount} unpaid bill items before the next cutoff',
                          icon: Icons.receipt_long_rounded,
                          color: intelliumPink,
                          onTap: onOpenBills,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: HomeOverviewCard(
                          title: 'Savings Balance',
                          value: formatPhp(data.savingsSaved),
                          subtitle: 'Money set aside',
                          icon: Icons.savings_rounded,
                          color: intelliumCyan,
                          onTap: onOpenSavings,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: HomeOverviewCard(
                          title: 'Income',
                          value: formatPhp(data.totalIncomeAdded),
                          subtitle: 'Total income added',
                          icon: Icons.payments_rounded,
                          color: intelliumPurple,
                          onTap: onOpenSweldo,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: HomeOverviewCard(
                          title: 'Spending',
                          value: formatPhp(data.totalExpenses),
                          subtitle: data.expenseCount == 0
                              ? 'No spending recorded in this cycle'
                              : '${data.expenseCount} spending entries in this cycle',
                          icon: Icons.wallet_rounded,
                          color: intelliumPink,
                          onTap: onOpenExpenses,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: HomeOverviewCard(
                          title: 'Daily Spending Limit',
                          value: formatPhp(data.dailyBudget),
                          subtitle: data.usesManualDailyBudget
                              ? (data.isManualDailyBudgetSafe
                                  ? 'Manual daily spending limit is on track'
                                  : 'Manual daily spending limit is above safe cutoff pace')
                              : (data.remainingSweldoDays > 0
                                  ? '${data.remainingSweldoDays} days until next cutoff'
                                  : 'No cutoff date set'),
                          icon: Icons.today_rounded,
                          color: intelliumCyan,
                          onTap: onOpenSweldo,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              PremiumFeatureLockCard(
                title: '7-Day Analysis',
                subtitle:
                    'Unlock 7-day analysis and custom themes with SweldoTrack Premium.',
                premiumService: premiumService,
              ),
              const SizedBox(height: 24),
              const HomeSectionHeader(
                title: 'Premium Tools',
                subtitle:
                    'Upgrade to unlock Calculator and To-Do List in your premium workspace',
              ),
              const SizedBox(height: 14),
              PremiumFeatureLockCard(
                title: 'Premium Tools',
                subtitle:
                    'Unlock Calculator and To-Do List with SweldoTrack Premium.',
                premiumService: premiumService,
              ),
              const SizedBox(height: 20),
              IntelliumFinancialHealthCard(
                score: data.healthScore,
                label: data.healthLabel,
                message: financialHealthMessage(data.healthLabel),
              ),
              const SizedBox(height: 24),
              const HomeSectionHeader(
                title: 'Upcoming Bills',
                subtitle: 'Your next unpaid schedules',
              ),
              const SizedBox(height: 14),
              UpcomingBillsCard(
                bills: data.upcomingBills,
                onTap: onOpenBills,
              ),
              const SizedBox(height: 24),
              const HomeSectionHeader(
                title: 'Recent Activity',
                subtitle: 'Latest spending entries from the active cutoff',
              ),
              const SizedBox(height: 14),
              RecentActivityCard(
                expenses: data.recentExpenses,
                onTap: onOpenExpenses,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumHomeDashboard extends StatelessWidget {
  final _HomeDashboardData data;
  final Future<void> Function() onOpenAnalytics;
  final VoidCallback onOpenSweldo;
  final VoidCallback onOpenBills;
  final VoidCallback onOpenSavings;
  final VoidCallback onOpenExpenses;
  final VoidCallback onOpenCalculator;
  final VoidCallback onOpenTodo;

  const _PremiumHomeDashboard({
    required this.data,
    required this.onOpenAnalytics,
    required this.onOpenSweldo,
    required this.onOpenBills,
    required this.onOpenSavings,
    required this.onOpenExpenses,
    required this.onOpenCalculator,
    required this.onOpenTodo,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            right: -70,
            child: _PremiumAmbientGlow(
              size: 220,
              color: _PremiumPalette.cyan.withValues(alpha: .18),
            ),
          ),
          Positioned(
            top: 180,
            left: -90,
            child: _PremiumAmbientGlow(
              size: 260,
              color: _PremiumPalette.violet.withValues(alpha: .16),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PremiumDashboardHeader(data: data),
              const SizedBox(height: 18),
              _PremiumDashboardHero(
                data: data,
                onOpenSweldo: onOpenSweldo,
                onOpenBills: onOpenBills,
                onOpenSavings: onOpenSavings,
                onOpenExpenses: onOpenExpenses,
              ),
              const SizedBox(height: 24),
              _PremiumDashboardSection(
                title: 'Overview',
                subtitle:
                    'Premium cutoff snapshot with the same saved SweldoTrack data',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = constraints.maxWidth >= 920
                        ? (constraints.maxWidth - 24) / 3
                        : constraints.maxWidth >= 520
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _PremiumDashboardMetricCard(
                            title: 'Opening Balance',
                            value: formatPhp(data.startingBalance),
                            subtitle: 'Starting amount for the active cycle',
                            accent: _PremiumPalette.cyan,
                            icon: Icons.payments_rounded,
                            onTap: onOpenSweldo,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _PremiumDashboardMetricCard(
                            title: 'Upcoming Bills',
                            value: formatPhp(data.totalBills),
                            subtitle: data.billCount == 0
                                ? 'No upcoming bills saved'
                                : '${data.billCount} unpaid bill items',
                            accent: _PremiumPalette.sky,
                            icon: Icons.receipt_long_rounded,
                            onTap: onOpenBills,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _PremiumDashboardMetricCard(
                            title: 'Savings Balance',
                            value: formatPhp(data.savingsSaved),
                            subtitle: 'Money set aside',
                            accent: _PremiumPalette.lilac,
                            icon: Icons.savings_rounded,
                            onTap: onOpenSavings,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _PremiumDashboardMetricCard(
                            title: 'Spending',
                            value: formatPhp(data.totalExpenses),
                            subtitle: data.expenseCount == 0
                                ? 'No spending recorded yet'
                                : '${data.expenseCount} spending entries logged',
                            accent: _PremiumPalette.violet,
                            icon: Icons.wallet_rounded,
                            onTap: onOpenExpenses,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _PremiumDashboardMetricCard(
                            title: 'Daily Spending Limit',
                            value: formatPhp(data.dailyBudget),
                            subtitle: data.usesManualDailyBudget
                                ? (data.isManualDailyBudgetSafe
                                    ? 'Manual daily spending limit is on track'
                                    : 'Manual daily spending limit is above safe pace')
                                : (data.remainingSweldoDays > 0
                                    ? '${data.remainingSweldoDays} days until next cutoff'
                                    : 'No cutoff date set'),
                            accent: _PremiumPalette.cyan,
                            icon: Icons.today_rounded,
                            onTap: onOpenSweldo,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              _PremiumDashboardSection(
                title: 'Premium Insight',
                subtitle: 'A cleaner 7-day spending pulse for this cutoff',
                child: IntelliumAnalyticsCard(
                  values: data.weeklyExpenseTrend,
                  onTap: onOpenAnalytics,
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 760;
                  final upcoming = _PremiumDashboardSection(
                    title: 'Upcoming Bills',
                    subtitle: 'Your next unpaid schedules',
                    child: UpcomingBillsCard(
                      bills: data.upcomingBills,
                      onTap: onOpenBills,
                    ),
                  );
                  final recent = _PremiumDashboardSection(
                    title: 'Recent Activity',
                    subtitle: 'Latest spending entries from this active cutoff',
                    child: RecentActivityCard(
                      expenses: data.recentExpenses,
                      onTap: onOpenExpenses,
                    ),
                  );

                  if (stacked) {
                    return Column(
                      children: [
                        upcoming,
                        const SizedBox(height: 24),
                        recent,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: upcoming),
                      const SizedBox(width: 16),
                      Expanded(child: recent),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              _PremiumDashboardSection(
                title: 'Premium Tools',
                subtitle: 'Unlocked utilities available from your dashboard',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = constraints.maxWidth >= 640
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: HomeToolCard(
                            title: 'Calculator',
                            subtitle:
                                'Fast basic math for budget checks and split totals.',
                            icon: Icons.calculate_rounded,
                            color: intelliumCyan,
                            onTap: onOpenCalculator,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: HomeToolCard(
                            title: 'To-Do List',
                            subtitle:
                                'Track errands, bill reminders, and personal tasks locally.',
                            icon: Icons.checklist_rounded,
                            color: intelliumPink,
                            onTap: onOpenTodo,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumDashboardHeader extends StatelessWidget {
  final _HomeDashboardData data;

  const _PremiumDashboardHeader({
    required this.data,
  });

  Color _healthAccent(String label) {
    switch (label) {
      case 'Strong':
        return _PremiumPalette.cyan;
      case 'Stable':
        return _PremiumPalette.sky;
      case 'Watchful':
        return _PremiumPalette.gold;
      case 'Needs Attention':
        return const Color(0xFFFF7A9C);
      default:
        return _PremiumPalette.textSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    final greeting = data.preferredName.isEmpty
        ? greetingForTime(data.currentDateTime)
        : '${greetingForTime(data.currentDateTime)}, ${data.preferredName}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(child: _PremiumBrandLockup()),
            _PremiumStatusBadge(
              label: 'Premium',
              accent: _PremiumPalette.lilac,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          greeting,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'A refined cutoff view built from your local SweldoTrack data.',
          style: TextStyle(
            color: _PremiumPalette.textSoft.withValues(alpha: .92),
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _PremiumInfoChip(
              icon: Icons.calendar_today_rounded,
              label: formatHeaderDate(data.currentDateTime),
              accent: _PremiumPalette.sky,
            ),
            _PremiumInfoChip(
              icon: Icons.access_time_rounded,
              label: formatHeaderTime(data.currentDateTime),
              accent: _PremiumPalette.cyan,
            ),
            _PremiumInfoChip(
              icon: Icons.favorite_rounded,
              label: data.healthLabel,
              accent: _healthAccent(data.healthLabel),
            ),
          ],
        ),
      ],
    );
  }
}

class _PremiumDashboardHero extends StatelessWidget {
  final _HomeDashboardData data;
  final VoidCallback onOpenSweldo;
  final VoidCallback onOpenBills;
  final VoidCallback onOpenSavings;
  final VoidCallback onOpenExpenses;

  const _PremiumDashboardHero({
    required this.data,
    required this.onOpenSweldo,
    required this.onOpenBills,
    required this.onOpenSavings,
    required this.onOpenExpenses,
  });

  @override
  Widget build(BuildContext context) {
    final daysLeftLabel = data.remainingSweldoDays > 0
        ? '${data.remainingSweldoDays} days left'
        : 'No cutoff set';
    final progressBase = max(
      data.startingBalance > 0 ? data.startingBalance : 0,
      data.totalIncomeAdded > 0 ? data.totalIncomeAdded : 0,
    );
    final balanceProgress = progressBase <= 0
        ? 0.0
        : (data.currentBalance / progressBase).clamp(0.0, 1.0).toDouble();
    final remainingLabel = data.currentBalance >= 0
        ? 'Real spendable money available right now'
        : 'Available balance is below zero right now';

    return _PremiumShowcaseShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          final actions = Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _PremiumQuickLink(
                icon: Icons.payments_rounded,
                label: 'Income',
                accent: _PremiumPalette.cyan,
                onTap: onOpenSweldo,
              ),
              _PremiumQuickLink(
                icon: Icons.receipt_long_rounded,
                label: 'Upcoming',
                accent: _PremiumPalette.sky,
                onTap: onOpenBills,
              ),
              _PremiumQuickLink(
                icon: Icons.savings_rounded,
                label: 'Savings',
                accent: _PremiumPalette.lilac,
                onTap: onOpenSavings,
              ),
              _PremiumQuickLink(
                icon: Icons.wallet_rounded,
                label: 'Spending',
                accent: _PremiumPalette.violet,
                onTap: onOpenExpenses,
              ),
            ],
          );

          final balanceCopy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _PremiumInfoChip(
                    icon: Icons.event_repeat_rounded,
                    label: 'Active Cutoff',
                    accent: _PremiumPalette.lilac,
                  ),
                  const SizedBox(width: 10),
                  _PremiumStatusBadge(
                    label: daysLeftLabel,
                    accent: _PremiumPalette.cyan,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Available Balance',
                style: TextStyle(
                  color: _PremiumPalette.textSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatPhp(data.currentBalance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -1.6,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                remainingLabel,
                style: const TextStyle(
                  color: _PremiumPalette.textSoft,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: balanceProgress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: .08),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    _PremiumPalette.cyan,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${formatPhp(data.totalExpenses)} spending',
                      style: const TextStyle(
                        color: _PremiumPalette.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${formatPhp(data.projectedAvailableBalance)} anticipated balance',
                    style: const TextStyle(
                      color: _PremiumPalette.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, innerConstraints) {
                  final statWidth = innerConstraints.maxWidth >= 560
                      ? (innerConstraints.maxWidth - 24) / 3
                      : innerConstraints.maxWidth >= 360
                          ? (innerConstraints.maxWidth - 12) / 2
                          : innerConstraints.maxWidth;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: statWidth,
                        child: _PremiumHeroStatCard(
                          label: 'Opening',
                          value: formatPhp(data.salary),
                          accent: _PremiumPalette.cyan,
                        ),
                      ),
                      SizedBox(
                        width: statWidth,
                        child: _PremiumHeroStatCard(
                          label: 'Upcoming Bills',
                          value: formatPhp(data.totalBills),
                          accent: _PremiumPalette.sky,
                        ),
                      ),
                      SizedBox(
                        width: statWidth,
                        child: _PremiumHeroStatCard(
                          label: 'Savings Balance',
                          value: formatPhp(data.savingsSaved),
                          accent: _PremiumPalette.lilac,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              actions,
            ],
          );

          final summary = _PremiumDashboardSummaryCard(data: data);
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                balanceCopy,
                const SizedBox(height: 22),
                summary,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 11, child: balanceCopy),
              const SizedBox(width: 20),
              Expanded(flex: 8, child: summary),
            ],
          );
        },
      ),
    );
  }
}

class _PremiumDashboardSummaryCard extends StatelessWidget {
  final _HomeDashboardData data;

  const _PremiumDashboardSummaryCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _PremiumPalette.panelGlass.withValues(alpha: .74),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _PremiumPalette.edge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .22),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cutoff Summary',
            style: TextStyle(
              color: _PremiumPalette.textSoft,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PremiumPhoneStatTile(
                  label: 'Anticipated',
                  value: formatPhp(data.projectedAvailableBalance),
                  accent: _PremiumPalette.cyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PremiumPhoneStatTile(
                  label: 'Daily Limit',
                  value: formatPhp(data.dailyBudget),
                  accent: _PremiumPalette.violet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PremiumPhoneStatTile(
                  label: 'Income',
                  value: formatPhp(data.totalIncomeAdded),
                  accent: _PremiumPalette.cyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PremiumPhoneStatTile(
                  label: 'Paid Bills',
                  value: formatPhp(data.settledBillsTotal),
                  accent: _PremiumPalette.sky,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PremiumPhoneStatTile(
                  label: 'Opening Balance',
                  value: formatPhp(data.salary),
                  accent: _PremiumPalette.cyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PremiumPhoneStatTile(
                  label: 'Savings Balance',
                  value: formatPhp(data.savingsSaved),
                  accent: _PremiumPalette.sky,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _PremiumInsightRow(
            icon: Icons.auto_graph_rounded,
            label: 'Health',
            value: data.healthLabel,
            accent: _PremiumPalette.sky,
          ),
          const SizedBox(height: 10),
          _PremiumInsightRow(
            icon: Icons.wallet_outlined,
            label: 'Spending',
            value: '${data.expenseCount} tracked',
            accent: _PremiumPalette.lilac,
          ),
          const SizedBox(height: 10),
          _PremiumInsightRow(
            icon: Icons.receipt_long_rounded,
            label: 'Upcoming bills',
            value: '${data.billCount} scheduled',
            accent: _PremiumPalette.cyan,
          ),
        ],
      ),
    );
  }
}

class _PremiumDashboardSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _PremiumDashboardSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _PremiumPalette.panelGlass.withValues(alpha: .74),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _PremiumPalette.edge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: _PremiumPalette.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _PremiumDashboardMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  const _PremiumDashboardMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _PremiumPalette.panel.withValues(alpha: .92),
                _PremiumPalette.panelStrong.withValues(alpha: .88),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _PremiumPalette.edge),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: .08),
                blurRadius: 18,
                spreadRadius: -8,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: .32)),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  color: _PremiumPalette.textSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _PremiumPalette.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumQuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _PremiumQuickLink({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _PremiumPalette.panelStrong.withValues(alpha: .94),
                _PremiumPalette.panel.withValues(alpha: .88),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _PremiumPalette.edge),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: .10),
                blurRadius: 14,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumAmbientGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _PremiumAmbientGlow({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _PremiumInfoChip({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: .12),
            Colors.white.withValues(alpha: .03),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: .22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 15),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumHeroStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _PremiumHeroStatCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _PremiumPalette.textSoft,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumInsightRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _PremiumInsightRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accent, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _PremiumPalette.textSoft,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class IntelliumTopHeader extends StatelessWidget {
  final String preferredName;
  final DateTime currentDateTime;

  const IntelliumTopHeader({
    super.key,
    required this.preferredName,
    required this.currentDateTime,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final greeting = greetingForTime(currentDateTime);
    final title =
        preferredName.isEmpty ? greeting : '$greeting, $preferredName';

    return Row(
      children: [
        Container(
          height: 58,
          width: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF16233F),
                Color(0xFF2E6BFF),
                Color(0xFF6E56FF),
              ],
              stops: [0.0, 0.54, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: .10),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF64E8FF).withValues(alpha: .18),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: const Color(0xFF8B5CFF).withValues(alpha: .16),
                blurRadius: 28,
                spreadRadius: -1,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: .16),
                        Colors.white.withValues(alpha: .03),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.34, 1.0],
                    ),
                  ),
                ),
              ),
              Center(
                child: Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .12),
                    ),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white.withValues(alpha: .94),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    formatHeaderDate(currentDateTime),
                    style: TextStyle(
                      color: ui.textSecondary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color:
                          ui.cardFill.withValues(alpha: ui.isJade ? .84 : .92),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: ui.borderColor),
                    ),
                    child: Text(
                      formatHeaderTime(currentDateTime),
                      style: TextStyle(
                        color: ui.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Legacy compatibility aliases. Do not use in new UI.
extension _HomeDashboardDataLegacyAliases on _HomeDashboardData {
  @Deprecated('Use startingBalance instead.')
  double get salary => startingBalance;
}

class IntelliumBalanceCard extends StatelessWidget {
  final double startingBalance;
  final double totalIncomeAdded;
  final double availableBalance;
  final double savingsBalance;
  final double projectedAvailableBalance;
  final double upcomingBillsAmount;
  final VoidCallback onStartingBalanceTap;
  final VoidCallback onIncomeTap;
  final VoidCallback onSavingsTap;
  final VoidCallback onBillsTap;

  const IntelliumBalanceCard({
    super.key,
    required this.startingBalance,
    required this.totalIncomeAdded,
    required this.availableBalance,
    required this.savingsBalance,
    required this.projectedAvailableBalance,
    required this.upcomingBillsAmount,
    required this.onStartingBalanceTap,
    required this.onIncomeTap,
    required this.onSavingsTap,
    required this.onBillsTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final overview = availableBalance;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: ui.isJade
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF133627),
                  Color(0xFF0C2218),
                  Color(0xFF091611)
                ],
                stops: [0.0, 0.52, 1.0],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A2551),
                  intelliumBlue,
                  intelliumPurple,
                  intelliumPink
                ],
                stops: [0.0, 0.28, 0.68, 1.0],
              ),
        boxShadow: [
          BoxShadow(
            color: ui.isJade
                ? const Color(0xFF2EE6A6).withValues(alpha: .22)
                : intelliumBlue.withValues(alpha: .18),
            blurRadius: 34,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: ui.isJade
                ? const Color(0xFF9DFFE0).withValues(alpha: .12)
                : intelliumPink.withValues(alpha: .12),
            blurRadius: 48,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: ui.isJade ? .10 : .14),
                  borderRadius: BorderRadius.circular(999),
                  border: ui.isJade
                      ? Border.all(color: const Color(0x442EE6A6))
                      : null,
                ),
                child: Text(
                  'Balance Overview',
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.auto_awesome_rounded, color: ui.textPrimary, size: 18),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Available Balance',
            style: TextStyle(
              color: ui.isJade ? ui.textSecondary : const Color(0xE6F6F7FF),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatPhp(overview),
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Money you can use now: Opening Balance plus Income, minus Spending, Paid Bills, and net savings transfers.',
            style: TextStyle(
              color: ui.isJade ? ui.textSecondary : const Color(0xD9F6F7FF),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _IntelliumBalanceMiniStat(
                  label: 'Opening Balance',
                  value: formatPhp(startingBalance),
                  onTap: onStartingBalanceTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _IntelliumBalanceMiniStat(
                  label: 'Anticipated Balance',
                  value: formatPhp(projectedAvailableBalance),
                  onTap: onIncomeTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _IntelliumBalanceMiniStat(
                  label: 'Savings Balance',
                  value: formatPhp(savingsBalance),
                  onTap: onSavingsTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _IntelliumBalanceMiniStat(
                  label: 'Upcoming Bills',
                  value: formatPhp(upcomingBillsAmount),
                  onTap: onBillsTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntelliumBalanceMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _IntelliumBalanceMiniStat({
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: ui.isJade ? .08 : .12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: ui.isJade
                  ? const Color(0x442EE6A6)
                  : Colors.white.withValues(alpha: .08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ui.isJade ? ui.textSecondary : const Color(0xCCF6F7FF),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeQuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const HomeQuickActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          decoration: ui.cardDecoration(radius: 20),
          child: Column(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: ui.iconChipBackground(color, radius: 14),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ui.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: ui.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: ui.textMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class HomeOverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const HomeOverviewCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final content = Container(
      padding: const EdgeInsets.all(18),
      decoration: ui.cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: ui.iconChipBackground(color, radius: 14),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ui.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ui.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: content,
      ),
    );
  }
}

class HomeToolCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const HomeToolCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: ui.cardDecoration(radius: 24),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: ui.iconChipBackground(color, radius: 16),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ui.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: ui.textMuted, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumToolScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget>? actions;

  const PremiumToolScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        toolbarHeight: 72,
        actions: actions,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                  color: ui.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: SafeArea(child: child),
    );
  }
}

class PremiumCalculatorScreen extends StatefulWidget {
  const PremiumCalculatorScreen({super.key});

  @override
  State<PremiumCalculatorScreen> createState() =>
      _PremiumCalculatorScreenState();
}

class _PremiumCalculatorScreenState extends State<PremiumCalculatorScreen> {
  String display = '0';
  double? storedValue;
  String? pendingOperator;
  bool shouldResetDisplay = false;

  void handleInput(String value) {
    setState(() {
      switch (value) {
        case 'C':
          display = '0';
          storedValue = null;
          pendingOperator = null;
          shouldResetDisplay = false;
          return;
        case '\u232B':
          if (shouldResetDisplay) {
            display = '0';
            shouldResetDisplay = false;
            return;
          }
          if (display.length <= 1 ||
              (display.startsWith('-') && display.length == 2)) {
            display = '0';
            return;
          }
          display = display.substring(0, display.length - 1);
          return;
        case '+/-':
          if (display == '0') return;
          display =
              display.startsWith('-') ? display.substring(1) : '-$display';
          return;
        case '%':
          final current = double.tryParse(display) ?? 0;
          display = _formatResult(current / 100);
          shouldResetDisplay = true;
          return;
        case '.':
          if (shouldResetDisplay) {
            display = '0.';
            shouldResetDisplay = false;
            return;
          }
          if (!display.contains('.')) {
            display = '$display.';
          }
          return;
        case '+':
        case '-':
        case '\u00D7':
        case '\u00F7':
          _prepareOperation(value);
          return;
        case '=':
          _resolvePendingOperation();
          pendingOperator = null;
          shouldResetDisplay = true;
          return;
        default:
          if (shouldResetDisplay || display == '0') {
            display = value;
            shouldResetDisplay = false;
          } else {
            display += value;
          }
      }
    });
  }

  void _prepareOperation(String operatorSymbol) {
    if (pendingOperator != null && !shouldResetDisplay) {
      _resolvePendingOperation();
    } else {
      storedValue = double.tryParse(display) ?? 0;
    }
    pendingOperator = operatorSymbol;
    shouldResetDisplay = true;
  }

  void _resolvePendingOperation() {
    if (pendingOperator == null || storedValue == null) return;
    final current = double.tryParse(display) ?? 0;
    final left = storedValue!;
    double result;

    switch (pendingOperator) {
      case '+':
        result = left + current;
        break;
      case '-':
        result = left - current;
        break;
      case '\u00D7':
        result = left * current;
        break;
      case '\u00F7':
        if (current == 0) {
          display = 'Error';
          storedValue = null;
          pendingOperator = null;
          shouldResetDisplay = true;
          return;
        }
        result = left / current;
        break;
      default:
        result = current;
    }

    storedValue = result;
    display = _formatResult(result);
  }

  String _formatResult(double value) {
    if (value.isNaN || value.isInfinite) return 'Error';
    final whole = value.truncateToDouble() == value;
    return whole ? value.toStringAsFixed(0) : value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    const buttons = [
      'C',
      '+/-',
      '%',
      '\u00F7',
      '7',
      '8',
      '9',
      '\u00D7',
      '4',
      '5',
      '6',
      '-',
      '1',
      '2',
      '3',
      '+',
      '0',
      '.',
      '\u232B',
      '=',
    ];

    return PremiumToolScaffold(
      title: 'Calculator',
      subtitle: 'Basic math tools for quick totals and budget checks',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: ui.premiumCtaDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    pendingOperator == null
                        ? 'Ready'
                        : 'Operation: $pendingOperator',
                    style: TextStyle(
                        color: ui.isJade ? ui.textSecondary : Colors.white70,
                        fontSize: 12.5),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      display,
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: buttons.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.08,
              ),
              itemBuilder: (context, index) {
                final label = buttons[index];
                final isOperator = {
                  '\u00F7',
                  '\u00D7',
                  '-',
                  '+',
                  '=',
                  '%',
                  'C',
                  '\u232B',
                  '+/-'
                }.contains(label);
                final accent = label == '='
                    ? Theme.of(context).colorScheme.primary
                    : isOperator
                        ? intelliumBlue
                        : intelliumCyan;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => handleInput(label),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      decoration: ui.cardDecoration(radius: 22).copyWith(
                            gradient: label == '=' ? ui.accentGradient : null,
                          ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: label == '=' ? intelliumBackground : accent,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumTodoListScreen extends StatefulWidget {
  const PremiumTodoListScreen({super.key});

  @override
  State<PremiumTodoListScreen> createState() => _PremiumTodoListScreenState();
}

class _PremiumTodoListScreenState extends State<PremiumTodoListScreen> {
  final TextEditingController taskController = TextEditingController();
  List<TodoTaskItem> tasks = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(loadTasks());
  }

  Future<void> loadTasks() async {
    final loaded = await FinanceRepository.loadToolTodoItems();
    if (!mounted) return;
    setState(() {
      tasks = loaded;
      loading = false;
    });
  }

  Future<void> persistTasks(List<TodoTaskItem> updated) async {
    await FinanceRepository.saveToolTodoItems(updated);
    if (!mounted) return;
    setState(() {
      tasks = updated;
    });
  }

  Future<void> addTask() async {
    final title = taskController.text.trim();
    if (title.isEmpty) return;
    final updated = [
      ...tasks,
      TodoTaskItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        isCompleted: false,
        createdAt: DateTime.now(),
      ),
    ];
    taskController.clear();
    await persistTasks(updated);
  }

  Future<void> toggleTask(TodoTaskItem task) async {
    final updated = tasks
        .map((item) => item.id == task.id
            ? item.copyWith(isCompleted: !item.isCompleted)
            : item)
        .toList();
    await persistTasks(updated);
  }

  Future<void> deleteTask(TodoTaskItem task) async {
    final updated = tasks.where((item) => item.id != task.id).toList();
    await persistTasks(updated);
  }

  @override
  void dispose() {
    taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final completedCount = tasks.where((task) => task.isCompleted).length;

    return PremiumToolScaffold(
      title: 'To-Do List',
      subtitle: 'Local task notes for reminders, errands, and bill follow-ups',
      actions: [
        if (tasks.isNotEmpty)
          IconButton(
            onPressed: () async {
              await persistTasks([]);
            },
            icon: Icon(Icons.delete_sweep_rounded, color: ui.textMuted),
          ),
      ],
      child: loading
          ? const Center(child: CircularProgressIndicator(color: intelliumCyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: ui.sectionContainerDecoration(),
                    child: Column(
                      children: [
                        TextField(
                          controller: taskController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => unawaited(addTask()),
                          decoration: const InputDecoration(
                            labelText: 'New task',
                            hintText: 'Add a reminder or quick task',
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              unawaited(addTask());
                            },
                            child: const Text(
                              'Add Task',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SummaryCard(
                          title: 'Tasks',
                          value: '${tasks.length}',
                          subtitle: 'Saved locally',
                          color: intelliumBlue,
                          icon: Icons.checklist_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SummaryCard(
                          title: 'Done',
                          value: '$completedCount',
                          subtitle: 'Completed items',
                          color: intelliumCyan,
                          icon: Icons.verified_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (tasks.isEmpty)
                    const EmptyStateCard(
                      icon: Icons.playlist_add_check_circle_rounded,
                      title: 'No tasks yet',
                      subtitle:
                          'Add your first to-do item to start tracking local reminders.',
                    )
                  else
                    ...tasks.map((task) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: ui.cardDecoration(radius: 22),
                          child: CheckboxListTile(
                            value: task.isCompleted,
                            onChanged: (_) => unawaited(toggleTask(task)),
                            activeColor: Theme.of(context).colorScheme.primary,
                            checkColor: intelliumBackground,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            title: Text(
                              task.title,
                              style: TextStyle(
                                color: ui.textPrimary,
                                fontWeight: FontWeight.w700,
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              formatCalendarDate(task.createdAt),
                              style: TextStyle(
                                  color: ui.textMuted, fontSize: 12.5),
                            ),
                            secondary: IconButton(
                              onPressed: () => unawaited(deleteTask(task)),
                              icon: const Icon(Icons.delete_outline_rounded),
                              color: intelliumPink,
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class TrackerInfo {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double progress;

  TrackerInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.progress,
  });
}

class SpendingTrendCard extends StatelessWidget {
  final List<double> values;

  const SpendingTrendCard({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final hasData = values.any((value) => value > 0);
    final maxValue = hasData ? values.reduce(max) : 1.0;
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final today = dateOnly(DateTime.now());
    final days = List.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: ui.analyticsDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '7-Day Spending Trend',
                      style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on your last 7 calendar days of saved spending entries',
                      style: TextStyle(color: ui.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: ui.iconChipBackground(
                  Theme.of(context).colorScheme.primary,
                  radius: 14,
                ),
                child: Text(
                  hasData ? formatPhp(total) : 'No recent data',
                  style: TextStyle(
                      color: ui.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!hasData)
            const EmptyStateCard(
              icon: Icons.show_chart_rounded,
              title: 'No spending trend yet',
              subtitle:
                  'Add spending in the next 7 days to see your rolling 7-day spending chart.',
            )
          else
            SizedBox(
              height: 170,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(values.length, (index) {
                  final value = values[index];
                  final barHeight =
                      value <= 0 ? 10.0 : max(14.0, 96 * (value / maxValue));
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            value <= 0 ? '-' : formatPhp(value),
                            style: TextStyle(
                              color:
                                  value <= 0 ? ui.textMuted : ui.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            height: barHeight,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: value <= 0
                                  ? null
                                  : ui.analyticsAccentGradient,
                              color: value <= 0
                                  ? ui.cardFill.withValues(alpha: .72)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            shortWeekdayLabel(days[index]),
                            style: TextStyle(
                                color: ui.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class MonthlySpendingTrendCard extends StatelessWidget {
  final List<double> values;

  const MonthlySpendingTrendCard({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final hasData = values.any((value) => value > 0);
    final maxValue = hasData ? values.reduce(max) : 1.0;
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final labels = getLast12MonthLabels();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: ui.analyticsDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '12-Month Spending Trend',
                      style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Monthly spending totals from your saved spending entries',
                      style: TextStyle(color: ui.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: ui.iconChipBackground(
                  Theme.of(context).colorScheme.primary,
                  radius: 14,
                ),
                child: Text(
                  hasData ? formatPhp(total) : 'No yearly spending yet',
                  style: TextStyle(
                      color: ui.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!hasData)
            const EmptyStateCard(
              icon: Icons.bar_chart_rounded,
              title: 'No monthly spending trend yet',
              subtitle:
                  'Add dated spending entries to build your 12-month spending view.',
            )
          else
            SizedBox(
              height: 190,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(values.length, (index) {
                  final value = values[index];
                  final barHeight =
                      value <= 0 ? 10.0 : max(14.0, 108 * (value / maxValue));
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            value <= 0 ? '-' : formatPhp(value),
                            style: TextStyle(
                              color:
                                  value <= 0 ? ui.textMuted : ui.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            height: barHeight,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: value <= 0
                                  ? null
                                  : ui.analyticsAccentGradient,
                              color: value <= 0
                                  ? ui.cardFill.withValues(alpha: .72)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            labels[index],
                            style: TextStyle(
                                color: ui.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class IntelliumAnalyticsCard extends StatelessWidget {
  final List<double> values;
  final VoidCallback onTap;

  const IntelliumAnalyticsCard({
    super.key,
    required this.values,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final hasData = values.any((value) => value > 0);
    final maxValue = hasData ? values.reduce(max) : 1.0;
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final today = dateOnly(DateTime.now());
    final days = List.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: ui.analyticsDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analytics',
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last 7 calendar days of spending from your saved local expense data',
                      style: TextStyle(color: ui.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: ui.iconChipBackground(
                    Theme.of(context).colorScheme.primary,
                    radius: 999,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Open',
                        style: TextStyle(
                          color: ui.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_outward_rounded,
                          color: ui.textPrimary, size: 15),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!hasData)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: ui.cardDecoration(radius: 22),
              child: Column(
                children: [
                  Icon(Icons.show_chart_rounded, color: ui.textMuted, size: 28),
                  const SizedBox(height: 10),
                  Text(
                    'No chart data yet',
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add spending in the next 7 days to light up your rolling 7-day spending trend.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ui.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatPhp(total),
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'spent over the last 7 days',
                        style: TextStyle(color: ui.textMuted, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 170,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(values.length, (index) {
                      final value = values[index];
                      final barHeight = value <= 0
                          ? 12.0
                          : max(18.0, 100 * (value / maxValue));
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                value <= 0 ? '-' : formatPhp(value),
                                style: TextStyle(
                                  color: value <= 0
                                      ? ui.textMuted
                                      : ui.textSecondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: value <= 0
                                      ? null
                                      : ui.analyticsAccentGradient,
                                  color: value <= 0
                                      ? ui.cardFill.withValues(alpha: .72)
                                      : null,
                                  boxShadow: value <= 0
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: ui.shadowColor.withValues(
                                                alpha: ui.isJade ? .35 : .20),
                                            blurRadius: 22,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                shortWeekdayLabel(days[index]),
                                style: TextStyle(
                                  color: ui.textMuted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class PremiumPlanCard extends StatelessWidget {
  final PremiumService premiumService;

  const PremiumPlanCard({
    super.key,
    required this.premiumService,
  });

  @override
  Widget build(BuildContext context) {
    const isComingSoon = !premiumLaunchEnabled;
    final canStartPurchase = !isComingSoon && premiumService.canPurchasePremium;
    final statusLabel = isComingSoon
        ? premiumTemporarilyUnavailableLabel
        : premiumService.premiumStatusLabel;
    final actionLabel = isComingSoon
        ? premiumTemporarilyUnavailableActionLabel
        : premiumService.premiumActionLabel;
    final supportingNote = isComingSoon
        ? premiumPurchasesUnavailableMessage
        : premiumService.isPremium
            ? 'Premium benefits are active on this device.'
            : premiumService.premiumStatusDetail;
    final statusAccent = premiumService.isPremium
        ? _PremiumPalette.cyan
        : premiumService.isPurchasePending
            ? _PremiumPalette.gold
            : premiumService.requiresBackendVerificationSetup ||
                    !canStartPurchase
                ? _PremiumPalette.sky
                : _PremiumPalette.lilac;

    return _PremiumShowcaseShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 920;
          final narrow = constraints.maxWidth < 540;
          final benefitColumns = constraints.maxWidth < 520
              ? 1
              : constraints.maxWidth < 840
                  ? 2
                  : 3;
          const orbitChips = [
            _PremiumOrbitChip(
              icon: Icons.auto_graph_rounded,
              label: 'Insights',
              accent: _PremiumPalette.cyan,
            ),
            _PremiumOrbitChip(
              icon: Icons.psychology_alt_rounded,
              label: 'Smart Tools',
              accent: _PremiumPalette.sky,
            ),
            _PremiumOrbitChip(
              icon: Icons.palette_outlined,
              label: 'Themes',
              accent: _PremiumPalette.lilac,
            ),
            _PremiumOrbitChip(
              icon: Icons.track_changes_rounded,
              label: 'Daily Limit',
              accent: _PremiumPalette.violet,
            ),
          ];

          final copyColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (narrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PremiumHeaderLockup(
                      subtitle: premiumService.isPremium
                          ? 'Verified premium access is ready on this device'
                          : 'Release-ready premium access through Google Play',
                    ),
                    const SizedBox(height: 12),
                    _PremiumStatusBadge(
                      label: statusLabel,
                      accent: statusAccent,
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PremiumHeaderLockup(
                        subtitle: premiumService.isPremium
                            ? 'Verified premium access is ready on this device'
                            : 'Release-ready premium access through Google Play',
                      ),
                    ),
                    const SizedBox(width: 12),
                    _PremiumStatusBadge(
                      label: statusLabel,
                      accent: statusAccent,
                    ),
                  ],
                ),
              const SizedBox(height: 28),
              Text(
                'SweldoTrack Premium',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .90),
                  fontSize: wide ? 18 : 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Smarter budget tracking for ${premiumService.priceLabel}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: wide
                      ? 40
                      : narrow
                          ? 28
                          : 34,
                  fontWeight: FontWeight.w900,
                  height: 1.02,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: const Text(
                  'Track your spending deeper, unlock premium insights, personalize your theme, and use smarter tools designed for Filipino payday budgeting.',
                  style: TextStyle(
                    color: _PremiumPalette.textSoft,
                    fontSize: 15,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(narrow ? 18 : 22),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(28),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .08)),
                  boxShadow: [
                    BoxShadow(
                      color: _PremiumPalette.cyan.withValues(alpha: .08),
                      blurRadius: 28,
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0x1FFFFFFF),
                                Color(0x12FFFFFF),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                premiumService.priceLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Monthly subscription',
                                style: TextStyle(
                                  color: _PremiumPalette.textSoft,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const _PremiumFeaturePill(
                          icon: Icons.workspace_premium_rounded,
                          label: 'Verified premium access',
                        ),
                        const _PremiumFeaturePill(
                          icon: Icons.lock_clock_rounded,
                          label: 'Monthly, flexible billing',
                        ),
                      ],
                    ),
                    if (!isComingSoon && premiumService.isLoadingProduct) ...[
                      const SizedBox(height: 16),
                      const _PremiumInlineNotice(
                        icon: Icons.sync_rounded,
                        message: 'Loading the latest Google Play pricing...',
                        accent: _PremiumPalette.cyan,
                      ),
                    ],
                    if (!isComingSoon && premiumService.isPurchasePending) ...[
                      const SizedBox(height: 16),
                      const _PremiumInlineNotice(
                        icon: Icons.hourglass_top_rounded,
                        message: 'Your purchase is pending in Google Play.',
                        accent: _PremiumPalette.gold,
                      ),
                    ],
                    if (!isComingSoon &&
                        premiumService.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _PremiumInlineNotice(
                        icon: Icons.info_outline_rounded,
                        message: premiumService.errorMessage!,
                        accent: const Color(0xFFFF9DB0),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: canStartPurchase
                            ? () async {
                                await premiumService.buyPremium();
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canStartPurchase
                              ? Colors.white
                              : Colors.white.withValues(alpha: .08),
                          foregroundColor: canStartPurchase
                              ? _PremiumPalette.background
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                            side: BorderSide(
                              color: canStartPurchase
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: .10),
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          actionLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _PremiumTrustBadge(
                          icon: Icons.verified_user_rounded,
                          label: 'Secure checkout by Google Play',
                        ),
                        _PremiumTrustBadge(
                          icon: Icons.event_repeat_rounded,
                          label: 'Cancel anytime through Google Play',
                        ),
                        _PremiumTrustBadge(
                          icon: Icons.restore_rounded,
                          label: 'Restore purchase anytime',
                        ),
                        _PremiumTrustBadge(
                          icon: Icons.shield_rounded,
                          label: 'Premium activates after verification',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      supportingNote,
                      style: const TextStyle(
                        color: _PremiumPalette.textMuted,
                        fontSize: 12.5,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'What you unlock',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .94),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: benefitColumns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: benefitColumns == 1
                    ? 4.6
                    : benefitColumns == 2
                        ? 2.45
                        : 2.05,
                children: const [
                  _PremiumBenefitCard(
                    icon: Icons.auto_graph_rounded,
                    label: 'Premium Analytics',
                    accent: _PremiumPalette.cyan,
                  ),
                  _PremiumBenefitCard(
                    icon: Icons.psychology_alt_rounded,
                    label: 'Smart Expense Detection',
                    accent: _PremiumPalette.sky,
                  ),
                  _PremiumBenefitCard(
                    icon: Icons.tune_rounded,
                    label: 'Advanced Budget Tools',
                    accent: _PremiumPalette.violet,
                  ),
                  _PremiumBenefitCard(
                    icon: Icons.palette_rounded,
                    label: 'Extra Themes',
                    accent: _PremiumPalette.lilac,
                  ),
                  _PremiumBenefitCard(
                    icon: Icons.groups_rounded,
                    label: 'Referral Tools',
                    accent: _PremiumPalette.gold,
                  ),
                  _PremiumBenefitCard(
                    icon: Icons.bolt_rounded,
                    label: 'Priority Updates',
                    accent: _PremiumPalette.cyan,
                  ),
                ],
              ),
            ],
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 12, child: copyColumn),
                const SizedBox(width: 24),
                const Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: _PremiumPhonePreviewCard()),
                      SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: orbitChips,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              copyColumn,
              const SizedBox(height: 26),
              const Center(child: _PremiumPhonePreviewCard()),
              const SizedBox(height: 16),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: orbitChips,
              ),
            ],
          );
        },
      ),
    );
  }
}

class PremiumFeatureLockCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final PremiumService premiumService;

  const PremiumFeatureLockCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.premiumService,
  });

  @override
  Widget build(BuildContext context) {
    const isComingSoon = !premiumLaunchEnabled;
    final canStartPurchase = !isComingSoon && premiumService.canPurchasePremium;
    final planLabel = isComingSoon
        ? premiumTemporarilyUnavailableLabel
        : premiumService.isPremium
            ? 'Premium is active'
            : premiumService.requiresBackendVerificationSetup
                ? premiumTemporarilyUnavailableLabel
                : premiumService.premiumStatusLabel == 'Free'
                    ? 'Upgrade to unlock premium features.'
                    : premiumService.premiumStatusLabel;
    final badgeLabel = isComingSoon
        ? 'Preview'
        : premiumService.requiresBackendVerificationSetup
            ? 'Unavailable'
            : 'Locked';
    final badgeAccent = isComingSoon
        ? _PremiumPalette.gold
        : premiumService.requiresBackendVerificationSetup
            ? _PremiumPalette.sky
            : _PremiumPalette.lilac;

    return _PremiumShowcaseShell(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          const previewTiles = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PremiumMiniPreviewTile(
                label: 'Weekly View',
                value: '7 days',
                accent: _PremiumPalette.cyan,
              ),
              _PremiumMiniPreviewTile(
                label: 'Theme Pack',
                value: '2 styles',
                accent: _PremiumPalette.sky,
              ),
              _PremiumMiniPreviewTile(
                label: 'Tool Access',
                value: 'Launch',
                accent: _PremiumPalette.lilac,
              ),
            ],
          );

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .12),
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: _PremiumPalette.lilac,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          planLabel,
                          style: const TextStyle(
                            color: _PremiumPalette.cyan,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _PremiumStatusBadge(
                    label: badgeLabel,
                    accent: badgeAccent,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _PremiumPalette.textSoft,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              const Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PremiumFeaturePill(
                    icon: Icons.auto_graph_rounded,
                    label: '7-day insight',
                  ),
                  _PremiumFeaturePill(
                    icon: Icons.palette_outlined,
                    label: 'Custom themes',
                  ),
                  _PremiumFeaturePill(
                    icon: Icons.widgets_outlined,
                    label: 'Premium tools',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              previewTiles,
              const SizedBox(height: 16),
              if (!isComingSoon && premiumService.isLoadingProduct)
                const Text(
                  'Loading pricing...',
                  style: TextStyle(
                    color: _PremiumPalette.textSoft,
                    fontSize: 12.5,
                  ),
                )
              else if (!isComingSoon && !premiumService.isAvailable)
                const Text(
                  'Google Play Billing is unavailable on this device.',
                  style: TextStyle(
                    color: _PremiumPalette.textSoft,
                    fontSize: 12.5,
                  ),
                )
              else
                Text(
                  planLabel,
                  style: const TextStyle(
                    color: _PremiumPalette.textSoft,
                    fontSize: 12.5,
                  ),
                ),
              if (!isComingSoon && premiumService.errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  premiumService.errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFFF9DB0),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canStartPurchase
                      ? () async {
                          await premiumService.buyPremium();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _PremiumPalette.background,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    premiumService.premiumActionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          );

          if (!wide) return content;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 10, child: content),
              const SizedBox(width: 18),
              const Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _PremiumOrbitChip(
                      icon: Icons.track_changes_rounded,
                      label: 'Planning',
                      accent: _PremiumPalette.violet,
                    ),
                    SizedBox(height: 14),
                    _PremiumOrbitChip(
                      icon: Icons.savings_outlined,
                      label: 'Savings Target',
                      accent: _PremiumPalette.cyan,
                    ),
                    SizedBox(height: 14),
                    _PremiumOrbitChip(
                      icon: Icons.palette_outlined,
                      label: 'Themes',
                      accent: _PremiumPalette.lilac,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PremiumPalette {
  static const Color background = Color(0xFF050917);
  static const Color backgroundSoft = Color(0xFF0A1024);
  static const Color panel = Color(0xFF0E1630);
  static const Color panelStrong = Color(0xFF151D3A);
  static const Color panelGlass = Color(0xCC111A36);
  static const Color edge = Color(0x26FFFFFF);
  static const Color textMuted = Color(0xFF8993BF);
  static const Color textSoft = Color(0xFFC9D0EB);
  static const Color cyan = Color(0xFF46D4FF);
  static const Color sky = Color(0xFF68A6FF);
  static const Color violet = Color(0xFF6E65FF);
  static const Color lilac = Color(0xFFBA7BFF);
  static const Color gold = Color(0xFFFFCC67);
}

class _PremiumShowcaseShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _PremiumShowcaseShell({
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _PremiumPalette.background,
            _PremiumPalette.backgroundSoft,
            Color(0xFF120F2D),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
        boxShadow: [
          BoxShadow(
            color: _PremiumPalette.cyan.withValues(alpha: .10),
            blurRadius: 40,
            spreadRadius: -3,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: _PremiumPalette.violet.withValues(alpha: .10),
            blurRadius: 42,
            spreadRadius: -8,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .34),
            blurRadius: 36,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Stack(
          children: [
            Positioned(
              left: -90,
              bottom: -100,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _PremiumPalette.cyan.withValues(alpha: .24),
                      _PremiumPalette.cyan.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -60,
              top: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _PremiumPalette.lilac.withValues(alpha: .22),
                      _PremiumPalette.lilac.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -60,
              right: -40,
              bottom: 120,
              child: Transform.rotate(
                angle: -0.18,
                child: Container(
                  height: 128,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(120),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        _PremiumPalette.cyan.withValues(alpha: .08),
                        _PremiumPalette.lilac.withValues(alpha: .14),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .04),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: .03),
                      Colors.transparent,
                      Colors.black.withValues(alpha: .06),
                    ],
                    stops: const [0, .22, 1],
                  ),
                ),
              ),
            ),
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumBrandLockup extends StatelessWidget {
  const _PremiumBrandLockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF29489A),
                _PremiumPalette.cyan,
                _PremiumPalette.violet,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _PremiumPalette.cyan.withValues(alpha: .18),
                blurRadius: 20,
                spreadRadius: -3,
              ),
              BoxShadow(
                color: _PremiumPalette.violet.withValues(alpha: .18),
                blurRadius: 26,
                spreadRadius: -6,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/icon/sweldotrack_icon.png',
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SweldoTrack',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      size: 14,
                      color: _PremiumPalette.cyan,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'SweldoTrack Premium',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _PremiumPalette.textSoft,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumHeaderLockup extends StatelessWidget {
  final String subtitle;

  const _PremiumHeaderLockup({
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF29489A),
                _PremiumPalette.cyan,
                _PremiumPalette.violet,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _PremiumPalette.cyan.withValues(alpha: .16),
                blurRadius: 22,
                spreadRadius: -4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/icon/sweldotrack_icon.png',
              width: 52,
              height: 52,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SweldoTrack',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _PremiumPalette.textSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumStatusBadge extends StatelessWidget {
  final String label;
  final Color accent;

  const _PremiumStatusBadge({
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: .16),
            accent.withValues(alpha: .08),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: .28)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .12),
            blurRadius: 18,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

class _PremiumInlineNotice extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color accent;

  const _PremiumInlineNotice({
    required this.icon,
    required this.message,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: .20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: accent == const Color(0xFFFF9DB0)
                    ? accent
                    : Colors.white.withValues(alpha: .90),
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumBenefitCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _PremiumBenefitCard({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _PremiumPalette.panelStrong,
            _PremiumPalette.panel,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _PremiumPalette.edge),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: .26)),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumFeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PremiumFeaturePill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _PremiumPalette.cyan, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumTrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PremiumTrustBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _PremiumPalette.cyan, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _PremiumPalette.textSoft,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumPhonePreviewCard extends StatelessWidget {
  const _PremiumPhonePreviewCard();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF050814),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: Colors.white.withValues(alpha: .14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .34),
              blurRadius: 34,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: _PremiumPalette.cyan.withValues(alpha: .10),
              blurRadius: 20,
              spreadRadius: -8,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E20),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 88,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Premium Dashboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'A quick look at your smarter budget view',
                          style: TextStyle(
                            color: _PremiumPalette.textSoft,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .08),
                      ),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: _PremiumPalette.lilac,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF122048),
                      Color(0xFF191B44),
                      Color(0xFF2A1B57),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .08)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'This cutoff',
                            style: TextStyle(
                              color: _PremiumPalette.textSoft,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _PremiumStatusBadge(
                          label: 'Verified',
                          accent: _PremiumPalette.cyan,
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Weekly Trend',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _PremiumSparkBar(
                            height: 24, accent: _PremiumPalette.sky),
                        SizedBox(width: 6),
                        _PremiumSparkBar(
                            height: 42, accent: _PremiumPalette.cyan),
                        SizedBox(width: 6),
                        _PremiumSparkBar(
                            height: 30, accent: _PremiumPalette.lilac),
                        SizedBox(width: 6),
                        _PremiumSparkBar(
                            height: 54, accent: _PremiumPalette.cyan),
                        SizedBox(width: 6),
                        _PremiumSparkBar(
                            height: 38, accent: _PremiumPalette.sky),
                        SizedBox(width: 6),
                        _PremiumSparkBar(
                            height: 50, accent: _PremiumPalette.violet),
                        SizedBox(width: 6),
                        _PremiumSparkBar(
                            height: 34, accent: _PremiumPalette.cyan),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Your last 7 days are easier to compare at a glance.',
                      style: TextStyle(
                        color: _PremiumPalette.textSoft,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(
                    child: _PremiumPreviewMetricCard(
                      title: 'Smart Detection',
                      value: '2 suggested',
                      subtitle: 'GCash transfer and Grab order spotted',
                      accent: _PremiumPalette.sky,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _PremiumPreviewMetricCard(
                      title: 'Safe Daily Limit',
                      value: '\u20B1690/day',
                      subtitle: 'Stays on track for the next 4 days',
                      accent: _PremiumPalette.violet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _PremiumPreviewMetricCard(
                title: 'Premium Dashboard',
                value: 'Spending, trends, and insights in one view',
                subtitle:
                    'Built to feel fast, clear, and reliable on payday weeks.',
                accent: _PremiumPalette.gold,
                compactValue: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumSparkBar extends StatelessWidget {
  final double height;
  final Color accent;

  const _PremiumSparkBar({
    required this.height,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              accent.withValues(alpha: .45),
              accent,
            ],
          ),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _PremiumPreviewMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final bool compactValue;

  const _PremiumPreviewMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    this.compactValue = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _PremiumPalette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: compactValue ? 17 : 14.5,
              height: compactValue ? 1.15 : 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: _PremiumPalette.textSoft,
              fontSize: 10.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumPhoneStatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _PremiumPhoneStatTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _PremiumPalette.panelStrong,
            _PremiumPalette.panel,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _PremiumPalette.edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumOrbitChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _PremiumOrbitChip({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: .38)),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 26),
          const SizedBox(height: 12),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumMiniPreviewTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _PremiumMiniPreviewTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 122,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _PremiumPalette.textSoft,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class ThemeSelectionCard extends StatelessWidget {
  final AppThemeController themeController;
  final bool hasPremium;

  const ThemeSelectionCard({
    super.key,
    required this.themeController,
    required this.hasPremium,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: ui.sectionContainerDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Theme',
            style: TextStyle(
                color: ui.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Your selected theme is saved locally and applied instantly.',
            style: TextStyle(color: ui.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          ...sweldoThemeDefinitions.map<Widget>((theme) {
            final isFreeTheme = isFreeSweldoTheme(theme.preset);
            final isLocked = !hasPremium && !isFreeTheme;
            final isSelected =
                themeController.effectivePreset(hasPremium: hasPremium) ==
                    theme.preset;
            final subtitle = switch (theme.preset) {
              SweldoThemePreset.emerald => 'Current Intellium default',
              SweldoThemePreset.jade => 'Alternate free green style',
              SweldoThemePreset.ocean ||
              SweldoThemePreset.sunset =>
                'Premium custom theme',
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: isLocked
                      ? null
                      : () {
                          unawaited(themeController.setTheme(theme.preset));
                        },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: ui.cardDecoration(radius: 20).copyWith(
                          border: Border.all(
                            color:
                                isSelected ? theme.seedColor : ui.borderColor,
                            width: isSelected ? 1.4 : 1,
                          ),
                        ),
                    child: Row(
                      children: [
                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            gradient:
                                LinearGradient(colors: theme.previewColors),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                theme.label,
                                style: TextStyle(
                                    color: ui.textPrimary,
                                    fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: TextStyle(
                                    color: ui.textSecondary, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (isLocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: ui.cardFill.withValues(alpha: .8),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Premium',
                              style: TextStyle(
                                  color: ui.textSecondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12),
                            ),
                          )
                        else if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: ui.iconChipBackground(theme.seedColor,
                                radius: 999),
                            child: Text(
                              'Selected',
                              style: TextStyle(
                                  color: theme.seedColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class IntelliumFinancialHealthCard extends StatelessWidget {
  final double score;
  final String label;
  final String message;

  const IntelliumFinancialHealthCard({
    super.key,
    required this.score,
    required this.label,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final progress = (score / 100).clamp(0.0, 1.0).toDouble();
    final accent = score >= 75
        ? intelliumCyan
        : score >= 50
            ? intelliumBlue
            : score >= 30
                ? intelliumPurple
                : intelliumPink;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: ui.sectionContainerDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: ui.iconChipBackground(accent),
                child: Icon(Icons.favorite_rounded, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Financial Health',
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${score.toInt()}%',
                style: TextStyle(
                    color: accent, fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
              backgroundColor: ui.cardFill,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              color: ui.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class UpcomingBillsCard extends StatelessWidget {
  final List<BillItem> bills;
  final VoidCallback onTap;

  const UpcomingBillsCard({
    super.key,
    required this.bills,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: ui.sectionContainerDecoration(),
          child: bills.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _HomeEmptyIcon(
                      icon: Icons.receipt_long_rounded,
                      color: intelliumPink,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No upcoming bills yet',
                      style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'When you add bills, your next unpaid schedules will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ui.textSecondary, fontSize: 12.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tap to open Upcoming Bills',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: ui.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                )
              : Column(
                  children: bills.map((bill) {
                    final nextDate = resolveUpcomingBillDate(bill);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: ui.cardDecoration(radius: 20),
                        child: Row(
                          children: [
                            Container(
                              height: 42,
                              width: 42,
                              decoration: ui.iconChipBackground(intelliumPink,
                                  radius: 14),
                              child: const Icon(Icons.calendar_month_rounded,
                                  color: intelliumPink),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bill.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: ui.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Due: ${formatCalendarDate(nextDate ?? bill.dueDate)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: ui.textMuted,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  formatPhp(bill.amount),
                                  style: TextStyle(
                                    color: ui.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ),
    );
  }
}

class RecentActivityCard extends StatelessWidget {
  final List<ExpenseItem> expenses;
  final VoidCallback onTap;

  const RecentActivityCard({
    super.key,
    required this.expenses,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: ui.sectionContainerDecoration(),
          child: expenses.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _HomeEmptyIcon(
                      icon: Icons.wallet_rounded,
                      color: intelliumCyan,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No activity yet',
                      style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your latest spending entries will show here after you start tracking.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ui.textSecondary, fontSize: 12.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tap to open SweldoTrack',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: ui.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                )
              : Column(
                  children: expenses.map((expense) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: ui.cardDecoration(radius: 20),
                        child: Row(
                          children: [
                            Container(
                              height: 42,
                              width: 42,
                              decoration: ui.iconChipBackground(intelliumCyan,
                                  radius: 14),
                              child: const Icon(Icons.wallet_rounded,
                                  color: intelliumCyan),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expense.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: ui.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${expense.category} | ${formatMonthDay(expense.createdAt)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: ui.textMuted,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  formatPhp(expense.amount),
                                  style: const TextStyle(
                                    color: intelliumTextPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ),
    );
  }
}

class _HomeEmptyIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _HomeEmptyIcon({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    return Container(
      height: 52,
      width: 52,
      decoration: ui.iconChipBackground(color, radius: 18).copyWith(
            border: Border.all(
              color: ui.isJade
                  ? color.withValues(alpha: .26)
                  : color.withValues(alpha: .18),
            ),
          ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class AnalyticsScreen extends StatefulWidget {
  final int refreshKey;
  final PremiumService premiumService;

  const AnalyticsScreen({
    super.key,
    required this.refreshKey,
    required this.premiumService,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool loading = true;
  Map<String, double> categoryTotals = {};
  double openingBalance = 0;
  double totalIncomeAdded = 0;
  double totalExpenses = 0;
  double todaySpending = 0;
  double currentMonthSpending = 0;
  double currentYearSpending = 0;
  double savingsBalance = 0;
  double billsAmount = 0;
  double settledBillsAmount = 0;
  double savingsContributionsAmount = 0;
  double savingsWithdrawalsAmount = 0;
  double availableBalance = 0;
  double projectedAvailableBalance = 0;
  double dailyBudget = 0;
  bool usesManualDailyBudget = false;
  bool isManualDailyBudgetSafe = true;
  int remainingSweldoDays = 0;
  List<double> weeklyExpenseTrend = List<double>.filled(7, 0);
  List<double> monthlyExpenseTrend = List<double>.filled(12, 0);

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant AnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      load();
    }
  }

  Future<void> load() async {
    final expenses = await FinanceRepository.loadExpenses();
    final bills = await FinanceRepository.loadBills();
    final startingBalance = await FinanceRepository.getStartingBalance();
    final incomeEntries = await FinanceRepository.loadIncomeEntries();
    final days = await FinanceRepository.getDaysUntilPayday();
    final salaryReceivedDate = await FinanceRepository.getSalaryReceivedDate();
    final nextPaydayDate = await FinanceRepository.getNextPaydayDate();
    final trackedSavings = await FinanceRepository.getTrackedSavingsAmount();
    final savingsHistory = await FinanceRepository.loadSavingsHistory();
    final dailyBudgetSettings =
        await FinanceRepository.getDailyBudgetSettings();
    final overview = recalculateBudget(
      startingBalance: startingBalance,
      incomeEntries: incomeEntries,
      savingsBalance: trackedSavings,
      savingsHistory: savingsHistory,
      bills: bills,
      expenses: expenses,
      cycleStartDate: salaryReceivedDate,
      nextCutoffDate: nextPaydayDate,
      fallbackDaysUntilCutoff: days,
      useManualDailyBudget: dailyBudgetSettings.useManualDailyBudget,
      manualDailyBudget: dailyBudgetSettings.manualDailyBudget,
    );

    final totals = <String, double>{};
    for (final e in overview.activeCycleExpenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }

    final activeCycleExpenseTotal = overview.snapshot.totalLoggedExpenses;
    final rollingSevenDayTrend = getLast7DaysSpending(expenses, bills: bills);
    final rollingTwelveMonthTrend =
        getLast12MonthsSpending(expenses, bills: bills);

    if (!mounted) return;
    setState(() {
      categoryTotals = totals;
      openingBalance = startingBalance;
      totalIncomeAdded = overview.snapshot.totalIncomeAdded;
      totalExpenses = activeCycleExpenseTotal;
      todaySpending = getTodayExpensesTotal(expenses, bills: bills);
      currentMonthSpending =
          getCurrentMonthExpensesTotal(expenses, bills: bills);
      currentYearSpending = getCurrentYearExpensesTotal(expenses, bills: bills);
      savingsBalance = overview.snapshot.savingsBalance;
      billsAmount = overview.snapshot.totalBills;
      settledBillsAmount = overview.snapshot.settledBillsAmount;
      savingsContributionsAmount = overview.snapshot.savingsContributionsAmount;
      savingsWithdrawalsAmount = overview.snapshot.savingsWithdrawalsAmount;
      availableBalance = overview.snapshot.availableBalance;
      projectedAvailableBalance = overview.snapshot.projectedAvailableBalance;
      dailyBudget = overview.snapshot.dailySpendingLimit;
      usesManualDailyBudget = overview.snapshot.usesManualDailyBudget;
      isManualDailyBudgetSafe = overview.snapshot.isManualDailyBudgetSafe;
      remainingSweldoDays = overview.snapshot.remainingDays;
      weeklyExpenseTrend = rollingSevenDayTrend;
      monthlyExpenseTrend = rollingTwelveMonthTrend;
      loading = false;
    });
  }

  Widget _buildAnalyticsMetricCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    final ui = SweldoVisualStyle.fromContext(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ui.sectionFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .08),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: ui.iconChipBackground(color, radius: 16),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: ui.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final ui = SweldoVisualStyle.fromContext(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ui.sectionFill,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: .05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: ui.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final items = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics',
              style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              'Here\'s your financial overview',
              style: TextStyle(
                  color: ui.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: loading
            ? buildPageLoadingState(
                'Loading your spending and balance insights...')
            : RefreshIndicator(
                color: intelliumCyan,
                backgroundColor: ui.sectionFill,
                onRefresh: load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HeroCard(
                        colors: const [
                          Color(0xFF153048),
                          intelliumBlue,
                          intelliumPurple
                        ],
                        title: 'Available Balance',
                        value: formatPhp(availableBalance),
                        badge: remainingSweldoDays > 0
                            ? '${formatPhp(projectedAvailableBalance)} anticipated balance | $remainingSweldoDays days until cutoff'
                            : '${formatPhp(projectedAvailableBalance)} anticipated balance',
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth = constraints.maxWidth >= 900
                              ? (constraints.maxWidth - 36) / 4
                              : constraints.maxWidth >= 620
                                  ? (constraints.maxWidth - 12) / 2
                                  : constraints.maxWidth;

                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: _buildAnalyticsMetricCard(
                                  context: context,
                                  title: 'Savings Balance',
                                  value: formatPhp(savingsBalance),
                                  subtitle: 'Money set aside',
                                  color: intelliumCyan,
                                  icon: Icons.savings_rounded,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildAnalyticsMetricCard(
                                  context: context,
                                  title: 'Anticipated Balance',
                                  value: formatPhp(projectedAvailableBalance),
                                  subtitle:
                                      'Estimated balance after upcoming unpaid bills',
                                  color: const Color(0xFF00C896),
                                  icon: Icons.shield_outlined,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildAnalyticsMetricCard(
                                  context: context,
                                  title: 'Daily Spending Limit',
                                  value: formatPhp(dailyBudget),
                                  subtitle: usesManualDailyBudget
                                      ? (isManualDailyBudgetSafe
                                          ? 'Manual limit is on track'
                                          : 'Manual limit is above safe pace')
                                      : 'Auto-calculated from Anticipated Balance',
                                  color: intelliumPurple,
                                  icon: Icons.today_rounded,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildAnalyticsMetricCard(
                                  context: context,
                                  title: 'Upcoming Bills',
                                  value: formatPhp(billsAmount),
                                  subtitle: 'Due before the next cutoff',
                                  color: const Color(0xFFFFA62B),
                                  icon: Icons.receipt_long_rounded,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth = constraints.maxWidth >= 720
                              ? (constraints.maxWidth - 24) / 3
                              : constraints.maxWidth >= 480
                                  ? (constraints.maxWidth - 12) / 2
                                  : constraints.maxWidth;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: HomeOverviewCard(
                                  title: 'Opening Balance',
                                  value: formatPhp(openingBalance),
                                  subtitle: 'Starting amount',
                                  color: intelliumCyan,
                                  icon: Icons.payments_rounded,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: HomeOverviewCard(
                                  title: 'Income',
                                  value: formatPhp(totalIncomeAdded),
                                  subtitle: 'Recorded income',
                                  color: intelliumBlue,
                                  icon: Icons.account_balance_wallet_rounded,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: HomeOverviewCard(
                                  title: 'Paid Bills',
                                  value: formatPhp(settledBillsAmount),
                                  subtitle: 'Already paid once',
                                  color: intelliumPurple,
                                  icon: Icons.check_circle_rounded,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: HomeOverviewCard(
                                  title: 'Net Savings Transfers',
                                  value: formatPhp(
                                    savingsContributionsAmount -
                                        savingsWithdrawalsAmount,
                                  ),
                                  subtitle:
                                      '${formatPhp(savingsContributionsAmount)} in | ${formatPhp(savingsWithdrawalsAmount)} out',
                                  color: intelliumPink,
                                  icon: Icons.swap_horiz_rounded,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildAnalyticsSection(
                        context: context,
                        title: 'Cash Flow',
                        subtitle:
                            'Income and spending momentum using your saved spending history',
                        child: AnimatedBuilder(
                          animation: widget.premiumService,
                          builder: (context, _) {
                            if (widget.premiumService.isPremium) {
                              return Column(
                                children: [
                                  SpendingTrendCard(values: weeklyExpenseTrend),
                                  const SizedBox(height: 18),
                                  MonthlySpendingTrendCard(
                                      values: monthlyExpenseTrend),
                                ],
                              );
                            }

                            return PremiumFeatureLockCard(
                              title: 'Premium Weekly Analysis',
                              subtitle:
                                  'See your last 7 days and last 12 months of spending activity and unlock custom themes.',
                              premiumService: widget.premiumService,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      const HomeSectionHeader(
                        title: 'Spending Categories',
                        subtitle:
                            'Breakdown of your saved spending totals by category',
                      ),
                      const SizedBox(height: 14),
                      if (items.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: ui.sectionContainerDecoration(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _HomeEmptyIcon(
                                icon: Icons.bar_chart_rounded,
                                color: intelliumBlue,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No analytics yet',
                                style: TextStyle(
                                    color: ui.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Add spending first to generate your category insights.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: ui.textSecondary, fontSize: 12.5),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: ui.sectionContainerDecoration(),
                          child: Column(
                            children: items.map((e) {
                              final maxValue = items.first.value <= 0
                                  ? 1.0
                                  : items.first.value;
                              final percent = (e.value / maxValue)
                                  .clamp(0.0, 1.0)
                                  .toDouble();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: ui.cardDecoration(radius: 20),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              e.key,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: ui.textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                formatPhp(e.value),
                                                style: TextStyle(
                                                  color: ui.isJade
                                                      ? const Color(0xFF9DFFE0)
                                                      : intelliumCyan,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: LinearProgressIndicator(
                                          value: percent,
                                          minHeight: 10,
                                          backgroundColor:
                                              ui.cardFill.withValues(alpha: .8),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            ui.isJade
                                                ? const Color(0xFF45F5B6)
                                                : intelliumCyan,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

enum _PremiumAnalyticsDashboardRange { month, year }

extension on _PremiumAnalyticsDashboardRange {
  String get label {
    switch (this) {
      case _PremiumAnalyticsDashboardRange.month:
        return 'This Month';
      case _PremiumAnalyticsDashboardRange.year:
        return 'This Year';
    }
  }
}

class PremiumAnalyticsDashboardScreen extends StatefulWidget {
  final int refreshKey;
  final PremiumService premiumService;

  const PremiumAnalyticsDashboardScreen({
    super.key,
    required this.refreshKey,
    required this.premiumService,
  });

  @override
  State<PremiumAnalyticsDashboardScreen> createState() =>
      _PremiumAnalyticsDashboardScreenState();
}

class _PremiumAnalyticsDashboardScreenState
    extends State<PremiumAnalyticsDashboardScreen> {
  bool loading = true;
  _PremiumAnalyticsDashboardRange selectedRange =
      _PremiumAnalyticsDashboardRange.month;
  Map<String, double> categoryTotals = {};
  List<_PremiumAnalyticsActivityItem> recentActivity = [];
  double currentBalance = 0;
  double totalIncome = 0;
  double totalExpenses = 0;
  double todaySpending = 0;
  double currentMonthSpending = 0;
  double currentYearSpending = 0;
  double savingsBalance = 0;
  double savingsTransferred = 0;
  double savingsContributionsTotal = 0;
  double savingsWithdrawalsTotal = 0;
  double paidBillsTotal = 0;
  double unpaidBillsTotal = 0;
  double projectedAvailableBalance = 0;
  double dailyBudget = 0;
  bool usesManualDailyBudget = false;
  bool isManualDailyBudgetSafe = true;
  int remainingSweldoDays = 0;
  List<double> weeklyExpenseTrend = List<double>.filled(7, 0);
  List<double> monthlyExpenseTrend = List<double>.filled(12, 0);
  List<double> weeklyIncomeTrend = List<double>.filled(7, 0);
  List<double> monthlyIncomeTrend = List<double>.filled(12, 0);

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant PremiumAnalyticsDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      load();
    }
  }

  Future<void> load() async {
    final expenses = await FinanceRepository.loadExpenses();
    final bills = await FinanceRepository.loadBills();
    final startingBalance = await FinanceRepository.getStartingBalance();
    final incomeEntries = await FinanceRepository.loadIncomeEntries();
    final days = await FinanceRepository.getDaysUntilPayday();
    final salaryReceivedDate = await FinanceRepository.getSalaryReceivedDate();
    final nextPaydayDate = await FinanceRepository.getNextPaydayDate();
    final trackedSavings = await FinanceRepository.getTrackedSavingsAmount();
    final savingsHistory = await FinanceRepository.loadSavingsHistory();
    final dailyBudgetSettings =
        await FinanceRepository.getDailyBudgetSettings();
    final overview = recalculateBudget(
      startingBalance: startingBalance,
      incomeEntries: incomeEntries,
      savingsBalance: trackedSavings,
      savingsHistory: savingsHistory,
      bills: bills,
      expenses: expenses,
      cycleStartDate: salaryReceivedDate,
      nextCutoffDate: nextPaydayDate,
      fallbackDaysUntilCutoff: days,
      useManualDailyBudget: dailyBudgetSettings.useManualDailyBudget,
      manualDailyBudget: dailyBudgetSettings.manualDailyBudget,
    );
    final ledger = calculateBalanceLedgerSnapshot(
      startingBalance: startingBalance,
      incomeEntries: incomeEntries,
      bills: bills,
      expenses: expenses,
      savingsBalance: trackedSavings,
      savingsHistory: savingsHistory,
    );

    final totals = <String, double>{};
    for (final item in overview.activeCycleExpenses) {
      totals[item.category] = (totals[item.category] ?? 0) + item.amount;
    }

    final activities = <_PremiumAnalyticsActivityItem>[
      ...incomeEntries.map(
        (item) => _PremiumAnalyticsActivityItem(
          title: item.note.isEmpty ? 'Income' : item.note,
          subtitle: 'Income',
          amount: item.amount,
          date: item.receivedAt,
          color: intelliumCyan,
          icon: Icons.account_balance_wallet_rounded,
          isPositive: true,
        ),
      ),
      ...overview.activeCycleExpenses.map(
        (item) => _PremiumAnalyticsActivityItem(
          title: item.category,
          subtitle: 'Spending',
          amount: item.amount,
          date: item.createdAt,
          color: intelliumPink,
          icon: Icons.wallet_rounded,
          isPositive: false,
        ),
      ),
      ...bills.where((item) => item.isPaid).map(
            (item) => _PremiumAnalyticsActivityItem(
              title: 'Bill Payment',
              subtitle: 'Marked settled',
              amount: item.amount,
              date: item.paidDate ?? item.dueDate,
              color: const Color(0xFFFFA62B),
              icon: Icons.receipt_long_rounded,
              isPositive: false,
            ),
          ),
      ...savingsHistory.map(
        (item) => _PremiumAnalyticsActivityItem(
          title: item.label,
          subtitle: 'Savings transfer',
          amount: item.amount,
          date: item.createdAt,
          color: item.isContribution
              ? const Color(0xFF00C896)
              : const Color(0xFFFFC857),
          icon: item.isContribution
              ? Icons.south_west_rounded
              : Icons.north_east_rounded,
          isPositive: item.isWithdrawal,
        ),
      ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    if (!mounted) return;
    setState(() {
      categoryTotals = totals;
      recentActivity = activities.take(6).toList();
      currentBalance = ledger.currentBalance;
      totalIncome = ledger.totalIncome;
      totalExpenses = overview.snapshot.totalLoggedExpenses;
      todaySpending = getTodayExpensesTotal(expenses, bills: bills);
      currentMonthSpending =
          getCurrentMonthExpensesTotal(expenses, bills: bills);
      currentYearSpending = getCurrentYearExpensesTotal(expenses, bills: bills);
      savingsBalance = overview.snapshot.savingsBalance;
      savingsTransferred = overview.snapshot.savingsContributionsAmount -
          overview.snapshot.savingsWithdrawalsAmount;
      savingsContributionsTotal = overview.snapshot.savingsContributionsAmount;
      savingsWithdrawalsTotal = overview.snapshot.savingsWithdrawalsAmount;
      paidBillsTotal = ledger.settledBillsTotal;
      unpaidBillsTotal = overview.snapshot.upcomingBillsAmount;
      projectedAvailableBalance = overview.snapshot.projectedAvailableBalance;
      dailyBudget = overview.snapshot.dailySpendingLimit;
      usesManualDailyBudget = overview.snapshot.usesManualDailyBudget;
      isManualDailyBudgetSafe = overview.snapshot.isManualDailyBudgetSafe;
      remainingSweldoDays = overview.snapshot.remainingDays;
      weeklyExpenseTrend = getLast7DaysSpending(expenses, bills: bills);
      monthlyExpenseTrend = getLast12MonthsSpending(expenses, bills: bills);
      weeklyIncomeTrend =
          _buildPremiumAnalyticsSevenDayIncomeTrend(incomeEntries);
      monthlyIncomeTrend = _buildPremiumAnalyticsTwelveMonthIncomeTrend(
        incomeEntries,
      );
      loading = false;
    });
  }

  bool get _hasAnalyticsData {
    return currentBalance != 0 ||
        totalIncome != 0 ||
        totalExpenses != 0 ||
        paidBillsTotal != 0 ||
        savingsTransferred != 0 ||
        categoryTotals.isNotEmpty ||
        recentActivity.isNotEmpty;
  }

  List<_PremiumAnalyticsChartPoint> get _cashFlowPoints {
    if (selectedRange == _PremiumAnalyticsDashboardRange.month) {
      final labels = _buildPremiumAnalyticsRecentDayLabels();
      return List<_PremiumAnalyticsChartPoint>.generate(
        labels.length,
        (index) => _PremiumAnalyticsChartPoint(
          label: labels[index],
          income: weeklyIncomeTrend[index],
          expense: weeklyExpenseTrend[index],
        ),
      );
    }

    const monthLabels = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return List<_PremiumAnalyticsChartPoint>.generate(
      monthLabels.length,
      (index) => _PremiumAnalyticsChartPoint(
        label: monthLabels[index],
        income: monthlyIncomeTrend[index],
        expense: monthlyExpenseTrend[index],
      ),
    );
  }

  MapEntry<String, double>? get _topCategoryEntry {
    if (categoryTotals.isEmpty) return null;
    final items = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return items.first;
  }

  String get _insightHeadline {
    if (!_hasAnalyticsData) return 'No analytics yet';
    if (_topCategoryEntry != null) {
      return '${_topCategoryEntry!.key} is your top spending category';
    }
    if (paidBillsTotal > 0) return 'You already cleared some bills';
    return 'Your premium dashboard is ready';
  }

  String get _insightMessage {
    if (!_hasAnalyticsData) {
      return 'Log spending, add income, or settle bills to unlock richer premium insights.';
    }
    final averageMonthlySpend = DateTime.now().month > 0
        ? currentYearSpending / DateTime.now().month
        : 0;
    if (currentMonthSpending > 0 && averageMonthlySpend > 0) {
      final belowAverage = currentMonthSpending <= averageMonthlySpend;
      return belowAverage
          ? 'This month is tracking below your average monthly spending pace.'
          : 'This month is currently above your average monthly spending pace.';
    }
    if (_topCategoryEntry != null) {
      return 'Current top category total: ${formatPhp(_topCategoryEntry!.value)}.';
    }
    return 'Daily spending limit ${usesManualDailyBudget ? (isManualDailyBudgetSafe ? 'is on track.' : 'needs attention.') : 'is auto-calculated from Anticipated Balance.'}';
  }

  void _setRange(_PremiumAnalyticsDashboardRange range) {
    if (selectedRange == range) return;
    setState(() {
      selectedRange = range;
    });
  }

  Widget _buildPremiumDashboard(BuildContext context) {
    final items = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final wide = MediaQuery.of(context).size.width >= 860;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PremiumAnalyticsHeroCardV2(
          currentBalance: currentBalance,
          totalIncome: totalIncome,
          projectedAvailableBalance: projectedAvailableBalance,
          savingsBalance: savingsBalance,
          daysUntilCutoff: remainingSweldoDays,
          averageMonthlySpending: DateTime.now().month > 0
              ? currentYearSpending / DateTime.now().month
              : 0,
          currentMonthSpending: currentMonthSpending,
          selectedRangeLabel: selectedRange.label,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 900
                ? (constraints.maxWidth - 36) / 4
                : constraints.maxWidth >= 620
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _PremiumAnalyticsMetricCardV2(
                    title: 'Savings Balance',
                    value: formatPhp(savingsBalance),
                    subtitle: 'Money set aside',
                    color: intelliumCyan,
                    icon: Icons.savings_rounded,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _PremiumAnalyticsMetricCardV2(
                    title: 'Anticipated Balance',
                    value: formatPhp(projectedAvailableBalance),
                    subtitle: 'Estimated balance after upcoming unpaid bills',
                    color: const Color(0xFF00C896),
                    icon: Icons.shield_outlined,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _PremiumAnalyticsMetricCardV2(
                    title: 'Daily Spending Limit',
                    value: formatPhp(dailyBudget),
                    subtitle: usesManualDailyBudget
                        ? (isManualDailyBudgetSafe
                            ? 'Manual limit is on track'
                            : 'Manual limit is above safe pace')
                        : 'Auto-calculated from Anticipated Balance',
                    color: intelliumPurple,
                    icon: Icons.today_rounded,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _PremiumAnalyticsMetricCardV2(
                    title: 'Upcoming Bills',
                    value: formatPhp(unpaidBillsTotal),
                    subtitle: 'Due before the next cutoff',
                    color: const Color(0xFFFFA62B),
                    icon: Icons.receipt_long_rounded,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _PremiumAnalyticsMetricCardV2(
                    title: 'Paid Bills',
                    value: formatPhp(paidBillsTotal),
                    subtitle: 'Marked settled',
                    color: const Color(0xFFFFA62B),
                    icon: Icons.check_circle_rounded,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _PremiumAnalyticsMetricCardV2(
                    title: 'Savings Contributions',
                    value: formatPhp(savingsContributionsTotal),
                    subtitle: 'Added to savings',
                    color: const Color(0xFF00C896),
                    icon: Icons.south_west_rounded,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _PremiumAnalyticsMetricCardV2(
                    title: 'Savings Withdrawals',
                    value: formatPhp(savingsWithdrawalsTotal),
                    subtitle: 'Moved back to available',
                    color: const Color(0xFFFFC857),
                    icon: Icons.north_east_rounded,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _PremiumAnalyticsSectionV2(
          title: 'Cash Flow',
          subtitle: selectedRange == _PremiumAnalyticsDashboardRange.month
              ? 'Income vs spending over your last 7 days'
              : 'Income vs spending across the last 12 months',
          child: _hasAnalyticsData
              ? _PremiumAnalyticsCashFlowChart(
                  points: _cashFlowPoints,
                  incomeColor: intelliumCyan,
                  expenseColor: intelliumPurple,
                )
              : const _PremiumAnalyticsEmptyStateV2(
                  icon: Icons.bar_chart_rounded,
                  title: 'No cash flow data yet',
                  message:
                      'Add income, spending, or settled bills to populate your premium cash flow chart.',
                ),
        ),
        const SizedBox(height: 24),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PremiumAnalyticsSectionV2(
                  title: 'Spending by Category',
                  subtitle:
                      'Current category distribution from your saved spending data',
                  child: _PremiumAnalyticsCategoryBreakdown(
                    items: items,
                    total:
                        items.fold<double>(0, (sum, item) => sum + item.value),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _PremiumAnalyticsSectionV2(
                  title: 'Recent Activity',
                  subtitle:
                      'Latest spending, settled bills, income, and savings transfers',
                  child: _PremiumAnalyticsRecentActivityList(
                      items: recentActivity),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _PremiumAnalyticsSectionV2(
                title: 'Spending by Category',
                subtitle:
                    'Current category distribution from your saved spending data',
                child: _PremiumAnalyticsCategoryBreakdown(
                  items: items,
                  total: items.fold<double>(0, (sum, item) => sum + item.value),
                ),
              ),
              const SizedBox(height: 24),
              _PremiumAnalyticsSectionV2(
                title: 'Recent Activity',
                subtitle:
                    'Latest spending, settled bills, income, and savings transfers',
                child:
                    _PremiumAnalyticsRecentActivityList(items: recentActivity),
              ),
            ],
          ),
        const SizedBox(height: 24),
        _PremiumAnalyticsInsightCardV2(
          headline: _insightHeadline,
          message: _insightMessage,
          accent: intelliumCyan,
          secondary: intelliumPurple,
        ),
      ],
    );
  }

  Widget _buildFreeDashboard(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final items = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeroCard(
          colors: const [Color(0xFF153048), intelliumBlue, intelliumPurple],
          title: 'Available Balance',
          value: formatPhp(currentBalance),
          badge: remainingSweldoDays > 0
              ? '${formatPhp(projectedAvailableBalance)} anticipated balance | $remainingSweldoDays days until cutoff'
              : '${formatPhp(projectedAvailableBalance)} anticipated balance',
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: HomeOverviewCard(
                title: 'Savings Balance',
                value: formatPhp(savingsBalance),
                subtitle: 'Money set aside',
                color: intelliumCyan,
                icon: Icons.savings_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: HomeOverviewCard(
                title: 'Anticipated Balance',
                value: formatPhp(projectedAvailableBalance),
                subtitle: 'Estimated balance after upcoming unpaid bills',
                color: intelliumBlue,
                icon: Icons.shield_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: HomeOverviewCard(
                title: 'Paid Bills',
                value: formatPhp(paidBillsTotal),
                subtitle: 'Marked settled',
                color: intelliumPurple,
                icon: Icons.check_circle_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: HomeOverviewCard(
                title: 'Daily Spending Limit',
                value: formatPhp(dailyBudget),
                subtitle: usesManualDailyBudget
                    ? (isManualDailyBudgetSafe
                        ? 'Manual limit is on track'
                        : 'Manual limit is above safe pace')
                    : 'Auto-calculated from Anticipated Balance',
                color: intelliumPink,
                icon: Icons.today_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _PremiumAnalyticsSectionV2(
          title: 'Category Snapshot',
          subtitle: 'A simplified view of your current spending categories',
          child: items.isEmpty
              ? const _PremiumAnalyticsEmptyStateV2(
                  icon: Icons.pie_chart_outline_rounded,
                  title: 'No spending categories yet',
                  message:
                      'Your saved spending will appear here once you start logging it.',
                )
              : Column(
                  children: items
                      .take(5)
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: ui.textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                formatPhp(entry.value),
                                style: TextStyle(
                                  color: ui.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 24),
        const _PremiumAnalyticsPreviewCardV2(),
        const SizedBox(height: 16),
        PremiumFeatureLockCard(
          title: 'Unlock Premium Analytics',
          subtitle:
              'Get advanced dashboard insights, cash flow view, category breakdown, and activity history.',
          premiumService: widget.premiumService,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        toolbarHeight: 78,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics',
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Here\'s your financial overview',
              style: TextStyle(
                color: ui.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _PremiumAnalyticsRangeChipV2(
              selectedRange: selectedRange,
              onSelected: _setRange,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: loading
            ? buildPageLoadingState('Loading your premium analytics...')
            : RefreshIndicator(
                color: intelliumCyan,
                backgroundColor: ui.sectionFill,
                onRefresh: load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                  child: widget.premiumService.isPremium
                      ? _buildPremiumDashboard(context)
                      : _buildFreeDashboard(context),
                ),
              ),
      ),
    );
  }
}

class _PremiumAnalyticsRangeChipV2 extends StatelessWidget {
  final _PremiumAnalyticsDashboardRange selectedRange;
  final ValueChanged<_PremiumAnalyticsDashboardRange> onSelected;

  const _PremiumAnalyticsRangeChipV2({
    required this.selectedRange,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    return PopupMenuButton<_PremiumAnalyticsDashboardRange>(
      onSelected: onSelected,
      color: ui.sectionFill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      itemBuilder: (context) => _PremiumAnalyticsDashboardRange.values
          .map(
            (range) => PopupMenuItem<_PremiumAnalyticsDashboardRange>(
              value: range,
              child: Text(
                range.label,
                style: TextStyle(
                  color: ui.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ui.sectionFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded,
                color: intelliumCyan, size: 16),
            const SizedBox(width: 10),
            Text(
              selectedRange.label,
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down_rounded, color: ui.textMuted),
          ],
        ),
      ),
    );
  }
}

class _PremiumAnalyticsHeroCardV2 extends StatelessWidget {
  final double currentBalance;
  final double totalIncome;
  final double projectedAvailableBalance;
  final double savingsBalance;
  final int daysUntilCutoff;
  final double averageMonthlySpending;
  final double currentMonthSpending;
  final String selectedRangeLabel;

  const _PremiumAnalyticsHeroCardV2({
    required this.currentBalance,
    required this.totalIncome,
    required this.projectedAvailableBalance,
    required this.savingsBalance,
    required this.daysUntilCutoff,
    required this.averageMonthlySpending,
    required this.currentMonthSpending,
    required this.selectedRangeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final belowAverage = averageMonthlySpending <= 0
        ? currentMonthSpending <= 0
        : currentMonthSpending <= averageMonthlySpending;
    final trendColor = belowAverage ? const Color(0xFF00C896) : intelliumPink;
    final trendLabel = averageMonthlySpending <= 0
        ? 'Building trend'
        : belowAverage
            ? 'Below avg pace'
            : 'Above avg pace';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: ui.isJade
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF123526),
                  Color(0xFF0D241B),
                  Color(0xFF081611)
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF132B52),
                  Color(0xFF183B7A),
                  Color(0xFF211A4C)
                ],
              ),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
        boxShadow: [
          BoxShadow(
            color: intelliumBlue.withValues(alpha: .16),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -10,
            child: Container(
              height: 128,
              width: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: intelliumCyan.withValues(alpha: .10),
              ),
            ),
          ),
          Positioned(
            right: 34,
            bottom: -16,
            child: Container(
              height: 92,
              width: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: intelliumPurple.withValues(alpha: .10),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Available Balance',
                      style: TextStyle(
                        color: ui.textSecondary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      selectedRangeLabel,
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                formatPhp(currentBalance),
                style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: trendColor.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          belowAverage
                              ? Icons.trending_down_rounded
                              : Icons.trending_up_rounded,
                          color: trendColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          trendLabel,
                          style: TextStyle(
                            color: trendColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      daysUntilCutoff > 0
                          ? '${formatPhp(projectedAvailableBalance)} anticipated balance | $daysUntilCutoff days until cutoff'
                          : '${formatPhp(totalIncome)} income | ${formatPhp(savingsBalance)} savings',
                      style: TextStyle(
                        color: ui.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumAnalyticsMetricCardV2 extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _PremiumAnalyticsMetricCardV2({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ui.sectionFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .08),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: ui.iconChipBackground(color, radius: 16),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: ui.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumAnalyticsSectionV2 extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _PremiumAnalyticsSectionV2({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ui.sectionFill,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: .05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: ui.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _PremiumAnalyticsChartPoint {
  final String label;
  final double income;
  final double expense;

  const _PremiumAnalyticsChartPoint({
    required this.label,
    required this.income,
    required this.expense,
  });
}

class _PremiumAnalyticsCashFlowChart extends StatelessWidget {
  final List<_PremiumAnalyticsChartPoint> points;
  final Color incomeColor;
  final Color expenseColor;

  const _PremiumAnalyticsCashFlowChart({
    required this.points,
    required this.incomeColor,
    required this.expenseColor,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final maxValue = points.fold<double>(
      1,
      (current, item) => max(current, max(item.income, item.expense)),
    );

    return Column(
      children: [
        Row(
          children: [
            _PremiumAnalyticsLegendDot(color: incomeColor, label: 'Income'),
            const SizedBox(width: 18),
            _PremiumAnalyticsLegendDot(color: expenseColor, label: 'Spending'),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 220,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: points
                .map(
                  (point) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _PremiumAnalyticsMiniBar(
                                    heightFactor: point.income / maxValue,
                                    color: incomeColor,
                                  ),
                                  const SizedBox(width: 6),
                                  _PremiumAnalyticsMiniBar(
                                    heightFactor: point.expense / maxValue,
                                    color: expenseColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            point.label,
                            style: TextStyle(
                              color: ui.textMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _PremiumAnalyticsLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _PremiumAnalyticsLegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 10,
          width: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: ui.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PremiumAnalyticsMiniBar extends StatelessWidget {
  final double heightFactor;
  final Color color;

  const _PremiumAnalyticsMiniBar({
    required this.heightFactor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = heightFactor.clamp(0.0, 1.0).toDouble();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: 14,
      height: 168 * clamped,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: .95),
            color.withValues(alpha: .65),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .18),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _PremiumAnalyticsCategoryBreakdown extends StatelessWidget {
  final List<MapEntry<String, double>> items;
  final double total;

  const _PremiumAnalyticsCategoryBreakdown({
    required this.items,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    if (items.isEmpty || total <= 0) {
      return const _PremiumAnalyticsEmptyStateV2(
        icon: Icons.pie_chart_outline_rounded,
        title: 'No category data yet',
        message: 'Your saved spending will build a category breakdown here.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 420;
        final chart = SizedBox(
          height: 180,
          width: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(180),
                painter: _PremiumAnalyticsCategoryDonutPainter(
                  items: items,
                  total: total,
                  colors: _premiumAnalyticsCategoryPalette,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      color: ui.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatPhp(total),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        final legend = Column(
          children: List<Widget>.generate(
            min(items.length, 6),
            (index) {
              final entry = items[index];
              final color = _premiumAnalyticsCategoryPalette[
                  index % _premiumAnalyticsCategoryPalette.length];
              final percent = total <= 0 ? 0 : (entry.value / total) * 100;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 10,
                      width: 10,
                      margin: const EdgeInsets.only(top: 4),
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              color: ui.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatPhp(entry.value),
                            style: TextStyle(
                              color: ui.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${percent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: ui.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );

        if (stacked) {
          return Column(
            children: [
              chart,
              const SizedBox(height: 16),
              legend,
            ],
          );
        }

        return Row(
          children: [
            chart,
            const SizedBox(width: 18),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _PremiumAnalyticsCategoryDonutPainter extends CustomPainter {
  final List<MapEntry<String, double>> items;
  final double total;
  final List<Color> colors;

  const _PremiumAnalyticsCategoryDonutPainter({
    required this.items,
    required this.total,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const strokeWidth = 18.0;
    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: .08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        rect.deflate(strokeWidth), -pi / 2, pi * 2, false, basePaint);

    if (total <= 0) return;

    var startAngle = -pi / 2;
    for (var i = 0; i < items.length && i < 6; i++) {
      final sweep = (items[i].value / total) * pi * 2;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
          rect.deflate(strokeWidth), startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(
      covariant _PremiumAnalyticsCategoryDonutPainter oldDelegate) {
    return oldDelegate.items != items || oldDelegate.total != total;
  }
}

class _PremiumAnalyticsActivityItem {
  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;
  final Color color;
  final IconData icon;
  final bool isPositive;

  const _PremiumAnalyticsActivityItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.color,
    required this.icon,
    required this.isPositive,
  });
}

class _PremiumAnalyticsRecentActivityList extends StatelessWidget {
  final List<_PremiumAnalyticsActivityItem> items;

  const _PremiumAnalyticsRecentActivityList({
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    if (items.isEmpty) {
      return const _PremiumAnalyticsEmptyStateV2(
        icon: Icons.history_rounded,
        title: 'No recent activity yet',
        message:
            'Recent spending, settled bills, and income entries will appear here.',
      );
    }

    return Column(
      children: items
          .map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .02),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: .04)),
              ),
              child: Row(
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(item.icon, color: item.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.subtitle,
                          style: TextStyle(
                            color: ui.textMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item.isPositive ? '+' : '-'} ${formatPhp(item.amount)}',
                        style: TextStyle(
                          color: item.isPositive
                              ? const Color(0xFF00C896)
                              : ui.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formatCalendarDate(item.date),
                        style: TextStyle(
                          color: ui.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PremiumAnalyticsInsightCardV2 extends StatelessWidget {
  final String headline;
  final String message;
  final Color accent;
  final Color secondary;

  const _PremiumAnalyticsInsightCardV2({
    required this.headline,
    required this.message,
    required this.accent,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: .16),
            secondary.withValues(alpha: .16),
            ui.sectionFill,
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: .9),
                  secondary.withValues(alpha: .9)
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    color: ui.textSecondary,
                    fontSize: 12.8,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumAnalyticsEmptyStateV2 extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _PremiumAnalyticsEmptyStateV2({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .02),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .04)),
      ),
      child: Column(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: ui.iconChipBackground(intelliumCyan, radius: 18),
            child: Icon(icon, color: intelliumCyan),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ui.textMuted,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumAnalyticsPreviewCardV2 extends StatelessWidget {
  const _PremiumAnalyticsPreviewCardV2();

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    Widget previewTile(String title, IconData icon, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: ui.iconChipBackground(color, radius: 14),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ui.sectionFill,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: .05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium Dashboard Preview',
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Unlock advanced cash flow, category visuals, and premium activity tracking.',
            style: TextStyle(
              color: ui.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              previewTile('Cash Flow', Icons.bar_chart_rounded, intelliumCyan),
              const SizedBox(width: 12),
              previewTile(
                  'Categories', Icons.pie_chart_rounded, intelliumPurple),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              previewTile('Activity', Icons.history_rounded, intelliumBlue),
              const SizedBox(width: 12),
              previewTile(
                  'Insights', Icons.auto_awesome_rounded, intelliumPink),
            ],
          ),
        ],
      ),
    );
  }
}

List<double> _buildPremiumAnalyticsSevenDayIncomeTrend(
    List<IncomeEntry> items) {
  final now = dateOnly(DateTime.now());
  final totals = List<double>.filled(7, 0);
  for (final item in items) {
    final itemDate = dateOnly(item.receivedAt);
    final diff = now.difference(itemDate).inDays;
    if (diff >= 0 && diff < 7) {
      totals[6 - diff] += item.amount;
    }
  }
  return totals;
}

List<double> _buildPremiumAnalyticsTwelveMonthIncomeTrend(
    List<IncomeEntry> items) {
  final now = DateTime.now();
  final totals = List<double>.filled(12, 0);
  for (final item in items) {
    final monthDiff = (now.year - item.receivedAt.year) * 12 +
        (now.month - item.receivedAt.month);
    if (monthDiff >= 0 && monthDiff < 12) {
      totals[11 - monthDiff] += item.amount;
    }
  }
  return totals;
}

List<String> _buildPremiumAnalyticsRecentDayLabels() {
  const labels = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  final now = DateTime.now();
  return List<String>.generate(7, (index) {
    final date = now.subtract(Duration(days: 6 - index));
    return labels[date.weekday - 1];
  });
}

const List<Color> _premiumAnalyticsCategoryPalette = [
  intelliumCyan,
  intelliumPurple,
  intelliumBlue,
  intelliumPink,
  Color(0xFFFFA62B),
  Color(0xFF00C896),
];

class UnifiedSavingsGoalScreen extends StatefulWidget {
  const UnifiedSavingsGoalScreen({super.key});

  @override
  State<UnifiedSavingsGoalScreen> createState() =>
      _UnifiedSavingsGoalScreenState();
}

class _UnifiedSavingsGoalScreenState extends State<UnifiedSavingsGoalScreen> {
  bool loading = true;
  String goalName = 'Savings Target';
  double targetAmount = 0;
  double savedAmount = 0;
  double currentMoney = 0;
  List<SavingsContributionEntry> history = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final savedGoalName = await FinanceRepository.getSavingsGoalName();
    final savedTarget = await FinanceRepository.getSavingsGoal();
    final savedProgress = await FinanceRepository.getTrackedSavingsAmount();
    final savedHistory = await FinanceRepository.loadSavingsHistory();
    final startingBalance = await FinanceRepository.getStartingBalance();
    final incomeEntries = await FinanceRepository.loadIncomeEntries();
    final bills = await FinanceRepository.loadBills();
    final expenses = await FinanceRepository.loadExpenses();
    final ledger = calculateBalanceLedgerSnapshot(
      startingBalance: startingBalance,
      incomeEntries: incomeEntries,
      bills: bills,
      expenses: expenses,
      savingsBalance: savedProgress,
      savingsHistory: savedHistory,
    );

    if (!mounted) return;
    setState(() {
      goalName = savedGoalName.isEmpty ? 'Savings Target' : savedGoalName;
      targetAmount = savedTarget;
      savedAmount = savedProgress;
      currentMoney = ledger.availableBalance;
      history = savedHistory;
      loading = false;
    });
  }

  Future<void> _showGoalEditor({required bool editing}) async {
    FocusScope.of(context).unfocus();
    final nameController = TextEditingController(
      text: editing ? goalName : (goalName == 'Savings Target' ? '' : goalName),
    );
    final targetController = TextEditingController(
      text: targetAmount > 0 ? targetAmount.toStringAsFixed(2) : '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: intelliumSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        String? validationMessage;
        var saving = false;

        Future<void> saveGoal() async {
          if (saving) return;
          final targetError = validatePesoAmountInput(
            targetController.text,
            fieldLabel: 'savings target amount',
          );
          final trimmedName = nameController.text.trim();
          if (trimmedName.isEmpty) {
            setStateIfMounted(sheetContext, () {
              validationMessage = 'Enter a goal name';
            });
            return;
          }
          if (targetError != null) {
            setStateIfMounted(sheetContext, () {
              validationMessage = targetError;
            });
            return;
          }
          final parsedTarget = parseMoneyInput(targetController.text)!;
          setStateIfMounted(sheetContext, () {
            saving = true;
          });
          FocusScope.of(sheetContext).unfocus();
          await FinanceRepository.setSavingsGoalName(trimmedName);
          await FinanceRepository.setSavingsGoal(parsedTarget);
          await load();
          if (!sheetContext.mounted || !mounted) return;
          Navigator.pop(sheetContext);
        }

        return StatefulBuilder(
          builder: (context, setModalState) => GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SheetHandle(),
                    const SizedBox(height: 20),
                    Text(
                      editing
                          ? 'Edit Savings Target'
                          : 'Set New Savings Target',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (_) {
                        if (validationMessage != null) {
                          setModalState(() => validationMessage = null);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Savings Target Name',
                        hintText: 'Ex. Emergency Fund',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: targetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (_) {
                        if (validationMessage != null) {
                          setModalState(() => validationMessage = null);
                        }
                      },
                      onSubmitted: (_) {
                        unawaited(saveGoal());
                      },
                      decoration: const InputDecoration(
                        labelText: 'Savings Target Amount',
                        hintText: 'Ex. 10000.00',
                      ),
                    ),
                    if (validationMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        validationMessage!,
                        style: const TextStyle(
                          color: Color(0xFFFF8A8A),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Save',
                            onPressed: () {
                              if (saving) return;
                              unawaited(saveGoal());
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    nameController.dispose();
    targetController.dispose();
  }

  Future<void> _showAddToSavingsSheet() async {
    if (targetAmount <= 0) {
      showAppMessage(context, 'Set a savings target first');
      return;
    }

    FocusScope.of(context).unfocus();
    final amountController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: intelliumSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        String? validationMessage;
        var saving = false;

        Future<void> saveContribution() async {
          if (saving) return;
          final amountError = validatePesoAmountInput(
            amountController.text,
            fieldLabel: 'savings amount',
          );
          if (amountError != null) {
            setStateIfMounted(sheetContext, () {
              validationMessage = amountError;
            });
            return;
          }
          final parsedAmount = parseMoneyInput(amountController.text)!;
          if (parsedAmount > currentMoney + 0.001) {
            setStateIfMounted(sheetContext, () {
              validationMessage =
                  'Not enough available balance for this transfer';
            });
            return;
          }
          setStateIfMounted(sheetContext, () {
            saving = true;
          });
          FocusScope.of(sheetContext).unfocus();
          await FinanceRepository.addSavingsTransfer(
            SavingsContributionEntry(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              amount: parsedAmount,
              createdAt: DateTime.now(),
              type: SavingsTransferType.contribution,
            ),
          );
          await load();
          if (!sheetContext.mounted || !mounted) return;
          Navigator.pop(sheetContext);
        }

        return StatefulBuilder(
          builder: (context, setModalState) => GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SheetHandle(),
                    const SizedBox(height: 20),
                    const Text(
                      'How much do you want to transfer to savings?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Available Balance: ${formatPhp(currentMoney)}',
                      style: const TextStyle(
                        color: intelliumTextMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (_) {
                        if (validationMessage != null) {
                          setModalState(() => validationMessage = null);
                        }
                      },
                      onSubmitted: (_) {
                        unawaited(saveContribution());
                      },
                      decoration: const InputDecoration(
                        labelText: 'Add to Savings',
                        hintText: 'Ex. 1000.00',
                      ),
                    ),
                    if (validationMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        validationMessage!,
                        style: const TextStyle(
                          color: Color(0xFFFF8A8A),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Save',
                            onPressed: () {
                              if (saving) return;
                              unawaited(saveContribution());
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    amountController.dispose();
  }

  Future<void> _showWithdrawFromSavingsSheet() async {
    if (savedAmount <= 0) {
      showAppMessage(context, 'No savings balance available to withdraw');
      return;
    }

    FocusScope.of(context).unfocus();
    final amountController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: intelliumSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        String? validationMessage;
        var saving = false;

        Future<void> saveWithdrawal() async {
          if (saving) return;
          final amountError = validatePesoAmountInput(
            amountController.text,
            fieldLabel: 'withdrawal amount',
          );
          if (amountError != null) {
            setStateIfMounted(sheetContext, () {
              validationMessage = amountError;
            });
            return;
          }
          final parsedAmount = parseMoneyInput(amountController.text)!;
          if (parsedAmount > savedAmount + 0.001) {
            setStateIfMounted(sheetContext, () {
              validationMessage =
                  'Not enough savings balance for this transfer';
            });
            return;
          }
          setStateIfMounted(sheetContext, () {
            saving = true;
          });
          FocusScope.of(sheetContext).unfocus();
          await FinanceRepository.addSavingsTransfer(
            SavingsContributionEntry(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              amount: parsedAmount,
              createdAt: DateTime.now(),
              type: SavingsTransferType.withdrawal,
            ),
          );
          await load();
          if (!sheetContext.mounted || !mounted) return;
          Navigator.pop(sheetContext);
        }

        return StatefulBuilder(
          builder: (context, setModalState) => GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SheetHandle(),
                    const SizedBox(height: 20),
                    const Text(
                      'How much do you want to move back to available balance?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Savings Balance: ${formatPhp(savedAmount)}',
                      style: const TextStyle(
                        color: intelliumTextMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (_) {
                        if (validationMessage != null) {
                          setModalState(() => validationMessage = null);
                        }
                      },
                      onSubmitted: (_) {
                        unawaited(saveWithdrawal());
                      },
                      decoration: const InputDecoration(
                        labelText: 'Withdraw from Savings',
                        hintText: 'Ex. 500.00',
                      ),
                    ),
                    if (validationMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        validationMessage!,
                        style: const TextStyle(
                          color: Color(0xFFFF8A8A),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Save',
                            onPressed: () {
                              if (saving) return;
                              unawaited(saveWithdrawal());
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    amountController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final remainingAmount = max(0.0, targetAmount - savedAmount);
    final progress = targetAmount <= 0
        ? 0.0
        : (savedAmount / targetAmount).clamp(0.0, 1.0).toDouble();

    Widget actionButton({
      required String label,
      required IconData icon,
      required Color color,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ui.sectionFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: .05)),
            ),
            child: Column(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: ui.iconChipBackground(color, radius: 14),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Savings Balance',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: loading
          ? buildPageLoadingState('Loading your savings overview...')
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeroCard(
                    colors: const [
                      Color(0xFF17345F),
                      intelliumBlue,
                      intelliumPurple,
                    ],
                    title: goalName,
                    value: formatPhp(savedAmount),
                    badge: targetAmount > 0
                        ? '${formatPhp(targetAmount)} target | ${formatPhp(remainingAmount)} remaining'
                        : 'Set a savings target to start tracking savings transfers',
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      actionButton(
                        label: 'Set New Savings Target',
                        icon: Icons.flag_rounded,
                        color: intelliumCyan,
                        onTap: () => _showGoalEditor(editing: false),
                      ),
                      const SizedBox(width: 12),
                      actionButton(
                        label: 'Edit Savings Target',
                        icon: Icons.edit_rounded,
                        color: intelliumBlue,
                        onTap: targetAmount > 0
                            ? () => _showGoalEditor(editing: true)
                            : () => showAppMessage(
                                  context,
                                  'Set a savings target first',
                                ),
                      ),
                      const SizedBox(width: 12),
                      actionButton(
                        label: 'Add to Savings',
                        icon: Icons.savings_rounded,
                        color: const Color(0xFF00C896),
                        onTap: () {
                          unawaited(_showAddToSavingsSheet());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      actionButton(
                        label: 'Withdraw from Savings',
                        icon: Icons.swap_horiz_rounded,
                        color: const Color(0xFFFFC857),
                        onTap: () {
                          unawaited(_showWithdrawFromSavingsSheet());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: ui.sectionFill,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: .05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goalName,
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: HomeOverviewCard(
                                title: 'Target',
                                value: formatPhp(targetAmount),
                                subtitle: 'Target amount',
                                color: intelliumBlue,
                                icon: Icons.flag_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: HomeOverviewCard(
                                title: 'Total Saved',
                                value: formatPhp(savedAmount),
                                subtitle: 'Transferred to this target',
                                color: const Color(0xFF00C896),
                                icon: Icons.savings_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: HomeOverviewCard(
                                title: 'Remaining',
                                value: formatPhp(remainingAmount),
                                subtitle: 'Left to reach this target',
                                color: intelliumPurple,
                                icon: Icons.track_changes_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: HomeOverviewCard(
                                title: 'Available Balance',
                                value: formatPhp(currentMoney),
                                subtitle: 'Ready for spending or transfers',
                                color: intelliumPink,
                                icon: Icons.account_balance_wallet_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 12,
                            backgroundColor:
                                Colors.white.withValues(alpha: .08),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              intelliumCyan,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}% of target reached',
                          style: TextStyle(
                            color: ui.textMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const HomeSectionHeader(
                    title: 'Savings Transfers',
                    subtitle: 'Every savings transfer is recorded here',
                  ),
                  const SizedBox(height: 14),
                  if (history.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: ui.sectionFill,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .05)),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _HomeEmptyIcon(
                            icon: Icons.savings_rounded,
                            color: intelliumPurple,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No savings activity yet',
                            style: TextStyle(
                              color: intelliumTextPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Use Add to Savings or Withdraw from Savings to move money between your balances.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: intelliumTextSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: ui.sectionFill,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .05)),
                      ),
                      child: Column(
                        children: history
                            .map(
                              (entry) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .02),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      height: 42,
                                      width: 42,
                                      decoration: ui.iconChipBackground(
                                        entry.isContribution
                                            ? const Color(0xFF00C896)
                                            : const Color(0xFFFFC857),
                                        radius: 14,
                                      ),
                                      child: Icon(
                                        entry.isContribution
                                            ? Icons.south_west_rounded
                                            : Icons.north_east_rounded,
                                        color: entry.isContribution
                                            ? const Color(0xFF00C896)
                                            : const Color(0xFFFFC857),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.label,
                                            style: TextStyle(
                                              color: ui.textPrimary,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            formatCalendarDate(entry.createdAt),
                                            style: TextStyle(
                                              color: ui.textMuted,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      formatPhp(entry.amount),
                                      style: TextStyle(
                                        color: entry.isContribution
                                            ? const Color(0xFF00C896)
                                            : const Color(0xFFFFC857),
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  void setStateIfMounted(BuildContext modalContext, VoidCallback fn) {
    if (!modalContext.mounted) return;
    fn();
    if (modalContext is Element) {
      modalContext.markNeedsBuild();
    }
  }
}

class InviteEarnScreen extends StatefulWidget {
  final int refreshKey;

  const InviteEarnScreen({super.key, required this.refreshKey});

  @override
  State<InviteEarnScreen> createState() => _InviteEarnScreenState();
}

class _InviteEarnScreenState extends State<InviteEarnScreen> {
  bool loading = true;
  String code = '------';
  int invites = 0;
  int active = 0;
  int paid = 0;
  double earnings = 0;
  List<String> history = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant InviteEarnScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      load();
    }
  }

  Future<void> load() async {
    code = await FinanceRepository.getReferralCode();
    invites = await FinanceRepository.getReferralInvites();
    active = await FinanceRepository.getReferralActive();
    paid = await FinanceRepository.getReferralPaid();
    earnings = await FinanceRepository.getReferralEarnings();
    history = await FinanceRepository.getReferralHistory();
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> addTestReferral() async {
    if (mounted) {
      setState(() => loading = true);
    }
    await FinanceRepository.recordSuccessfulPaidReferral(referralCode: code);
    await load();
  }

  Future<void> copyCode() async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Referral code copied: $code')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canWithdraw = earnings >= 100;
    final ui = SweldoVisualStyle.fromContext(context);
    const referralBlue = Color(0xFF7A9BFF);
    const referralViolet = Color(0xFF8E78FF);
    const referralMint = Color(0xFF57E9C3);

    return SafeArea(
      child: loading
          ? buildPageLoadingState('Loading your referral dashboard...')
          : RefreshIndicator(
              onRefresh: load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(decoration: TextDecoration.none),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite & Earn',
                        style: TextStyle(
                          color: ui.textPrimary,
                          decoration: TextDecoration.none,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Text(
                          'Share your referral code, track paid conversions, and monitor your referral rewards in one polished premium view.',
                          style: TextStyle(
                            color: ui.textSecondary,
                            decoration: TextDecoration.none,
                            fontSize: 13.5,
                            height: 1.55,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _InviteHeroCard(
                        title: 'Total Earnings',
                        value: formatPhp(earnings, decimals: 2),
                        badge:
                            'Earn \u20B120 for every successful paid referral',
                        primary: referralBlue,
                        secondary: referralViolet,
                        accent: referralMint,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _InviteStatCard(
                              title: 'Invites',
                              value: '$invites',
                              subtitle: 'People referred',
                              color: referralBlue,
                              icon: Icons.person_add_alt_1_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InviteStatCard(
                              title: 'Paid',
                              value: '$paid',
                              subtitle: 'Subscribers converted',
                              color: referralMint,
                              icon: Icons.verified_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _InviteCodeCard(
                        code: code,
                        infoCard: _InviteInfoCard(
                          title: 'Withdrawal',
                          subtitle: canWithdraw
                              ? 'Minimum withdrawal: \u20B1100. Your current referral balance is ready for payout.'
                              : 'Minimum withdrawal: \u20B1100. Keep sharing your code to reach the payout threshold.',
                          accent: canWithdraw ? referralMint : referralViolet,
                          icon: canWithdraw
                              ? Icons.account_balance_wallet_rounded
                              : Icons.info_outline_rounded,
                        ),
                        onCopy: copyCode,
                        onAddTestReferral: kDebugMode ? addTestReferral : null,
                        accent: referralBlue,
                      ),
                      const SizedBox(height: 28),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Referral History',
                                  style: TextStyle(
                                    color: ui.textPrimary,
                                    decoration: TextDecoration.none,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  history.isEmpty
                                      ? 'Your paid referral activity will appear here.'
                                      : '${history.length} recent referral update${history.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    color: ui.textSecondary,
                                    decoration: TextDecoration.none,
                                    fontSize: 12.5,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (history.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: referralBlue.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: referralBlue.withValues(alpha: .16),
                                ),
                              ),
                              child: Text(
                                '${history.length}',
                                style: TextStyle(
                                  color: ui.textPrimary,
                                  decoration: TextDecoration.none,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (history.isEmpty)
                        const EmptyStateCard(
                          icon: Icons.card_giftcard_rounded,
                          title: 'No referrals yet',
                          subtitle:
                              'Your future \u20B120 paid referral history will appear here.',
                        )
                      else
                        ...history.map(
                          (item) => _InviteHistoryCard(item: item),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _InviteHeroCard extends StatelessWidget {
  final String title;
  final String value;
  final String badge;
  final Color primary;
  final Color secondary;
  final Color accent;

  const _InviteHeroCard({
    required this.title,
    required this.value,
    required this.badge,
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0C1427),
            primary.withValues(alpha: .18),
            secondary.withValues(alpha: .14),
            const Color(0xFF0B1020),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: .08),
            blurRadius: 26,
            spreadRadius: -12,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .08)),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.none,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .18,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: .18)),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: accent,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                decoration: TextDecoration.none,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                height: 1.04,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: .06)),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: ui.textSecondary,
                decoration: TextDecoration.none,
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _InviteStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 156),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: .08),
            ui.cardFill.withValues(alpha: .97),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: .10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: ui.iconChipBackground(color, radius: 16),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    color: ui.textMuted,
                    decoration: TextDecoration.none,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            value,
            style: TextStyle(
              color: ui.textPrimary,
              decoration: TextDecoration.none,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: ui.textSecondary,
              decoration: TextDecoration.none,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  final String code;
  final Widget infoCard;
  final VoidCallback onCopy;
  final VoidCallback? onAddTestReferral;
  final Color accent;

  const _InviteCodeCard({
    required this.code,
    required this.infoCard,
    required this.onCopy,
    required this.onAddTestReferral,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ui.cardFill.withValues(alpha: .98),
            const Color(0xFF101726),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .05)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .05),
            blurRadius: 22,
            spreadRadius: -14,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Referral Code',
            style: TextStyle(
              color: ui.textMuted,
              decoration: TextDecoration.none,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: .25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Share this code with new premium users to track paid referral rewards.',
            style: TextStyle(
              color: ui.textSecondary,
              decoration: TextDecoration.none,
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: .09),
                  const Color(0xFF0F1727),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: .14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share Code',
                  style: TextStyle(
                    color: ui.textMuted,
                    decoration: TextDecoration.none,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          code,
                          style: TextStyle(
                            color: ui.textPrimary,
                            decoration: TextDecoration.none,
                            fontSize: 29,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .06),
                        ),
                      ),
                      child: Icon(
                        Icons.qr_code_2_rounded,
                        color: accent.withValues(alpha: .92),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _InviteActionButton(
                  label: 'Copy Code',
                  icon: Icons.copy_rounded,
                  onPressed: onCopy,
                  backgroundColor: accent,
                  foregroundColor: intelliumBackground,
                ),
              ),
              if (onAddTestReferral != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _InviteActionButton(
                    label: 'Add Test Referral',
                    icon: Icons.science_outlined,
                    onPressed: onAddTestReferral!,
                    backgroundColor: ui.cardFill,
                    foregroundColor: ui.textPrimary,
                    borderColor: Colors.white.withValues(alpha: .08),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          infoCard,
        ],
      ),
    );
  }
}

class _InviteInfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;

  const _InviteInfoCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: .07),
            ui.cardFill.withValues(alpha: .98),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: .11)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: ui.iconChipBackground(accent, radius: 16),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ui.textPrimary,
                    decoration: TextDecoration.none,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: ui.textSecondary,
                    decoration: TextDecoration.none,
                    fontSize: 12.5,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteHistoryCard extends StatelessWidget {
  final String item;

  const _InviteHistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    const accent = Color(0xFF7A9BFF);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ui.cardFill.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: .10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(8),
            decoration: ui.iconChipBackground(accent, radius: 14),
            child: const Icon(
              Icons.north_east_rounded,
              color: accent,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item,
              style: TextStyle(
                color: ui.textPrimary,
                decoration: TextDecoration.none,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;

  const _InviteActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: borderColor == null
                ? BorderSide.none
                : BorderSide(color: borderColor!),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            decoration: TextDecoration.none,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Settings
// -----------------------------------------------------------------------------

class SettingsScreen extends StatelessWidget {
  final VoidCallback onChanged;
  final PremiumService premiumService;
  final AppThemeController themeController;

  const SettingsScreen({
    super.key,
    required this.onChanged,
    required this.premiumService,
    required this.themeController,
  });

  Future<void> _openHelpTutorialScreen(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const HelpTutorialScreen(),
      ),
    );
  }

  Future<void> _showInfoDialog(
    BuildContext context, {
    required String title,
    required String body,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: intelliumSurface,
        title: Text(
          title,
          style: const TextStyle(color: intelliumTextPrimary),
        ),
        content: SelectableText(
          body,
          style: const TextStyle(color: intelliumTextSecondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSupportDialog(BuildContext context) async {
    await _showInfoDialog(
      context,
      title: 'Contact Support',
      body: 'For help or bug reports, contact:\n\nintelliumdigitalph@gmail.com',
    );
  }

  Future<void> _showFeedbackDialog(BuildContext context) async {
    await _showInfoDialog(
      context,
      title: 'Report a Bug / Request Feature',
      body:
          'Share bugs, ideas, or feature requests at:\n\nintelliumdigitalph@gmail.com',
    );
  }

  Future<void> _showBackupReadyDialog(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String jsonPayload,
  }) async {
    final controller = TextEditingController(text: jsonPayload);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var copying = false;
        return StatefulBuilder(
          builder: (dialogStateContext, setDialogState) => AlertDialog(
            backgroundColor: intelliumSurface,
            title: Text(
              title,
              style: const TextStyle(color: intelliumTextPrimary),
            ),
            content: SizedBox(
              width: min(MediaQuery.of(dialogContext).size.width * 0.88, 560.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: intelliumTextSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    readOnly: true,
                    maxLines: 12,
                    minLines: 8,
                    style: const TextStyle(
                      color: intelliumTextPrimary,
                      fontFamily: 'Courier',
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Backup JSON',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: copying
                    ? null
                    : () async {
                        setDialogState(() => copying = true);
                        await Clipboard.setData(ClipboardData(text: jsonPayload));
                        if (!dialogContext.mounted || !context.mounted) return;
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Backup ready to copy.')),
                        );
                      },
                child: Text(copying ? 'Copying...' : 'Copy'),
              ),
              TextButton(
                onPressed: copying ? null : () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
  }

  Future<void> _showImportBackupDialog(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var importing = false;
        return StatefulBuilder(
          builder: (dialogStateContext, setDialogState) => AlertDialog(
            backgroundColor: intelliumSurface,
            title: const Text(
              'Import Backup',
              style: TextStyle(color: intelliumTextPrimary),
            ),
            content: SizedBox(
              width: min(MediaQuery.of(dialogContext).size.width * 0.88, 560.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Paste a SweldoTrack backup JSON file below. Import replaces only the supported local data included in that backup.',
                    style: TextStyle(
                      color: intelliumTextSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    maxLines: 12,
                    minLines: 8,
                    style: const TextStyle(
                      color: intelliumTextPrimary,
                      fontFamily: 'Courier',
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Backup JSON',
                      hintText: '{ ... }',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: importing ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: importing
                    ? null
                    : () async {
                        setDialogState(() => importing = true);
                        final raw = controller.text.trim();
                        late final ({
                          Map<String, dynamic> data,
                          List<String> keys,
                          String scope
                        }) parsed;
                        try {
                          parsed = FinanceRepository.parseLocalBackupJson(raw);
                        } catch (_) {
                          if (!dialogContext.mounted || !context.mounted) return;
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Invalid backup file. Please check the format and try again.',
                              ),
                            ),
                          );
                          return;
                        }

                        final confirmed = await showDialog<bool>(
                              context: dialogContext,
                              builder: (confirmContext) => AlertDialog(
                                backgroundColor: intelliumSurface,
                                title: const Text(
                                  'Replace local data with this backup?',
                                  style: TextStyle(color: intelliumTextPrimary),
                                ),
                                content: Text(
                                  'This backup includes ${parsed.keys.length} supported data key${parsed.keys.length == 1 ? '' : 's'} from ${parsed.scope.replaceAll('_', ' ')}. Existing values for those items on this device will be replaced.',
                                  style: const TextStyle(
                                    color: intelliumTextSecondary,
                                    height: 1.45,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(confirmContext, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(confirmContext, true),
                                    child: const Text('Import'),
                                  ),
                                ],
                              ),
                            ) ??
                            false;

                        if (!dialogContext.mounted) return;
                        if (!confirmed) {
                          setDialogState(() => importing = false);
                          return;
                        }

                        try {
                          await FinanceRepository.importLocalBackupJson(raw);
                          await themeController.load();
                          if (!context.mounted) return;
                          onChanged();
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Backup imported successfully.'),
                            ),
                          );
                        } catch (_) {
                          if (!dialogContext.mounted || !context.mounted) return;
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Invalid backup file. Please check the format and try again.',
                              ),
                            ),
                          );
                        }
                      },
                child: Text(importing ? 'Importing...' : 'Import Backup'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
  }

  Future<void> _showResetAllDataDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: intelliumSurface,
            title: const Text(
              'Reset all local data?',
              style: TextStyle(color: intelliumTextPrimary),
            ),
            content: const Text(
              'This will clear your profile, onboarding progress, finance records, bills, savings, smart detection settings, and app preferences on this device. This cannot be undone.',
              style: TextStyle(color: intelliumTextSecondary, height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;

    final confirmationController = TextEditingController();
    var confirmationValue = '';
    final finalConfirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              backgroundColor: intelliumSurface,
              title: const Text(
                'Final confirmation',
                style: TextStyle(color: intelliumTextPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'To confirm, type RESET below. Your Google Play subscription is not cancelled. You can restore purchases after reset if needed.',
                    style: TextStyle(
                      color: intelliumTextSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmationController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: intelliumTextPrimary),
                    onChanged: (value) {
                      setDialogState(() => confirmationValue = value.trim());
                    },
                    decoration: const InputDecoration(
                      labelText: 'Type RESET',
                      hintText: 'RESET',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: confirmationValue == 'RESET'
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  child: const Text('Reset All Data'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    confirmationController.dispose();
    if (!finalConfirmed) return;

    try {
      await FinanceRepository.resetAllLocalUserData();
      await premiumService.reloadLocalStatus();
      await themeController.load();
      if (!context.mounted) return;
      onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All local app data has been reset.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final lastVerifiedLabel = premiumService.lastVerifiedAt == null
        ? 'Not yet checked'
        : DateFormat('MMM d, yyyy h:mm a').format(
            premiumService.lastVerifiedAt!.toLocal(),
          );
    final premiumStatusValue = !premiumLaunchEnabled
        ? premiumTemporarilyUnavailableLabel
        : premiumService.premiumStatusLabel;
    final premiumStatusSubtitle = !premiumLaunchEnabled
        ? premiumPurchasesUnavailableMessage
        : premiumService.premiumStatusDetail;
    final premiumVerificationValue = !premiumLaunchEnabled
        ? 'Unavailable'
        : premiumService.requiresBackendVerificationSetup
            ? premiumTemporarilyUnavailableLabel
            : premiumService.isPremium
                ? 'Verified'
                : premiumService.isRestorePending
                    ? 'Checking'
                    : premiumService.isPurchasePending
                        ? 'Pending'
                        : 'Not verified yet';
    final premiumVerificationSubtitle = !premiumLaunchEnabled
        ? premiumPurchasesUnavailableMessage
        : premiumService.requiresBackendVerificationSetup
            ? premiumPurchasesUnavailableMessage
            : premiumService.isPremium
                ? 'Your Google Play purchase was verified before premium access was enabled here.'
                : premiumService.isRestorePending
                    ? 'Google Play is checking this account for a previous premium purchase.'
                    : premiumService.isPurchasePending
                        ? 'Google Play is still finishing your purchase confirmation.'
                        : 'Premium activates only after a verified Google Play purchase.';

    Widget buildSectionHeader(String title, String subtitle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: ui.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              'Manage your profile, storage, privacy, and app preferences.',
              style: TextStyle(
                  color: ui.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([premiumService, themeController]),
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildSectionHeader(
                  'App / Profile',
                  'SweldoTrack helps you track spending, bills, savings, and budget habits with a private device-first setup.',
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: ui.sectionContainerDecoration(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 48,
                        width: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [intelliumCyan, intelliumBlue],
                          ),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SweldoTrack',
                              style: TextStyle(
                                color: ui.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your personal salary, budget, and spending tracker.',
                              style: TextStyle(
                                color: ui.textSecondary,
                                fontSize: 12.8,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                buildSectionHeader(
                  'App Information',
                  'Current installed version information for this app.',
                ),
                const SizedBox(height: 16),
                const InstalledAppVersionCard(),
                const SizedBox(height: 24),
                buildSectionHeader(
                  'Preferences',
                  'Customize how SweldoTrack looks and behaves on this device.',
                ),
                const SizedBox(height: 16),
                const SummaryCard(
                  title: 'Currency',
                  value: '\u20B1',
                  subtitle: 'Philippine Peso format',
                  color: Color(0xFF00C896),
                  icon: Icons.currency_exchange_rounded,
                ),
                const SizedBox(height: 12),
                ThemeSelectionCard(
                  themeController: themeController,
                  hasPremium: premiumService.isPremium,
                ),
                if (!premiumService.isPremium) ...[
                  const SizedBox(height: 12),
                  PremiumFeatureLockCard(
                    title: 'Premium Theme Pack',
                    subtitle:
                        'Jade Green stays free. Unlock additional premium themes with SweldoTrack Premium.',
                    premiumService: premiumService,
                  ),
                ],
                if (!kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.android) ...[
                  const SizedBox(height: 12),
                  SmartExpenseDetectionSettingsCard(
                    premiumService: premiumService,
                  ),
                ],
                const SizedBox(height: 12),
                const _SettingsPlaceholderCard(
                  icon: Icons.lock_outline_rounded,
                  accent: Color(0xFF6C8CFF),
                  title: 'App Lock',
                  subtitle: 'Protect SweldoTrack with PIN or biometrics.',
                  pillLabel: 'Coming soon',
                ),
                const SizedBox(height: 24),
                buildSectionHeader(
                  'Premium',
                  'Review your subscription, restore purchases, and manage premium status.',
                ),
                const SizedBox(height: 16),
                PremiumPlanCard(premiumService: premiumService),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: ui.sectionContainerDecoration(),
                  child: LayoutBuilder(
                    builder: (context, sectionConstraints) {
                      final stackCards = sectionConstraints.maxWidth < 720;
                      final stackButtons = sectionConstraints.maxWidth < 520;

                      final statusCard = SummaryCard(
                        title: 'Premium Status',
                        value: premiumStatusValue,
                        subtitle: premiumStatusSubtitle,
                        color: premiumService.isPremium
                            ? intelliumCyan
                            : intelliumTextMuted,
                        icon: premiumService.isPremium
                            ? Icons.verified_rounded
                            : Icons.shield_outlined,
                      );
                      final verificationCard = SummaryCard(
                        title: 'Verification',
                        value: premiumVerificationValue,
                        subtitle: premiumVerificationSubtitle,
                        color: const Color(0xFF6C8CFF),
                        icon: Icons.security_rounded,
                      );
                      final lastCheckCard = SummaryCard(
                        title: 'Last Premium Check',
                        value: lastVerifiedLabel,
                        subtitle: premiumService.lastVerifiedAt == null
                            ? 'No premium verification has been saved on this device yet.'
                            : 'Most recent premium verification saved on this device.',
                        color: const Color(0xFFFFC857),
                        icon: Icons.schedule_rounded,
                      );

                      final restoreButton = ElevatedButton(
                        onPressed: !premiumService.canRestorePremium
                            ? null
                            : () async {
                                await premiumService.restorePurchases();
                                if (!context.mounted) return;
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: intelliumCyan,
                          foregroundColor: intelliumBackground,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Restore Purchase',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      );
                      final refreshButton = ElevatedButton(
                        onPressed: premiumService.isAnyPremiumActionPending
                            ? null
                            : () async {
                                await premiumService.refreshStoreState();
                                if (!context.mounted) return;
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: intelliumCard,
                          foregroundColor: intelliumTextPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Refresh Premium Status',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Premium Status',
                            style: TextStyle(
                              color: ui.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Review your subscription, verification, and purchase recovery options.',
                            style: TextStyle(
                              color: ui.textSecondary,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (stackCards) ...[
                            statusCard,
                            const SizedBox(height: 12),
                            verificationCard,
                          ] else
                            Row(
                              children: [
                                Expanded(child: statusCard),
                                const SizedBox(width: 12),
                                Expanded(child: verificationCard),
                              ],
                            ),
                          const SizedBox(height: 12),
                          lastCheckCard,
                          if (!premiumService.isPremium &&
                              (premiumService
                                      .requiresBackendVerificationSetup ||
                                  !premiumService.isAvailable ||
                                  !premiumService.isProductLoaded ||
                                  premiumService.lastVerificationMessage !=
                                      null)) ...[
                            const SizedBox(height: 12),
                            Text(
                              premiumService.premiumStatusDetail,
                              style: TextStyle(
                                color: ui.textSecondary,
                                fontSize: 12.5,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (premiumService.errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              premiumService.errorMessage!,
                              style: TextStyle(
                                color: ui.isJade
                                    ? const Color(0xFFFFB6C8)
                                    : const Color(0xFFFF8A8A),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: ui.cardDecoration(radius: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Restore Purchase',
                                  style: TextStyle(
                                    color: ui.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  premiumService
                                      .premiumRestoreAvailabilityMessage,
                                  style: TextStyle(
                                    color: ui.textSecondary,
                                    fontSize: 12.5,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (stackButtons) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: restoreButton,
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: refreshButton,
                                  ),
                                ] else
                                  Row(
                                    children: [
                                      Expanded(child: restoreButton),
                                      const SizedBox(width: 12),
                                      Expanded(child: refreshButton),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                buildSectionHeader(
                  'Privacy & Data',
                  'Review local storage, backups, privacy details, and finance-only recovery tools.',
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: ui.sectionContainerDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingsActionCard(
                        icon: Icons.privacy_tip_outlined,
                        accent: intelliumPurple,
                        title: 'Privacy & Data',
                        subtitle: 'How SweldoTrack stores and uses your data',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PrivacyDataScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      const SummaryCard(
                        title: 'Storage',
                        value: 'Local only',
                        subtitle:
                            'Your finance data stays on this device unless you export a backup.',
                        color: Color(0xFF6C8CFF),
                        icon: Icons.sd_storage_rounded,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: ui.cardDecoration(radius: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  height: 42,
                                  width: 42,
                                  decoration: ui.iconChipBackground(
                                    intelliumCyan,
                                    radius: 14,
                                  ),
                                  child: const Icon(
                                    Icons.backup_rounded,
                                    color: intelliumCyan,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Backup & Restore',
                                        style: TextStyle(
                                          color: ui.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Create copyable local backups or import a previous SweldoTrack backup safely.',
                                        style: TextStyle(
                                          color: ui.textSecondary,
                                          fontSize: 12.5,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _SettingsActionCard(
                              icon: Icons.ios_share_rounded,
                              accent: intelliumCyan,
                              title: 'Export All Data',
                              subtitle:
                                  'Create a full local JSON backup for profile, finance, preferences, and supported settings.',
                              onTap: () async {
                                final payload = await FinanceRepository
                                    .exportAllLocalDataJson();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Backup ready to copy.'),
                                  ),
                                );
                                await _showBackupReadyDialog(
                                  context,
                                  title: 'Export All Data',
                                  subtitle:
                                      'Copy this JSON backup and store it somewhere safe.',
                                  jsonPayload: payload,
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _SettingsActionCard(
                              icon: Icons.upload_file_rounded,
                              accent: const Color(0xFFFFC857),
                              title: 'Import Backup',
                              subtitle:
                                  'Paste a supported SweldoTrack JSON backup and replace the included local data.',
                              onTap: () {
                                unawaited(_showImportBackupDialog(context));
                              },
                            ),
                            const SizedBox(height: 12),
                            _SettingsActionCard(
                              icon: Icons.receipt_long_outlined,
                              accent: const Color(0xFF57E9C3),
                              title: 'Export Expenses Only',
                              subtitle:
                                  'Copy a JSON backup containing saved spending entries only.',
                              onTap: () async {
                                final payload = await FinanceRepository
                                    .exportExpensesOnlyJson();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Backup ready to copy.'),
                                  ),
                                );
                                await _showBackupReadyDialog(
                                  context,
                                  title: 'Export Expenses Only',
                                  subtitle:
                                      'Copy this JSON if you only want a spending-only backup.',
                                  jsonPayload: payload,
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _SettingsActionCard(
                              icon: Icons.calendar_month_rounded,
                              accent: const Color(0xFF6C8CFF),
                              title: 'Export Bills Only',
                              subtitle:
                                  'Copy a JSON backup containing saved bills only.',
                              onTap: () async {
                                final payload = await FinanceRepository
                                    .exportBillsOnlyJson();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Backup ready to copy.'),
                                  ),
                                );
                                await _showBackupReadyDialog(
                                  context,
                                  title: 'Export Bills Only',
                                  subtitle:
                                      'Copy this JSON if you only want a bills-only backup.',
                                  jsonPayload: payload,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: ui.cardDecoration(radius: 24).copyWith(
                              border: Border.all(
                                color: intelliumPurple.withValues(alpha: .18),
                              ),
                            ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 42,
                                  width: 42,
                                  decoration: ui.iconChipBackground(
                                    intelliumPurple,
                                    radius: 14,
                                  ),
                                  child: const Icon(
                                    Icons.restart_alt_rounded,
                                    color: intelliumPurple,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Reset Finance Data',
                                        style: TextStyle(
                                          color: ui.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Clear saved spending, bills, savings, referrals, and balance setup while keeping themes and premium state intact.',
                                        style: TextStyle(
                                          color: ui.textSecondary,
                                          fontSize: 12.5,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      backgroundColor: intelliumSurface,
                                      title: const Text('Reset finance data?',
                                          style: TextStyle(
                                              color: intelliumTextPrimary)),
                                      content: const Text(
                                        'This clears saved spending, bills, income setup, savings targets, and referral history on this device. Premium cache, app theme, and onboarding stay untouched.',
                                        style: TextStyle(
                                            color: intelliumTextSecondary),
                                      ),
                                      actions: [
                                        TextButton(
                                            onPressed: () => Navigator.pop(
                                                dialogContext, false),
                                            child: const Text('Cancel')),
                                        TextButton(
                                            onPressed: () => Navigator.pop(
                                                dialogContext, true),
                                            child: const Text('Reset')),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true) {
                                    await FinanceRepository.resetFinanceData();
                                    if (!context.mounted) return;
                                    onChanged();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Finance data has been reset'),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C8CFF),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text(
                                  'Reset Finance Data',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            if (kDebugMode) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        backgroundColor: intelliumSurface,
                                        title: const Text(
                                            'Run full testing reset?',
                                            style: TextStyle(
                                                color: intelliumTextPrimary)),
                                        content: const Text(
                                          'Debug-only reset. This fully clears local app state, including premium cache, theme selection, and onboarding markers.',
                                          style: TextStyle(
                                              color: intelliumTextSecondary),
                                        ),
                                        actions: [
                                          TextButton(
                                              onPressed: () => Navigator.pop(
                                                  dialogContext, false),
                                              child: const Text('Cancel')),
                                          TextButton(
                                              onPressed: () => Navigator.pop(
                                                  dialogContext, true),
                                              child: const Text('Reset')),
                                        ],
                                      ),
                                    );

                                    if (confirmed == true) {
                                      await FinanceRepository
                                          .resetLocalTestingState();
                                      await premiumService.reloadLocalStatus();
                                      await themeController.load();
                                      if (!context.mounted) return;
                                      onChanged();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Full local testing reset completed',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: intelliumCard,
                                    foregroundColor: intelliumTextPrimary,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(18)),
                                  ),
                                  child: const Text('Full Testing Reset',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                buildSectionHeader(
                  'Help & Support',
                  'Open guidance, support options, and feedback channels when you need them.',
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: ui.sectionContainerDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingsActionCard(
                        icon: Icons.school_outlined,
                        accent: intelliumCyan,
                        title: 'Help & Tutorial',
                        subtitle: 'Learn how to use SweldoTrack',
                        onTap: () {
                          unawaited(_openHelpTutorialScreen(context));
                        },
                      ),
                      const SizedBox(height: 12),
                      _SettingsActionCard(
                        icon: Icons.support_agent_rounded,
                        accent: const Color(0xFFFFC857),
                        title: 'Contact Support',
                        subtitle: 'Report a bug or request help',
                        onTap: () {
                          unawaited(_showSupportDialog(context));
                        },
                      ),
                      const SizedBox(height: 12),
                      _SettingsActionCard(
                        icon: Icons.bug_report_outlined,
                        accent: intelliumPurple,
                        title: 'Report a Bug / Request Feature',
                        subtitle:
                            'Share product issues or ideas for future updates',
                        onTap: () {
                          unawaited(_showFeedbackDialog(context));
                        },
                      ),
                    ],
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: ui.sectionContainerDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Debug-Only Premium Override',
                          style: TextStyle(
                              color: ui.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Debug-only local UI override. Store purchases still require receipt verification.',
                          style: TextStyle(
                              color: ui.textSecondary,
                              fontSize: 12.5,
                              height: 1.35),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SummaryCard(
                                title: 'Override',
                                value:
                                    premiumService.isTestPremiumOverrideEnabled
                                        ? 'Enabled'
                                        : 'Disabled',
                                subtitle: 'Debug-only local premium toggle',
                                color:
                                    premiumService.isTestPremiumOverrideEnabled
                                        ? intelliumCyan
                                        : intelliumTextMuted,
                                icon:
                                    premiumService.isTestPremiumOverrideEnabled
                                        ? Icons.toggle_on_rounded
                                        : Icons.toggle_off_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SummaryCard(
                                title: 'Cache',
                                value: premiumService.hasCachedPremiumState
                                    ? 'Present'
                                    : 'Empty',
                                subtitle: 'Local premium metadata state',
                                color: premiumService.hasCachedPremiumState
                                    ? const Color(0xFFFFC857)
                                    : intelliumTextMuted,
                                icon: premiumService.hasCachedPremiumState
                                    ? Icons.sd_storage_rounded
                                    : Icons.storage_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: ui.cardDecoration(radius: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Developer Diagnostics',
                                style: TextStyle(
                                  color: ui.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...premiumService.developerDiagnostics.map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '${entry.$1}: ${entry.$2}',
                                    style: TextStyle(
                                      color: ui.textSecondary,
                                      fontSize: 12.5,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  await premiumService
                                      .setTestPremiumEnabled(true);
                                  if (!context.mounted) return;
                                  onChanged();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: intelliumCyan,
                                  foregroundColor: intelliumBackground,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18)),
                                ),
                                child: const Text('Enable Override',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  await premiumService
                                      .setTestPremiumEnabled(false);
                                  if (!context.mounted) return;
                                  onChanged();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: intelliumCard,
                                  foregroundColor: intelliumTextPrimary,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18)),
                                ),
                                child: const Text('Disable Override',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  await premiumService.reloadLocalStatus();
                                  if (!context.mounted) return;
                                  onChanged();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Local premium state refreshed'),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: intelliumCard,
                                  foregroundColor: intelliumTextPrimary,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18)),
                                ),
                                child: const Text('Refresh Local State',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  await premiumService
                                      .clearLocalPremiumTestingCache();
                                  if (!context.mounted) return;
                                  onChanged();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Local premium cache cleared'),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: intelliumPink,
                                  foregroundColor: intelliumBackground,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18)),
                                ),
                                child: const Text('Clear Local Cache',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: ui.sectionContainerDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Danger Zone',
                        style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'These actions are permanent and should only be used when you want to start over.',
                        style: TextStyle(
                          color: ui.textSecondary,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A1028).withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color:
                                const Color(0xFFFF6B9A).withValues(alpha: .28),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 42,
                                  width: 42,
                                  decoration: ui.iconChipBackground(
                                    const Color(0xFFFF6B9A),
                                    radius: 14,
                                  ),
                                  child: const Icon(
                                    Icons.delete_forever_rounded,
                                    color: Color(0xFFFF6B9A),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Reset All Data',
                                        style: TextStyle(
                                          color: ui.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Clear profile, onboarding, finance records, bills, savings, smart detection settings, and app preferences on this device.',
                                        style: TextStyle(
                                          color: ui.textSecondary,
                                          fontSize: 12.5,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  unawaited(_showResetAllDataDialog(context));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF5F8F),
                                  foregroundColor: intelliumBackground,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text(
                                  'Reset All Data',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InstalledAppVersionCard extends StatefulWidget {
  const InstalledAppVersionCard({super.key});

  @override
  State<InstalledAppVersionCard> createState() =>
      _InstalledAppVersionCardState();
}

class _InstalledAppVersionCardState extends State<InstalledAppVersionCard> {
  AppInstallInfo? appInfo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await AppInstallInfo.load();
    if (!mounted) return;
    setState(() => appInfo = loaded);
  }

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      title: 'App Version',
      value: appInfo?.versionLabel ?? 'Loading version...',
      subtitle: 'Current installed release build info',
      color: const Color(0xFF6C8CFF),
      icon: Icons.system_update_rounded,
    );
  }
}

class _SettingsActionCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsActionCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: ui.cardDecoration(radius: 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: ui.iconChipBackground(accent, radius: 14),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: ui.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: ui.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsPlaceholderCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String pillLabel;

  const _SettingsPlaceholderCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.pillLabel,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: ui.cardDecoration(radius: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: ui.iconChipBackground(accent, radius: 14),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: ui.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withValues(alpha: .22)),
            ),
            child: Text(
              pillLabel,
              style: TextStyle(
                color: accent,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HelpTutorialScreen extends StatelessWidget {
  const HelpTutorialScreen({super.key});

  Future<void> _replayTutorial(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: _OnboardingFlowSheet(
            onFinish: () async {
              if (!sheetContext.mounted) return;
              Navigator.pop(sheetContext);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    Widget infoCard({
      required IconData icon,
      required Color color,
      required String title,
      required String body,
    }) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: ui.cardDecoration(radius: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: ui.iconChipBackground(color, radius: 14),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      color: ui.textSecondary,
                      fontSize: 12.8,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return PremiumToolScaffold(
      title: 'Help & Tutorial',
      subtitle: 'Learn how to use SweldoTrack',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: ui.sectionContainerDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Help',
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Review the core budgeting terms below or replay the onboarding tutorial any time.',
                    style: TextStyle(
                      color: ui.textSecondary,
                      fontSize: 12.8,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        unawaited(_replayTutorial(context));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: intelliumBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Replay Tutorial',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            infoCard(
              icon: Icons.account_balance_wallet_outlined,
              color: intelliumCyan,
              title: 'Available Balance',
              body:
                  'This is the money you can currently spend after your saved income, expenses, bills, and savings transfers are applied.',
            ),
            const SizedBox(height: 12),
            infoCard(
              icon: Icons.auto_graph_rounded,
              color: const Color(0xFF6C8CFF),
              title: 'Anticipated Balance',
              body:
                  'This projects what your balance may look like after upcoming bills and your current setup are considered.',
            ),
            const SizedBox(height: 12),
            infoCard(
              icon: Icons.speed_rounded,
              color: const Color(0xFFFFC857),
              title: 'Daily Spending Limit',
              body:
                  'This is your suggested daily amount based on the time left before your next cutoff or payday and the balance setup saved on your device.',
            ),
            const SizedBox(height: 12),
            infoCard(
              icon: Icons.receipt_long_rounded,
              color: intelliumPink,
              title: 'Expenses',
              body:
                  'Expenses are your day-to-day spending entries. They reduce Available Balance and build your monthly spending history.',
            ),
            const SizedBox(height: 12),
            infoCard(
              icon: Icons.calendar_month_rounded,
              color: intelliumPurple,
              title: 'Bills',
              body:
                  'Bills help you track upcoming payments, recurring dues, and what has already been settled for the current cycle.',
            ),
            const SizedBox(height: 12),
            infoCard(
              icon: Icons.savings_rounded,
              color: const Color(0xFF57E9C3),
              title: 'Savings',
              body:
                  'Savings lets you track targets, saved amounts, and transfer history without mixing those funds into everyday spending.',
            ),
            const SizedBox(height: 12),
            infoCard(
              icon: Icons.restart_alt_rounded,
              color: const Color(0xFF6C8CFF),
              title: 'Reset Finance Data',
              body:
                  'This clears saved finance records, referrals, and balance setup while keeping your theme and premium state intact.',
            ),
            const SizedBox(height: 12),
            infoCard(
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFFF6B81),
              title: 'Reset All Data',
              body:
                  'This clears local profile, onboarding, finance, preferences, and smart detection settings when you want to start over.',
            ),
            const SizedBox(height: 12),
            infoCard(
              icon: Icons.workspace_premium_rounded,
              color: const Color(0xFFFFC857),
              title: 'Premium',
              body:
                  'Premium unlocks extra themes, advanced analytics, and optional smart tools after a verified Google Play purchase.',
            ),
            const SizedBox(height: 12),
            infoCard(
              icon: Icons.notifications_active_outlined,
              color: intelliumCyan,
              title: 'Smart Expense Detection',
              body:
                  'This optional Android-only feature watches selected app notifications on your device and suggests expenses for you to review before saving.',
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacyDataScreen extends StatelessWidget {
  const PrivacyDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    Widget infoCard({
      required IconData icon,
      required Color color,
      required String title,
      required String body,
    }) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: ui.cardDecoration(radius: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: ui.iconChipBackground(color, radius: 14),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      color: ui.textSecondary,
                      fontSize: 12.8,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return PremiumToolScaffold(
      title: 'Privacy & Data',
      subtitle: 'How SweldoTrack stores and uses your data',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          children: [
            infoCard(
              icon: Icons.save_rounded,
              color: const Color(0xFF6C8CFF),
              title: 'Local storage',
              body:
                  'Finance data is stored locally on this device. No cloud sync is currently implemented in SweldoTrack.',
            ),
            const SizedBox(height: 12),
            infoCard(
              icon: Icons.cloud_off_rounded,
              color: intelliumPurple,
              title: 'No cloud sync yet',
              body:
                  'Your records stay on this device unless you export a backup yourself. SweldoTrack does not currently sync data to an online account.',
            ),
            const SizedBox(height: 12),
            infoCard(
              icon: Icons.notifications_active_outlined,
              color: intelliumCyan,
              title: 'Smart Expense Detection',
              body:
                  'Smart Expense Detection is optional. Notification-based detection does not automatically save expenses and only suggests entries after you enable permission.',
            ),
            const SizedBox(height: 12),
            infoCard(
              icon: Icons.fact_check_outlined,
              color: const Color(0xFF57E9C3),
              title: 'Review before saving',
              body:
                  'Suggested notification items are reviewed by you first. Nothing from supported app notifications is saved automatically.',
            ),
            const SizedBox(height: 12),
            infoCard(
              icon: Icons.folder_copy_outlined,
              color: intelliumBlue,
              title: 'Export, import, and reset',
              body:
                  'You can export local backups, import supported backups, or reset local finance data from Settings whenever you need recovery options.',
            ),
            const SizedBox(height: 12),
            infoCard(
              icon: Icons.verified_user_outlined,
              color: const Color(0xFFFFC857),
              title: 'Premium verification',
              body:
                  'Premium purchase verification may contact the secure verifier when it is configured for Google Play purchase checks.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartExpenseSetupResult {
  final Set<String> monitoredApps;

  const _SmartExpenseSetupResult({required this.monitoredApps});
}

class SmartExpenseDetectionSettingsCard extends StatefulWidget {
  final PremiumService premiumService;

  const SmartExpenseDetectionSettingsCard({
    super.key,
    required this.premiumService,
  });

  @override
  State<SmartExpenseDetectionSettingsCard> createState() =>
      _SmartExpenseDetectionSettingsCardState();
}

class _SmartExpenseDetectionSettingsCardState
    extends State<SmartExpenseDetectionSettingsCard>
    with WidgetsBindingObserver {
  bool loading = true;
  bool detectionEnabled = false;
  bool hasNotificationAccess = false;
  Set<String> monitoredApps = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final isAndroidPlatform =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final enabled = await FinanceRepository.isSmartExpenseDetectionEnabled();
    final selectedApps = await FinanceRepository.getSmartExpenseMonitoredApps();
    final notificationAccess = isAndroidPlatform
        ? await SmartExpenseDetectionBridge.hasNotificationAccess()
        : false;
    final resolvedEnabled = smartExpenseDetectionLaunchEnabled &&
        isAndroidPlatform &&
        widget.premiumService.isPremium &&
        notificationAccess &&
        selectedApps.isNotEmpty &&
        enabled;
    if (enabled != resolvedEnabled) {
      await FinanceRepository.setSmartExpenseDetectionEnabled(resolvedEnabled);
    }
    if (!mounted) return;
    setState(() {
      detectionEnabled = resolvedEnabled;
      monitoredApps = selectedApps.toSet();
      hasNotificationAccess = notificationAccess;
      loading = false;
    });
  }

  Future<void> _disableSmartDetection({
    bool clearMonitoredApps = false,
    String? message,
  }) async {
    await FinanceRepository.setSmartExpenseDetectionEnabled(false);
    if (clearMonitoredApps) {
      await FinanceRepository.setSmartExpenseMonitoredApps(const <String>[]);
    }
    await _load();
    if (!mounted || message == null || message.trim().isEmpty) return;
    showAppMessage(context, message.trim());
  }

  Future<void> _handlePremiumLockedTap() async {
    final canStartPurchase = widget.premiumService.canPurchasePremium;

    if (canStartPurchase) {
      await widget.premiumService.buyPremium();
      return;
    }

    if (!mounted) return;
    showAppMessage(
      context,
      widget.premiumService.premiumPurchaseAvailabilityMessage,
    );
  }

  Future<void> _setDetectionEnabled(bool value) async {
    if (loading) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      showAppMessage(
        context,
        'Smart Expense Detection is available on Android only.',
      );
      return;
    }
    if (!widget.premiumService.isPremium) {
      await _handlePremiumLockedTap();
      return;
    }

    if (!value) {
      await _disableSmartDetection(
        message:
            'Smart Expense Detection is off. Notifications will no longer be checked.',
      );
      return;
    }

    final notificationAccess =
        await SmartExpenseDetectionBridge.hasNotificationAccess();
    if (!notificationAccess) {
      await _disableSmartDetection(
        message:
            'Notification access is required before Smart Expense Detection can be enabled.',
      );
      return;
    }

    await _showSetupSheet();
  }

  Future<void> _showSetupSheet() async {
    final result = await showModalBottomSheet<_SmartExpenseSetupResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: intelliumSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final ui = SweldoVisualStyle.fromContext(sheetContext);
        var permissionGranted = hasNotificationAccess;
        var checkingPermission = false;
        final selectedApps = monitoredApps.isEmpty
            ? <String>{}
            : Set<String>.from(monitoredApps);

        Future<void> refreshPermission(StateSetter setModalState) async {
          setModalState(() => checkingPermission = true);
          final granted =
              await SmartExpenseDetectionBridge.hasNotificationAccess();
          if (!sheetContext.mounted) return;
          setModalState(() {
            permissionGranted = granted;
            checkingPermission = false;
          });
        }

        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 20),
                  Text(
                    'Smart Expense Detection',
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Smart Expense Detection is optional. If enabled, SweldoTrack uses Android Notification Access to check notifications only from the supported apps you select, such as GCash, Maya, Shopee, Lazada, Foodpanda, or Grab. Notification content is processed locally on your device only, nothing is saved automatically, and you review and confirm each suggestion before it is saved. You can turn this off anytime, and you should leave it off if you are uncomfortable with notification access.',
                    style: TextStyle(
                      color: ui.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: ui.cardDecoration(radius: 22).copyWith(
                          border: Border.all(
                            color:
                                const Color(0xFF6C8CFF).withValues(alpha: .18),
                          ),
                        ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step 1 Â· Notification Access',
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          permissionGranted
                              ? 'SweldoTrack can now check notifications only from the supported Android apps you choose after you turn detection on. Notification text stays on this device and is only used to suggest possible expenses for your review.'
                              : 'Grant Android notification access so this optional feature can check notifications only from the supported apps you choose. Notification text is read on this device only for those selected apps, and nothing is saved automatically.',
                          style: TextStyle(
                            color: ui.textSecondary,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                                await SmartExpenseDetectionBridge
                                    .openNotificationAccessSettings();
                                if (!sheetContext.mounted) return;
                                showAppMessage(
                                  sheetContext,
                                  'Enable SweldoTrack notification access in Android settings, then return here and tap "I enabled access". Detection stays off until setup is complete and only the selected supported apps will be checked.',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C8CFF),
                                foregroundColor: intelliumBackground,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const Text(
                                'Open Android Settings',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: checkingPermission
                                  ? null
                                  : () async {
                                      await refreshPermission(setModalState);
                                    },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ui.textPrimary,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: .12),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: Icon(
                                permissionGranted
                                    ? Icons.verified_rounded
                                    : Icons.refresh_rounded,
                              ),
                              label: Text(
                                permissionGranted
                                    ? 'Access Ready'
                                    : checkingPermission
                                        ? 'Checking...'
                                        : 'I enabled access',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: ui.cardDecoration(radius: 22).copyWith(
                          border: Border.all(
                            color:
                                const Color(0xFF7DF9C6).withValues(alpha: .16),
                          ),
                        ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step 2 Â· Choose Monitored Apps',
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Only selected apps are checked, and only after you enable detection. You can change this list anytime or turn the feature off completely.',
                          style: TextStyle(
                            color: ui.textSecondary,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final app in smartExpenseSupportedAppLabels)
                              FilterChip(
                                selected: selectedApps.contains(app),
                                onSelected: (selected) {
                                  setModalState(() {
                                    if (selected) {
                                      selectedApps.add(app);
                                    } else {
                                      selectedApps.remove(app);
                                    }
                                  });
                                },
                                backgroundColor:
                                    ui.cardFill.withValues(alpha: .84),
                                selectedColor: const Color(0xFF6C8CFF)
                                    .withValues(alpha: .18),
                                checkmarkColor: const Color(0xFF7DF9C6),
                                side: BorderSide(
                                  color: selectedApps.contains(app)
                                      ? const Color(0xFF6C8CFF)
                                          .withValues(alpha: .35)
                                      : Colors.white.withValues(alpha: .08),
                                ),
                                label: Text(
                                  app,
                                  style: TextStyle(
                                    color: ui.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Suggestions are review-only. Nothing is saved unless you confirm the expense. You can turn this off anytime, and you should not enable it if you are uncomfortable granting notification access.',
                    style: TextStyle(
                      color: ui.textMuted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Not now'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              permissionGranted && selectedApps.isNotEmpty
                                  ? () {
                                      Navigator.pop(
                                        sheetContext,
                                        _SmartExpenseSetupResult(
                                          monitoredApps: Set<String>.from(
                                            selectedApps,
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C8CFF),
                            foregroundColor: intelliumBackground,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            detectionEnabled
                                ? 'Save Setup'
                                : 'Enable Detection',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == null) return;

    await FinanceRepository.setSmartExpenseMonitoredApps(
      result.monitoredApps.toList(),
    );
    await FinanceRepository.setSmartExpenseDetectionEnabled(true);
    await _load();
    if (!mounted) return;
    showAppMessage(
      context,
      'Smart Expense Detection is on for ${result.monitoredApps.length} selected app${result.monitoredApps.length == 1 ? '' : 's'}. SweldoTrack will only review notifications from those apps, process notification content locally on this device, and wait for your confirmation before saving anything.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final isAndroidPlatform =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: ui.sectionContainerDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF79A8FF),
                      Color(0xFF7A56F5),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Expense Detection',
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Smart Expense Detection is optional. If enabled, SweldoTrack uses Android Notification Access to check notifications only from your selected supported apps. Notification content is processed locally on this device only for those selected apps, nothing is saved automatically, you review and confirm each suggestion before it is saved, and you can turn the feature off anytime. Leave it off if you are not comfortable with notification access.',
                      style: TextStyle(
                        color: ui.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SmartExpenseStatusChip(
                label: 'Android',
                color: Color(0xFF6C8CFF),
                icon: Icons.android_rounded,
              ),
              _SmartExpenseStatusChip(
                label: 'Notification-based',
                color: Color(0xFF7A56F5),
                icon: Icons.notifications_active_outlined,
              ),
              _SmartExpenseStatusChip(
                label: 'Review before save',
                color: Color(0xFF7DF9C6),
                icon: Icons.fact_check_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isAndroidPlatform) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: ui.cardDecoration(radius: 22).copyWith(
                    border: Border.all(
                      color: const Color(0xFFFFC857).withValues(alpha: .18),
                    ),
                  ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Android required',
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Smart Expense Detection only works on Android because it depends on Android notification access. It stays unavailable on other platforms.',
                    style: TextStyle(
                      color: ui.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (!widget.premiumService.isPremium) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: ui.cardDecoration(radius: 22).copyWith(
                    border: Border.all(
                      color: const Color(0xFF7A56F5).withValues(alpha: .18),
                    ),
                  ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premium required',
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Unlock this optional Android-only premium feature for supported apps like GCash, Maya, Grab, Foodpanda, Lazada, and Shopee. You choose which supported apps SweldoTrack can check, notification text is only read for those selected apps on this device, nothing is saved automatically, and you can disable it anytime.',
                    style: TextStyle(
                      color: ui.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.premiumService.canPurchasePremium
                          ? () async {
                              await _handlePremiumLockedTap();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C8CFF),
                        foregroundColor: intelliumBackground,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        widget.premiumService.premiumActionLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (loading) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: buildPageLoadingState(
                'Loading Smart Expense Detection...',
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'Access',
                    value: hasNotificationAccess ? 'Ready' : 'Needed',
                    subtitle: hasNotificationAccess
                        ? 'Notification access is on'
                        : 'Notification access required',
                    color: hasNotificationAccess
                        ? const Color(0xFF7DF9C6)
                        : const Color(0xFFFFC857),
                    icon: hasNotificationAccess
                        ? Icons.verified_rounded
                        : Icons.notifications_off_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryCard(
                    title: 'Detection',
                    value: detectionEnabled ? 'Enabled' : 'Off',
                    subtitle: detectionEnabled
                        ? 'Review-only suggestions from selected apps'
                        : 'Optional for selected apps',
                    color: detectionEnabled
                        ? const Color(0xFF6C8CFF)
                        : intelliumTextMuted,
                    icon: detectionEnabled
                        ? Icons.auto_awesome_rounded
                        : Icons.toggle_off_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SummaryCard(
              title: 'Monitored Apps',
              value: monitoredApps.isEmpty
                  ? 'None'
                  : monitoredApps.length.toString(),
              subtitle: monitoredApps.isEmpty
                  ? 'Choose apps before detection can suggest expenses'
                  : monitoredApps.join(', '),
              color: const Color(0xFF7A56F5),
              icon: Icons.filter_list_rounded,
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: .05)),
              ),
              child: SwitchListTile.adaptive(
                value: detectionEnabled,
                onChanged: (value) async {
                  await _setDetectionEnabled(value);
                },
                activeThumbColor: const Color(0xFF7DF9C6),
                activeTrackColor:
                    const Color(0xFF6C8CFF).withValues(alpha: .35),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                title: const Text(
                  'Enable smart detection',
                  style: TextStyle(
                    color: intelliumTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  hasNotificationAccess
                      ? 'Check only the selected supported apps and show a review sheet when a likely expense is detected. Notification text is processed locally on this device only for those selected apps, and nothing is saved unless you confirm.'
                      : 'Grant Android notification access first, then choose which apps to monitor. Detection stays optional and off until you enable it.',
                  style: const TextStyle(
                    color: intelliumTextMuted,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: ui.cardDecoration(radius: 22).copyWith(
                    border: Border.all(
                      color: const Color(0xFF6C8CFF).withValues(alpha: .14),
                    ),
                  ),
              child: Text(
                'Privacy note: Smart Expense Detection uses Android Notification Access only after you enable it. SweldoTrack checks only the supported apps you select, processes notification content locally on your device, and does not save anything unless you review and confirm it. You can turn this feature off anytime.',
                style: TextStyle(
                  color: ui.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (!hasNotificationAccess) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: ui.cardDecoration(radius: 22).copyWith(
                      border: Border.all(
                        color: const Color(0xFFFFC857).withValues(alpha: .18),
                      ),
                    ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification access required',
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Open Android settings, enable SweldoTrack notification access, then return here. Detection stays off until access is granted and you choose apps to monitor.',
                      style: TextStyle(
                        color: ui.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await SmartExpenseDetectionBridge
                              .openNotificationAccessSettings();
                          await _load();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C8CFF),
                          foregroundColor: intelliumBackground,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Open Notification Access',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    if (monitoredApps.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            await _disableSmartDetection(
                              clearMonitoredApps: true,
                              message:
                                  'Smart Expense Detection has been disabled and monitored apps were cleared.',
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFFC857),
                            side: BorderSide(
                              color: const Color(0xFFFFC857).withValues(
                                alpha: .35,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Disable Smart Detection',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              if (!detectionEnabled && monitoredApps.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: ui.cardDecoration(radius: 22).copyWith(
                        border: Border.all(
                          color: const Color(0xFFFFC857).withValues(alpha: .18),
                        ),
                      ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detection is currently off',
                        style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your monitored apps are saved, but SweldoTrack will not check notifications until you turn detection back on.',
                        style: TextStyle(
                          color: ui.textSecondary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              if (monitoredApps.isNotEmpty)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final app in monitoredApps)
                      Chip(
                        backgroundColor:
                            const Color(0xFF6C8CFF).withValues(alpha: .14),
                        side: BorderSide(
                          color: const Color(0xFF6C8CFF).withValues(alpha: .22),
                        ),
                        label: Text(
                          app,
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await _showSetupSheet();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: intelliumCard,
                    foregroundColor: intelliumTextPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Review Apps And Access',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (detectionEnabled || monitoredApps.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      await _disableSmartDetection(
                        clearMonitoredApps: true,
                        message:
                            'Smart Expense Detection has been disabled and monitored apps were cleared.',
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFC857),
                      side: BorderSide(
                        color: const Color(0xFFFFC857).withValues(alpha: .35),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Disable Smart Detection',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class _SmartExpenseStatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _SmartExpenseStatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class ExpenseTrackerScreen extends StatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  List<ExpenseItem> expenses = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    expenses = await FinanceRepository.loadExpenses();
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> save() async {
    await FinanceRepository.saveExpenses(expenses);
  }

  Future<void> reloadExpenses() async {
    await load();
  }

  Future<void> deleteItem(int index) async {
    expenses.removeAt(index);
    await save();
    if (!mounted) return;
    await reloadExpenses();
  }

  void showAddExpenseSheet({int? editIndex}) {
    FocusScope.of(context).unfocus();
    final existingExpense = editIndex == null ? null : expenses[editIndex];
    final isEditing = existingExpense != null;
    const categoryOptions = {'Food', 'Transport', 'Bills', 'Other'};
    const paymentOptions = {'Cash', 'GCash', 'Maya'};
    final title = TextEditingController(text: existingExpense?.title ?? '');
    final amount = TextEditingController(
      text: existingExpense == null ? '' : existingExpense.amount.toString(),
    );
    String category = categoryOptions.contains(existingExpense?.category)
        ? existingExpense!.category
        : 'Food';
    String payment = paymentOptions.contains(existingExpense?.paymentMethod)
        ? existingExpense!.paymentMethod
        : 'Cash';
    DateTime selectedDate =
        dateOnly(existingExpense?.createdAt ?? DateTime.now());
    var saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: intelliumSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20,
                      MediaQuery.of(context).viewInsets.bottom + 24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SheetHandle(),
                        const SizedBox(height: 20),
                        Text(
                          isEditing ? 'Edit Spending' : 'Add Spending',
                          style: const TextStyle(
                              color: intelliumTextPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: title,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(color: intelliumTextPrimary),
                          decoration: const InputDecoration(
                              labelText: 'Spending Title',
                              hintText: 'Ex. Lunch, Gas, Grocery'),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: amount,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(color: intelliumTextPrimary),
                          decoration: const InputDecoration(
                              labelText: 'Amount', hintText: 'Ex. 250.00'),
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 3650)),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 3650)),
                            );
                            if (pickedDate == null) return;
                            if (!context.mounted) return;
                            setModalState(
                                () => selectedDate = dateOnly(pickedDate));
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Spending Date',
                              hintText: 'Select a date',
                            ),
                            child: Text(
                              formatCalendarDate(selectedDate),
                              style:
                                  const TextStyle(color: intelliumTextPrimary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          dropdownColor: intelliumCard,
                          style: const TextStyle(color: intelliumTextPrimary),
                          items: const [
                            DropdownMenuItem(
                                value: 'Food', child: Text('Food')),
                            DropdownMenuItem(
                                value: 'Transport', child: Text('Transport')),
                            DropdownMenuItem(
                                value: 'Bills', child: Text('Bills')),
                            DropdownMenuItem(
                                value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (v) =>
                              setModalState(() => category = v ?? 'Food'),
                          decoration:
                              const InputDecoration(labelText: 'Category'),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: payment,
                          dropdownColor: intelliumCard,
                          style: const TextStyle(color: intelliumTextPrimary),
                          items: const [
                            DropdownMenuItem(
                                value: 'Cash', child: Text('Cash')),
                            DropdownMenuItem(
                                value: 'GCash', child: Text('GCash')),
                            DropdownMenuItem(
                                value: 'Maya', child: Text('Maya')),
                          ],
                          onChanged: (v) =>
                              setModalState(() => payment = v ?? 'Cash'),
                          decoration: const InputDecoration(
                              labelText: 'Payment Method'),
                        ),
                        const SizedBox(height: 20),
                        PrimaryButton(
                          label: isEditing ? 'Save Changes' : 'Save Spending',
                          onPressed: () async {
                            if (saving) return;
                            final titleValue = title.text.trim();
                            final amountText = amount.text.trim();
                            final amountError = validatePesoAmountInput(
                              amountText,
                              fieldLabel: 'amount',
                            );

                            if (titleValue.isEmpty) {
                              showAppMessage(context, 'Enter a spending title');
                              return;
                            }
                            if (amountError != null) {
                              showAppMessage(context, amountError);
                              return;
                            }
                            final amountValue = parseMoneyInput(amountText)!;
                            setModalState(() => saving = true);
                            final updatedExpense = (existingExpense ??
                                    ExpenseItem(
                                      id: DateTime.now()
                                          .microsecondsSinceEpoch
                                          .toString(),
                                      title: '',
                                      amount: 0,
                                      category: 'Food',
                                      paymentMethod: 'Cash',
                                      createdAt: dateOnly(DateTime.now()),
                                    ))
                                .copyWith(
                              title: titleValue,
                              amount: amountValue,
                              category: category,
                              paymentMethod: payment,
                              createdAt: selectedDate,
                            );
                            if (isEditing) {
                              expenses[editIndex!] = updatedExpense;
                            } else {
                              expenses.insert(0, updatedExpense);
                            }
                            await save();
                            if (!context.mounted || !mounted) return;
                            Navigator.pop(context);
                            await reloadExpenses();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      title.dispose();
      amount.dispose();
    });
  }

  double get totalSpent => expenses.fold<double>(0, (sum, e) => sum + e.amount);

  String get topCategory {
    if (expenses.isEmpty) return 'None';
    final totals = <String, double>{};
    for (final e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
    String best = 'None';
    double bestAmount = 0;
    totals.forEach((key, value) {
      if (value > bestAmount) {
        bestAmount = value;
        best = key;
      }
    });
    return best;
  }

  Color categoryColor(String category) {
    switch (category) {
      case 'Food':
        return const Color(0xFFFFC857);
      case 'Transport':
        return const Color(0xFF6C8CFF);
      case 'Bills':
        return const Color(0xFFB084F5);
      default:
        return const Color(0xFF00C896);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: intelliumBackground,
      appBar: AppBar(
        backgroundColor: intelliumBackground,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        toolbarHeight: 72,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SweldoTrack',
              style: TextStyle(
                  color: intelliumTextPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text(
              'Track what you spend and where it goes',
              style: TextStyle(
                  color: intelliumTextMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddExpenseSheet,
        backgroundColor: intelliumCyan,
        foregroundColor: intelliumBackground,
        icon: const Icon(Icons.add),
        label: const Text('Add Spending',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: loading
          ? buildPageLoadingState('Loading your spending...')
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeroCard(
                    colors: const [
                      Color(0xFF1A2551),
                      intelliumBlue,
                      intelliumPurple
                    ],
                    title: 'Total Spending',
                    value: formatPhp(totalSpent),
                    badge: '${expenses.length} entries | Top: $topCategory',
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: HomeOverviewCard(
                          title: 'Total Spent',
                          value: formatPhp(totalSpent),
                          subtitle: 'All spending entries',
                          color: intelliumCyan,
                          icon: Icons.wallet_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: HomeOverviewCard(
                          title: 'Entries',
                          value: '${expenses.length}',
                          subtitle: 'Transactions added',
                          color: intelliumPink,
                          icon: Icons.receipt_long_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  HomeOverviewCard(
                    title: 'Top Category',
                    value: topCategory,
                    subtitle: 'Highest spending category',
                    color: intelliumPurple,
                    icon: Icons.star_rounded,
                  ),
                  const SizedBox(height: 26),
                  const HomeSectionHeader(
                    title: 'Recent Spending',
                    subtitle: 'Your latest saved spending entries',
                  ),
                  const SizedBox(height: 14),
                  if (expenses.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: intelliumSurface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .05)),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _HomeEmptyIcon(
                            icon: Icons.wallet_rounded,
                            color: intelliumCyan,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No spending yet',
                            style: TextStyle(
                                color: intelliumTextPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Add your first spending entry to start tracking where your money goes.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: intelliumTextSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    )
                  else
                    ...List.generate(expenses.length, (index) {
                      final item = expenses[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: intelliumSurface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: .05)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 48,
                                width: 48,
                                decoration: BoxDecoration(
                                  color: categoryColor(item.category)
                                      .withValues(alpha: .16),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(Icons.receipt_long_rounded,
                                    color: categoryColor(item.category)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: intelliumTextPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.category} | ${item.paymentMethod}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: intelliumTextMuted,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formatCalendarDate(item.createdAt),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: intelliumTextSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 96),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        formatPhp(item.amount),
                                        style: const TextStyle(
                                            color: intelliumTextPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(
                                            minWidth: 36, minHeight: 36),
                                        padding: EdgeInsets.zero,
                                        onPressed: () => showAddExpenseSheet(
                                            editIndex: index),
                                        icon: const Icon(Icons.edit_outlined),
                                        color: intelliumTextMuted,
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(
                                            minWidth: 36, minHeight: 36),
                                        padding: EdgeInsets.zero,
                                        onPressed: () => deleteItem(index),
                                        icon: const Icon(
                                            Icons.delete_outline_rounded),
                                        color: intelliumTextMuted,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class SweldoBudgetScreen extends StatefulWidget {
  const SweldoBudgetScreen({super.key});

  @override
  State<SweldoBudgetScreen> createState() => _SweldoBudgetScreenState();
}

class _SweldoBudgetScreenState extends State<SweldoBudgetScreen> {
  final salaryController = TextEditingController();
  final daysController = TextEditingController();
  final targetSavingsController = TextEditingController();
  final manualDailyBudgetController = TextEditingController();

  List<IncomeEntry> incomeEntries = [];
  List<FixedExpenseItem> fixedExpenses = [];
  DateTime? salaryReceivedDate;
  DateTime? nextPaydayDate;
  double loggedExpenses = 0;
  double trackedBills = 0;
  double currentBalance = 0;
  double totalIncomeAdded = 0;
  double paidBillsTotal = 0;
  double savingsTransferred = 0;
  bool useManualDailyBudget = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final startingBalance = await FinanceRepository.getStartingBalance();
    final daysUntilPayday = await FinanceRepository.getDaysUntilPayday();
    final targetSavingsAmount = await FinanceRepository.getSavingsGoal();
    final dailyBudgetSettings =
        await FinanceRepository.getDailyBudgetSettings();
    final loadedSalaryReceivedDate =
        await FinanceRepository.getSalaryReceivedDate();
    final loadedNextPaydayDate = await FinanceRepository.getNextPaydayDate();
    final loadedIncomeEntries = await FinanceRepository.loadIncomeEntries();
    final loadedFixedExpenses = await FinanceRepository.loadFixedExpenses();
    final expenses = await FinanceRepository.loadExpenses();
    final bills = await FinanceRepository.loadBills();
    final trackedSavingsAmount =
        await FinanceRepository.getTrackedSavingsAmount();
    final savingsHistory = await FinanceRepository.loadSavingsHistory();
    final overview = recalculateBudget(
      startingBalance: startingBalance,
      incomeEntries: loadedIncomeEntries,
      savingsBalance: trackedSavingsAmount,
      savingsHistory: savingsHistory,
      bills: bills,
      expenses: expenses,
      cycleStartDate: loadedSalaryReceivedDate,
      nextCutoffDate: loadedNextPaydayDate,
      fallbackDaysUntilCutoff: daysUntilPayday,
      useManualDailyBudget: dailyBudgetSettings.useManualDailyBudget,
      manualDailyBudget: dailyBudgetSettings.manualDailyBudget,
    );
    final ledger = calculateBalanceLedgerSnapshot(
      startingBalance: startingBalance,
      incomeEntries: loadedIncomeEntries,
      bills: bills,
      expenses: expenses,
      savingsBalance: trackedSavingsAmount,
      savingsHistory: savingsHistory,
    );
    if (!mounted) return;
    salaryController.text = startingBalance.toStringAsFixed(0);
    daysController.text = daysUntilPayday.toString();
    targetSavingsController.text = targetSavingsAmount.toStringAsFixed(0);
    manualDailyBudgetController.text =
        dailyBudgetSettings.manualDailyBudget == null
            ? ''
            : dailyBudgetSettings.manualDailyBudget!.toStringAsFixed(0);
    setState(() {
      incomeEntries = loadedIncomeEntries;
      salaryReceivedDate = loadedSalaryReceivedDate;
      nextPaydayDate = loadedNextPaydayDate;
      fixedExpenses = loadedFixedExpenses;
      loggedExpenses = overview.snapshot.totalLoggedExpenses;
      trackedBills = overview.snapshot.totalBills;
      currentBalance = ledger.availableBalance;
      totalIncomeAdded = ledger.totalIncome;
      paidBillsTotal = ledger.settledBillsTotal;
      savingsTransferred = trackedSavingsAmount;
      useManualDailyBudget = overview.snapshot.usesManualDailyBudget;
      loading = false;
    });
  }

  Future<void> saveSetup() async {
    final startingBalanceValue =
        parseMoneyInput(salaryController.text, allowNegative: false) ?? 0;
    final daysUntilNextCutoff = int.tryParse(daysController.text.trim()) ?? 0;
    final savingsGoalTarget =
        parseMoneyInput(targetSavingsController.text, allowNegative: false) ??
            0;

    await FinanceRepository.saveBalanceSetup(
      startingBalance: startingBalanceValue,
      daysUntilPayday: daysUntilNextCutoff,
      savingsGoalTarget: savingsGoalTarget,
      cycleStartDate: salaryReceivedDate,
      nextCutoffDate: nextPaydayDate,
      useManualDailyBudget: useManualDailyBudget,
      manualDailyBudget: manualDailyBudget,
    );
  }

  Future<void> saveExpenses() async {
    await FinanceRepository.saveFixedExpenses(fixedExpenses);
  }

  double get salary =>
      parseMoneyInput(salaryController.text, allowNegative: false) ?? 0;
  int get days => int.tryParse(daysController.text.trim()) ?? 0;
  double get targetSavings =>
      parseMoneyInput(targetSavingsController.text, allowNegative: false) ?? 0;
  double? get manualDailyBudget => parseMoneyInput(
        manualDailyBudgetController.text,
        allowNegative: false,
      );
  int get remainingDays => calculateRemainingSweldoDays(
        nextPaydayDate: nextPaydayDate,
        fallbackDaysUntilPayday: days,
      );
  BudgetSnapshot get budgetSnapshot => calculateBudgetSnapshot(
        incomeTotal: totalIncomeAdded,
        upcomingBillsAmount: trackedBills,
        spendingAmount: loggedExpenses,
        remainingDays: remainingDays,
        availableBalance: currentBalance,
        savingsBalance: savingsTransferred,
        settledBillsAmount: paidBillsTotal,
        useManualDailyBudget: useManualDailyBudget,
        manualDailyBudget: manualDailyBudget,
      );

  Future<T?> _pushScreen<T>(Widget screen) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _openSummaryScreen(Widget screen) async {
    await _pushScreen<void>(screen);
    if (!mounted) return;
    await load();
  }

  Future<void> showSetupSheet() async {
    FocusScope.of(context).unfocus();
    final tempSalary = TextEditingController(text: salaryController.text);
    final tempDays = TextEditingController(text: daysController.text);
    final tempTarget =
        TextEditingController(text: targetSavingsController.text);
    final tempManualDailyBudget = TextEditingController(
      text: manualDailyBudgetController.text,
    );
    var tempSalaryReceivedDate = salaryReceivedDate;
    var tempNextPaydayDate = nextPaydayDate;
    var tempUseManualDailyBudget = useManualDailyBudget;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: intelliumSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 18, 20, MediaQuery.of(context).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SheetHandle(),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Balance Setup',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                        controller: tempSalary,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            labelText: 'Opening Balance',
                            hintText: 'Ex. 5,000.00')),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: tempSalaryReceivedDate ?? DateTime.now(),
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 3650)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (pickedDate == null) return;
                        if (!context.mounted) return;
                        setModalState(
                            () => tempSalaryReceivedDate = pickedDate);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Cutoff Start Date',
                          hintText: 'Optional start date',
                        ),
                        child: Text(
                          tempSalaryReceivedDate == null
                              ? 'Tap to choose a date'
                              : formatCalendarDate(tempSalaryReceivedDate!),
                          style: TextStyle(
                              color: tempSalaryReceivedDate == null
                                  ? intelliumTextMuted
                                  : intelliumTextPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: tempNextPaydayDate ??
                              DateTime.now().add(const Duration(days: 14)),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (pickedDate == null) return;
                        if (!context.mounted) return;
                        final computedDays = calculateRemainingSweldoDays(
                          nextPaydayDate: pickedDate,
                          fallbackDaysUntilPayday: 0,
                        );
                        setModalState(() {
                          tempNextPaydayDate = pickedDate;
                          tempDays.text = computedDays.toString();
                        });
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Next Cutoff Date',
                          hintText: 'Select cycle end date',
                        ),
                        child: Text(
                          tempNextPaydayDate == null
                              ? 'Optional if you prefer using days'
                              : formatCalendarDate(tempNextPaydayDate!),
                          style: TextStyle(
                              color: tempNextPaydayDate == null
                                  ? intelliumTextMuted
                                  : intelliumTextPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: tempDays,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: 'Remaining Days Until Next Cutoff',
                          hintText:
                              'Optional if you prefer days instead of a date'),
                      onChanged: (_) {
                        if (tempNextPaydayDate != null) {
                          setModalState(() => tempNextPaydayDate = null);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                        controller: tempTarget,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            labelText: 'Savings Target',
                            hintText: 'Ex. 10,000.00')),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .05)),
                      ),
                      child: SwitchListTile.adaptive(
                        value: tempUseManualDailyBudget,
                        onChanged: (value) {
                          setModalState(() {
                            tempUseManualDailyBudget = value;
                          });
                        },
                        activeThumbColor: intelliumCyan,
                        activeTrackColor: intelliumCyan.withValues(alpha: .35),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: const Text(
                          'Use manual daily spending limit',
                          style: TextStyle(
                            color: intelliumTextPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          tempUseManualDailyBudget
                              ? 'Set your own daily spending limit and compare it against the recommended auto amount.'
                              : 'Let the app calculate your daily spending limit automatically from Anticipated Balance.',
                          style: const TextStyle(
                            color: intelliumTextMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                    if (tempUseManualDailyBudget) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: tempManualDailyBudget,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Manual Daily Spending Limit',
                          hintText: 'Ex. 500',
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Save Setup',
                      onPressed: () async {
                        if (saving) return;
                        final salaryText = tempSalary.text.trim();
                        final daysText = tempDays.text.trim();
                        final targetText = tempTarget.text.trim();
                        final manualDailyBudgetText =
                            tempManualDailyBudget.text.trim();
                        final salaryValue = parseMoneyInput(
                          salaryText.isEmpty ? '0' : salaryText,
                        );
                        final daysValue = int.tryParse(daysText);
                        final targetValue = parseMoneyInput(
                          targetText.isEmpty ? '0' : targetText,
                          allowNegative: false,
                        );
                        final manualDailyBudgetValue = parseMoneyInput(
                          manualDailyBudgetText.isEmpty
                              ? '0'
                              : manualDailyBudgetText,
                          allowNegative: false,
                        );
                        final resolvedDays = tempNextPaydayDate != null
                            ? calculateRemainingSweldoDays(
                                nextPaydayDate: tempNextPaydayDate,
                                fallbackDaysUntilPayday: 0,
                              )
                            : (daysValue ?? 0);
                        final openingBalanceError = validatePesoAmountInput(
                          salaryText,
                          fieldLabel: 'opening available balance',
                          allowZero: true,
                        );
                        final targetAmountError = targetText.isEmpty
                            ? null
                            : validatePesoAmountInput(
                                targetText,
                                fieldLabel: 'savings target amount',
                                allowZero: true,
                              );
                        final manualDailyBudgetError = tempUseManualDailyBudget
                            ? validatePesoAmountInput(
                                manualDailyBudgetText,
                                fieldLabel: 'manual daily spending limit',
                              )
                            : null;

                        if (openingBalanceError != null) {
                          showAppMessage(context, openingBalanceError);
                          return;
                        }
                        if (tempSalaryReceivedDate != null &&
                            tempNextPaydayDate != null &&
                            !dateOnly(tempNextPaydayDate!)
                                .isAfter(dateOnly(tempSalaryReceivedDate!))) {
                          showAppMessage(context,
                              'Next cutoff must be after the cutoff start date');
                          return;
                        }
                        if (tempNextPaydayDate == null && daysValue == null) {
                          showAppMessage(
                              context, 'Enter a valid whole number of days');
                          return;
                        }
                        if (resolvedDays < 0) {
                          showAppMessage(
                              context, 'Remaining days cannot be negative');
                          return;
                        }
                        if (targetAmountError != null) {
                          showAppMessage(context, targetAmountError);
                          return;
                        }
                        if (manualDailyBudgetError != null) {
                          showAppMessage(context, manualDailyBudgetError);
                          return;
                        }
                        final resolvedSalaryValue = salaryValue ?? 0;
                        final resolvedTargetValue = targetValue ?? 0;

                        final projectedSnapshot = calculateBudgetSnapshot(
                          incomeTotal: totalIncomeAdded,
                          upcomingBillsAmount: trackedBills,
                          spendingAmount: loggedExpenses,
                          remainingDays: resolvedDays,
                          availableBalance: currentBalance,
                          savingsBalance: savingsTransferred,
                          settledBillsAmount: paidBillsTotal,
                          useManualDailyBudget: tempUseManualDailyBudget,
                          manualDailyBudget: tempUseManualDailyBudget
                              ? manualDailyBudgetValue
                              : null,
                        );

                        setModalState(() => saving = true);
                        salaryController.text =
                            resolvedSalaryValue.toStringAsFixed(0);
                        daysController.text = resolvedDays.toString();
                        targetSavingsController.text =
                            resolvedTargetValue.toStringAsFixed(0);
                        manualDailyBudgetController.text =
                            tempUseManualDailyBudget &&
                                    manualDailyBudgetValue != null
                                ? manualDailyBudgetValue.toStringAsFixed(0)
                                : '';
                        salaryReceivedDate = tempSalaryReceivedDate;
                        nextPaydayDate = tempNextPaydayDate;
                        useManualDailyBudget = tempUseManualDailyBudget;
                        await saveSetup();
                        await load();
                        if (!context.mounted || !mounted) return;
                        Navigator.pop(context);
                        if (projectedSnapshot.usesManualDailyBudget &&
                            !projectedSnapshot.isManualDailyBudgetSafe) {
                          showAppMessage(
                            context,
                            'Manual daily spending limit saved, but it is above the safe cutoff pace.',
                          );
                        }
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    tempSalary.dispose();
    tempDays.dispose();
    tempTarget.dispose();
    tempManualDailyBudget.dispose();
  }

  Future<void> showAddFixedExpense() async {
    final item = await _pushScreen<FixedExpenseItem>(const AddBillScreen());
    if (item == null) return;
    fixedExpenses.add(item);
    await saveExpenses();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deleteIncomeEntry(String incomeEntryId) async {
    incomeEntries.removeWhere((item) => item.id == incomeEntryId);
    await FinanceRepository.saveIncomeEntries(incomeEntries);
    if (!mounted) return;
    await load();
    setState(() {});
  }

  Future<void> showAddIncomeEntry({IncomeEntry? existingEntry}) async {
    FocusScope.of(context).unfocus();
    final amountController = TextEditingController(
      text:
          existingEntry == null ? '' : existingEntry.amount.toStringAsFixed(2),
    );
    final noteController =
        TextEditingController(text: existingEntry?.note ?? '');
    var receivedAt = dateOnly(existingEntry?.receivedAt ?? DateTime.now());
    var saving = false;
    final isEditing = existingEntry != null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: intelliumSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SheetHandle(),
                    const SizedBox(height: 20),
                    Text(
                      isEditing ? 'Edit Income' : 'Add Income',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Ex. 15,000.00',
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: receivedAt,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 3650)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (pickedDate == null) return;
                        if (!context.mounted) return;
                        setModalState(() => receivedAt = pickedDate);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Received Date',
                        ),
                        child: Text(
                          formatCalendarDate(receivedAt),
                          style: const TextStyle(color: intelliumTextPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: noteController,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        hintText: 'Ex. 15th cutoff income',
                      ),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: isEditing ? 'Save Changes' : 'Save Income Entry',
                      onPressed: () async {
                        if (saving) return;
                        final amountError = validatePesoAmountInput(
                          amountController.text,
                          fieldLabel: 'income amount',
                        );
                        if (amountError != null) {
                          showAppMessage(context, amountError);
                          return;
                        }
                        final amount = parseMoneyInput(amountController.text)!;
                        setModalState(() => saving = true);
                        final updatedEntry = (existingEntry ??
                                IncomeEntry(
                                  id: DateTime.now()
                                      .microsecondsSinceEpoch
                                      .toString(),
                                  amount: 0,
                                  receivedAt: receivedAt,
                                  note: '',
                                ))
                            .copyWith(
                          amount: amount,
                          receivedAt: receivedAt,
                          note: noteController.text.trim(),
                        );
                        final existingIndex = incomeEntries.indexWhere(
                          (item) => item.id == updatedEntry.id,
                        );
                        if (existingIndex >= 0) {
                          incomeEntries[existingIndex] = updatedEntry;
                          await FinanceRepository.saveIncomeEntries(
                              incomeEntries);
                        } else {
                          await FinanceRepository.addIncomeEntry(updatedEntry);
                        }
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    amountController.dispose();
    noteController.dispose();
    if (!mounted) return;
    await load();
    setState(() {});
  }

  Future<void> deleteFixedExpense(int index) async {
    fixedExpenses.removeAt(index);
    await saveExpenses();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> showStartingBalanceEditor() async {
    FocusScope.of(context).unfocus();
    final amountController = TextEditingController(
      text: salary > 0 ? salary.toStringAsFixed(2) : '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: intelliumSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        String? validationMessage;
        var saving = false;

        return StatefulBuilder(
          builder: (context, setSheetState) => GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SheetHandle(),
                    const SizedBox(height: 20),
                    const Text(
                      'How much is your opening available balance?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (_) {
                        if (validationMessage != null) {
                          setSheetState(() => validationMessage = null);
                        }
                      },
                      onSubmitted: (_) async {
                        final amountError = validatePesoAmountInput(
                          amountController.text,
                          fieldLabel: 'opening available balance',
                          allowZero: true,
                        );
                        if (amountError != null) {
                          setSheetState(() => validationMessage = amountError);
                          return;
                        }
                        final parsedValue = parseMoneyInput(
                          amountController.text,
                        )!;
                        FocusScope.of(context).unfocus();
                        salaryController.text = parsedValue.toStringAsFixed(2);
                        await FinanceRepository.setStartingBalance(parsedValue);
                        await load();
                        if (!sheetContext.mounted || !mounted) return;
                        Navigator.pop(sheetContext);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Opening Balance',
                        hintText: 'Ex. 5000.00',
                      ),
                    ),
                    if (validationMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        validationMessage!,
                        style: const TextStyle(
                          color: Color(0xFFFF8A8A),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              Navigator.pop(sheetContext);
                            },
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Save',
                            onPressed: () async {
                              if (saving) return;
                              final amountError = validatePesoAmountInput(
                                amountController.text,
                                fieldLabel: 'opening available balance',
                                allowZero: true,
                              );
                              if (amountError != null) {
                                setSheetState(
                                  () => validationMessage = amountError,
                                );
                                return;
                              }
                              final parsedValue = parseMoneyInput(
                                amountController.text,
                              )!;
                              setSheetState(() => saving = true);
                              FocusScope.of(context).unfocus();
                              salaryController.text =
                                  parsedValue.toStringAsFixed(2);
                              await FinanceRepository.setStartingBalance(
                                parsedValue,
                              );
                              await load();
                              if (!sheetContext.mounted || !mounted) return;
                              Navigator.pop(sheetContext);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    amountController.dispose();
  }

  Widget _buildIncomeHistorySection() {
    final items = incomeEntries.toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Income History',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            items.isEmpty
                ? 'Income entries will appear here once you add them.'
                : 'Every saved income entry increases Available Balance.',
            style: const TextStyle(
              color: intelliumTextMuted,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const EmptyStateCard(
              icon: Icons.account_balance_wallet_rounded,
              title: 'No income yet',
              subtitle:
                  'Add your first income entry to keep Available Balance and Daily Spending Limit accurate.',
            )
          else
            ...items.take(5).map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: const Color(0x3300C896),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Color(0xFF00C896),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.note.isEmpty ? 'Income' : item.note,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatCalendarDate(item.receivedAt),
                                style: const TextStyle(
                                  color: intelliumTextMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatPhp(item.amount),
                              style: const TextStyle(
                                color: Color(0xFF00C896),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: () =>
                                      showAddIncomeEntry(existingEntry: item),
                                  icon: const Icon(Icons.edit_outlined),
                                  color: intelliumTextMuted,
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _deleteIncomeEntry(item.id),
                                  icon:
                                      const Icon(Icons.delete_outline_rounded),
                                  color: intelliumTextMuted,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    salaryController.dispose();
    daysController.dispose();
    targetSavingsController.dispose();
    manualDailyBudgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = budgetSnapshot.availableBalance < 0
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF00C896);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Income & Balance',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: () {
              unawaited(showSetupSheet());
            },
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          unawaited(showAddIncomeEntry());
        },
        backgroundColor: const Color(0xFF00C896),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Add Income',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: loading
          ? buildPageLoadingState(
              'Loading income, balances, and your current budget snapshot...')
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeroCard(
                    colors: [
                      accent,
                      const Color(0xFF0F172A),
                      const Color(0xFF0B0F1A)
                    ],
                    title: 'Available Balance',
                    value: formatPhp(budgetSnapshot.availableBalance),
                    badge: budgetSnapshot.usesManualDailyBudget
                        ? '${formatPhp(budgetSnapshot.totalIncomeAdded)} total income | ${formatPhp(budgetSnapshot.autoDailyBudget)} recommended daily limit'
                        : remainingDays > 0
                            ? '${formatPhp(budgetSnapshot.projectedAvailableBalance)} anticipated balance | ${formatPhp(budgetSnapshot.dailyBudget)} daily spending limit'
                            : 'No cutoff date set yet. Daily spending limit uses Anticipated Balance for now.',
                    onTap: () =>
                        _openSummaryScreen(const SalaryOverviewScreen()),
                  ),
                  const SizedBox(height: 12),
                  _buildIncomeHistorySection(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SummaryCard(
                          title: 'Opening Balance',
                          value: formatPhp(salary),
                          subtitle:
                              'Money available before future income entries',
                          color: const Color(0xFF6C8CFF),
                          icon: Icons.payments_rounded,
                          onTap: () {
                            unawaited(showStartingBalanceEditor());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SummaryCard(
                          title: 'Upcoming Bills',
                          value: formatPhp(budgetSnapshot.totalBills),
                          subtitle: 'Scheduled unpaid bills',
                          color: const Color(0xFFFFC857),
                          icon: Icons.receipt_long_rounded,
                          onTap: () => _openSummaryScreen(const BillsScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SummaryCard(
                          title: 'Savings Balance',
                          value: formatPhp(savingsTransferred),
                          subtitle: 'Money set aside',
                          color: const Color(0xFFB084F5),
                          icon: Icons.savings_rounded,
                          onTap: () => _openSummaryScreen(
                              const UnifiedSavingsGoalScreen()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SummaryCard(
                          title: 'Daily Spending Limit',
                          value: formatPhp(budgetSnapshot.dailyBudget),
                          subtitle: dailyBudgetSummaryText(
                              budgetSnapshot, remainingDays),
                          color: accent,
                          icon: Icons.today_rounded,
                          onTap: () =>
                              _openSummaryScreen(const DailyBudgetScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SummaryCard(
                          title: 'Anticipated Balance',
                          value: formatPhp(
                              budgetSnapshot.projectedAvailableBalance),
                          subtitle:
                              'Estimated balance after upcoming unpaid bills',
                          color: const Color(0xFF00C896),
                          icon: Icons.shield_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SummaryCard(
                          title: 'Paid Bills',
                          value: formatPhp(paidBillsTotal),
                          subtitle: 'Already deducted once',
                          color: const Color(0xFFFFC857),
                          icon: Icons.check_circle_rounded,
                          onTap: () => _openSummaryScreen(const BillsScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SummaryCard(
                          title: 'Income',
                          value: formatPhp(budgetSnapshot.totalIncomeAdded),
                          subtitle: 'Total income added so far',
                          color: const Color(0xFF6C8CFF),
                          icon: Icons.account_balance_wallet_rounded,
                          onTap: () => _openSummaryScreen(
                              const SalaryAfterBillsScreen()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SummaryCard(
                          title: 'Spending',
                          value: formatPhp(budgetSnapshot.totalLoggedExpenses),
                          subtitle: 'Logged in the active cutoff',
                          color: const Color(0xFFFF6B6B),
                          icon: Icons.wallet_rounded,
                          onTap: () =>
                              _openSummaryScreen(const ExpensesScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  const Text('Fixed Deductions',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  if (fixedExpenses.isEmpty)
                    const EmptyStateCard(
                        icon: Icons.payments_rounded,
                        title: 'No fixed deductions yet',
                        subtitle:
                            'Add recurring deductions for planning and reference.')
                  else
                    ...List.generate(fixedExpenses.length, (index) {
                      final item = fixedExpenses[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.receipt_long_rounded,
                                    color: Color(0xFFFFC857)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(item.name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700)),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(formatPhp(item.amount),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800)),
                                  IconButton(
                                    onPressed: () => deleteFixedExpense(index),
                                    icon: const Icon(
                                        Icons.delete_outline_rounded),
                                    color: Colors.white54,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class SavingsGoalScreen extends StatefulWidget {
  const SavingsGoalScreen({super.key});

  @override
  State<SavingsGoalScreen> createState() => _SavingsGoalScreenState();
}

class _SavingsGoalScreenState extends State<SavingsGoalScreen> {
  bool loading = true;
  double goal = 0;
  double saved = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    goal = await FinanceRepository.getSavingsGoal();
    saved = await FinanceRepository.getTrackedSavingsAmount();
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> addSavings() async {
    final controller = TextEditingController();
    var saving = false;
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: intelliumSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(sheetContext).unfocus(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 20),
                  const Text(
                    'Add to Savings',
                    style: TextStyle(
                        color: intelliumTextPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: intelliumTextPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Amount to add',
                      hintText: 'Ex. 500.00',
                    ),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Save',
                    onPressed: () async {
                      if (saving) return;
                      final amountError = validatePesoAmountInput(
                        controller.text,
                        fieldLabel: 'amount',
                      );
                      if (amountError != null) {
                        showAppMessage(context, amountError);
                        return;
                      }
                      final value = parseMoneyInput(controller.text)!;
                      final startingBalance =
                          await FinanceRepository.getStartingBalance();
                      final incomeEntries =
                          await FinanceRepository.loadIncomeEntries();
                      final bills = await FinanceRepository.loadBills();
                      final expenses = await FinanceRepository.loadExpenses();
                      final savingsHistory =
                          await FinanceRepository.loadSavingsHistory();
                      final ledger = calculateBalanceLedgerSnapshot(
                        startingBalance: startingBalance,
                        incomeEntries: incomeEntries,
                        bills: bills,
                        expenses: expenses,
                        savingsBalance: saved,
                        savingsHistory: savingsHistory,
                      );
                      if (!context.mounted || !mounted) return;
                      if (value > ledger.availableBalance + 0.001) {
                        showAppMessage(
                          context,
                          'Not enough available balance for this transfer',
                        );
                        return;
                      }
                      saving = true;
                      await FinanceRepository.addSavingsTransfer(
                        SavingsContributionEntry(
                          id: DateTime.now().microsecondsSinceEpoch.toString(),
                          amount: value,
                          createdAt: DateTime.now(),
                          type: SavingsTransferType.contribution,
                        ),
                      );
                      if (!context.mounted || !mounted) return;
                      Navigator.pop(context);
                      await load();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> setGoal() async {
    final controller = TextEditingController(text: goal.toStringAsFixed(0));
    var saving = false;
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: intelliumSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(sheetContext).unfocus(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 20),
                  const Text(
                    'Set New Goal',
                    style: TextStyle(
                        color: intelliumTextPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: intelliumTextPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Savings target',
                      hintText: 'Ex. 10,000.00',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Saving a new goal will reset your current saved progress to \u20B10.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Color(0xFFFFC857),
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Save Goal',
                    onPressed: () async {
                      if (saving) return;
                      final amountError = validatePesoAmountInput(
                        controller.text,
                        fieldLabel: 'savings target amount',
                      );
                      if (amountError != null) {
                        showAppMessage(context, amountError);
                        return;
                      }
                      final value = parseMoneyInput(controller.text)!;
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          backgroundColor: intelliumSurface,
                          title: const Text('Reset current progress?',
                              style: TextStyle(color: intelliumTextPrimary)),
                          content: const Text(
                            'Setting a new savings target will reset your current saved progress to \u20B10.',
                            style: TextStyle(color: intelliumTextSecondary),
                          ),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('Continue')),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      saving = true;
                      goal = value;
                      saved = 0;
                      await FinanceRepository.setSavingsGoal(goal);
                      await FinanceRepository.clearSavingsProgress();
                      if (!context.mounted || !mounted) return;
                      Navigator.pop(context);
                      await load();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        goal <= 0 ? 0.0 : (saved / goal).clamp(0.0, 1.0).toDouble();
    final remaining = max(0.0, goal - saved);

    return Scaffold(
      backgroundColor: intelliumBackground,
      appBar: AppBar(
        backgroundColor: intelliumBackground,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        toolbarHeight: 72,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Savings Target',
              style: TextStyle(
                  color: intelliumTextPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text(
              'Build progress toward your savings balance target',
              style: TextStyle(
                  color: intelliumTextMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          unawaited(addSavings());
        },
        backgroundColor: intelliumCyan,
        foregroundColor: intelliumBackground,
        icon: const Icon(Icons.add),
        label: const Text('Add to Savings',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: loading
          ? buildPageLoadingState('Loading your savings...')
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeroCard(
                    colors: const [
                      Color(0xFF2C2A58),
                      intelliumPurple,
                      intelliumBlue
                    ],
                    title: 'Savings Progress',
                    value: '${formatPhp(saved)} / ${formatPhp(goal)}',
                    badge: '${(progress * 100).toInt()}% completed',
                    progress: progress.toDouble(),
                    progressColor: intelliumCyan,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: HomeOverviewCard(
                          title: 'Saved So Far',
                          value: formatPhp(saved),
                          subtitle: 'Savings balance',
                          color: intelliumCyan,
                          icon: Icons.savings_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: HomeOverviewCard(
                          title: 'Remaining',
                          value: formatPhp(remaining),
                          subtitle: 'Still needed',
                          color: intelliumPink,
                          icon: Icons.flag_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  HomeOverviewCard(
                    title: 'Savings Target',
                    value: formatPhp(goal),
                    subtitle: 'Target amount',
                    color: intelliumPurple,
                    icon: Icons.track_changes_rounded,
                  ),
                  if (goal <= 0 && saved <= 0) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: intelliumSurface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .05)),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _HomeEmptyIcon(
                            icon: Icons.savings_rounded,
                            color: intelliumPurple,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No savings target yet',
                            style: TextStyle(
                                color: intelliumTextPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Set a goal and add savings to start tracking your progress.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: intelliumTextSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      unawaited(setGoal());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: intelliumSurface,
                      foregroundColor: intelliumTextPrimary,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: .06)),
                    ),
                    child: const Text('Set New Goal',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
    );
  }
}

class BillsTrackerScreen extends StatefulWidget {
  const BillsTrackerScreen({super.key});

  @override
  State<BillsTrackerScreen> createState() => _BillsTrackerScreenState();
}

class _BillsTrackerScreenState extends State<BillsTrackerScreen> {
  List<BillItem> bills = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    bills = await FinanceRepository.loadBills();
    bills.sort(FinanceRepository._compareBillItems);
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> save() async {
    await FinanceRepository.saveBills(bills);
    bills.sort(FinanceRepository._compareBillItems);
  }

  Future<void> togglePaid(int index) async {
    final bill = bills[index];
    final markAsPaid = billHasOutstandingBalance(bill);
    bills[index] = bill.copyWith(
      isPaid: markAsPaid,
      paidDate: markAsPaid ? dateOnly(DateTime.now()) : null,
      settledCycleKey: markAsPaid && bill.isRecurring
          ? resolveBillCurrentCycleKey(bill)
          : null,
    );
    await save();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> deleteBill(int index) async {
    bills.removeAt(index);
    await save();
    if (!mounted) return;
    setState(() {});
  }

  void showAddBillSheet({int? editIndex}) {
    FocusScope.of(context).unfocus();
    final existingBill = editIndex == null ? null : bills[editIndex];
    final isEditing = existingBill != null;
    const categoryOptions = {'Utilities', 'Internet', 'Loan', 'Other'};
    final title = TextEditingController(text: existingBill?.title ?? '');
    final amount = TextEditingController(
      text: existingBill == null ? '' : existingBill.amount.toString(),
    );
    String category = categoryOptions.contains(existingBill?.category)
        ? existingBill!.category
        : 'Utilities';
    bool recurring = existingBill?.isRecurring ?? true;
    DateTime dueDate = dateOnly(existingBill?.dueDate ?? DateTime.now());
    final wasSettledForCurrentCycle = existingBill != null
        ? isBillSettledForCurrentCycle(existingBill)
        : false;
    bool isPaid = wasSettledForCurrentCycle;
    DateTime? paidDate =
        isPaid ? (existingBill.paidDate ?? dateOnly(DateTime.now())) : null;
    var saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: intelliumSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 18, 20, MediaQuery.of(context).viewInsets.bottom + 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SheetHandle(),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isEditing
                              ? 'Edit Upcoming Bill'
                              : 'Add Upcoming Bill',
                          style: const TextStyle(
                              color: intelliumTextPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: title,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: intelliumTextPrimary),
                        decoration: const InputDecoration(
                            labelText: 'Bill Title',
                            hintText: 'Ex. Electricity'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(color: intelliumTextPrimary),
                        decoration: const InputDecoration(
                            labelText: 'Amount', hintText: 'Ex. 1,250.00'),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: recurring,
                        activeThumbColor: intelliumCyan,
                        title: const Text('Recurring Bill',
                            style: TextStyle(color: intelliumTextPrimary)),
                        subtitle: const Text(
                            'Turn on if this bill repeats monthly',
                            style: TextStyle(color: intelliumTextMuted)),
                        onChanged: (v) => setModalState(() {
                          recurring = v;
                        }),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: dueDate,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 3650)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (pickedDate == null) return;
                          if (!context.mounted) return;
                          setModalState(() => dueDate = dateOnly(pickedDate));
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText:
                                recurring ? 'Due Date Anchor' : 'Due Date',
                            hintText: 'Select a date',
                          ),
                          child: Text(
                            formatCalendarDate(dueDate),
                            style: const TextStyle(color: intelliumTextPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        dropdownColor: intelliumCard,
                        style: const TextStyle(color: intelliumTextPrimary),
                        items: const [
                          DropdownMenuItem(
                              value: 'Utilities', child: Text('Utilities')),
                          DropdownMenuItem(
                              value: 'Internet', child: Text('Internet')),
                          DropdownMenuItem(value: 'Loan', child: Text('Loan')),
                          DropdownMenuItem(
                              value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (v) =>
                            setModalState(() => category = v ?? 'Utilities'),
                        decoration:
                            const InputDecoration(labelText: 'Category'),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile.adaptive(
                        value: isPaid,
                        activeThumbColor: intelliumCyan,
                        activeTrackColor: intelliumCyan.withValues(alpha: .35),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Mark as settled',
                          style: TextStyle(
                              color: intelliumTextPrimary,
                              fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          isPaid
                              ? 'A settled date will be saved with this bill.'
                              : 'Leave this off to keep the bill unpaid.',
                          style: const TextStyle(
                              color: intelliumTextMuted, fontSize: 12.5),
                        ),
                        onChanged: (value) => setModalState(() {
                          isPaid = value;
                          if (isPaid) {
                            paidDate = dateOnly(DateTime.now());
                          } else {
                            paidDate = null;
                          }
                        }),
                      ),
                      if (isPaid) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: paidDate ?? dateOnly(DateTime.now()),
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 3650)),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 3650)),
                            );
                            if (pickedDate == null) return;
                            if (!context.mounted) return;
                            setModalState(
                                () => paidDate = dateOnly(pickedDate));
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Settled Date',
                              hintText: 'Select a date',
                            ),
                            child: Text(
                              formatCalendarDate(
                                  paidDate ?? dateOnly(DateTime.now())),
                              style:
                                  const TextStyle(color: intelliumTextPrimary),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      PrimaryButton(
                        label:
                            isEditing ? 'Save Changes' : 'Save Upcoming Bill',
                        onPressed: () async {
                          if (saving) return;
                          final titleValue = title.text.trim();
                          final amountText = amount.text.trim();
                          final amountError = validatePesoAmountInput(
                            amountText,
                            fieldLabel: 'amount',
                          );

                          if (titleValue.isEmpty) {
                            showAppMessage(context, 'Enter a bill title');
                            return;
                          }
                          if (amountError != null) {
                            showAppMessage(context, amountError);
                            return;
                          }
                          final amountValue = parseMoneyInput(amountText)!;
                          setModalState(() => saving = true);
                          final preservedHistoricalRecurringSettlement =
                              existingBill != null &&
                                  existingBill.isRecurring &&
                                  !wasSettledForCurrentCycle &&
                                  !isPaid &&
                                  recurring;
                          final updatedBill = (existingBill ??
                                  BillItem(
                                    id: DateTime.now()
                                        .microsecondsSinceEpoch
                                        .toString(),
                                    title: '',
                                    amount: 0,
                                    dueDate: dateOnly(DateTime.now()),
                                    paidDate: null,
                                    settledCycleKey: null,
                                    category: 'Utilities',
                                    isRecurring: true,
                                    isPaid: false,
                                  ))
                              .copyWith(
                            title: titleValue,
                            amount: amountValue,
                            dueDate: dueDate,
                            paidDate: isPaid
                                ? (paidDate ?? dateOnly(DateTime.now()))
                                : preservedHistoricalRecurringSettlement
                                    ? existingBill.paidDate
                                    : null,
                            settledCycleKey: recurring && isPaid
                                ? billCycleKey(paidDate ?? DateTime.now())
                                : preservedHistoricalRecurringSettlement
                                    ? existingBill.settledCycleKey
                                    : null,
                            category: category,
                            isRecurring: recurring,
                            isPaid: isPaid ||
                                (preservedHistoricalRecurringSettlement &&
                                    existingBill.isPaid),
                          );
                          if (isEditing) {
                            bills[editIndex!] = updatedBill;
                          } else {
                            bills.insert(0, updatedBill);
                          }
                          await save();
                          if (!context.mounted || !mounted) return;
                          Navigator.pop(context);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      title.dispose();
      amount.dispose();
    });
  }

  Color billColor(String category) {
    switch (category) {
      case 'Internet':
        return const Color(0xFF6C8CFF);
      case 'Loan':
        return const Color(0xFFFF6B6B);
      case 'Utilities':
        return const Color(0xFFFFC857);
      default:
        return const Color(0xFF00C896);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalBills = bills.fold<double>(0, (sum, e) => sum + e.amount);
    final unpaidBills = bills
        .where((e) => billHasOutstandingBalance(e))
        .fold<double>(0, (sum, e) => sum + e.amount);
    final paidCount =
        bills.where((e) => isBillSettledForCurrentCycle(e)).length;
    final progress = bills.isEmpty ? 0 : paidCount / bills.length;

    return Scaffold(
      backgroundColor: intelliumBackground,
      appBar: AppBar(
        backgroundColor: intelliumBackground,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        toolbarHeight: 72,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upcoming Bills',
              style: TextStyle(
                  color: intelliumTextPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text(
              'Track due dates, upcoming bills, and settled bills',
              style: TextStyle(
                  color: intelliumTextMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddBillSheet,
        backgroundColor: intelliumCyan,
        foregroundColor: intelliumBackground,
        icon: const Icon(Icons.add),
        label: const Text('Add Upcoming Bill',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: loading
          ? buildPageLoadingState('Loading your bills...')
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeroCard(
                    colors: const [
                      Color(0xFF2C2A58),
                      intelliumPurple,
                      intelliumBlue
                    ],
                    title: 'Upcoming Bills',
                    value: '${formatPhp(unpaidBills)} unpaid',
                    badge: '$paidCount of ${bills.length} marked as paid',
                    progress: progress.toDouble(),
                    progressColor: intelliumCyan,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: HomeOverviewCard(
                          title: 'All Bills',
                          value: formatPhp(totalBills),
                          subtitle: 'All saved bill entries',
                          color: intelliumPurple,
                          icon: Icons.receipt_long_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: HomeOverviewCard(
                          title: 'Upcoming Bills',
                          value: formatPhp(unpaidBills),
                          subtitle: 'Still unpaid',
                          color: intelliumPink,
                          icon: Icons.warning_amber_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  const HomeSectionHeader(
                    title: 'Bill List',
                    subtitle: 'Saved due dates and settlement status',
                  ),
                  const SizedBox(height: 14),
                  if (bills.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: intelliumSurface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .05)),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _HomeEmptyIcon(
                            icon: Icons.calendar_month_rounded,
                            color: intelliumPink,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No upcoming bills yet',
                            style: TextStyle(
                                color: intelliumTextPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Add your first bill to track due dates, payment status, and Anticipated Balance.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: intelliumTextSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    )
                  else
                    ...List.generate(bills.length, (index) {
                      final bill = bills[index];
                      final isSettled = isBillSettledForCurrentCycle(bill);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: intelliumSurface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: .05)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 48,
                                width: 48,
                                decoration: BoxDecoration(
                                  color: (isSettled
                                          ? intelliumCyan
                                          : billColor(bill.category))
                                      .withValues(alpha: .16),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  isSettled
                                      ? Icons.check_circle_rounded
                                      : Icons.calendar_month_rounded,
                                  color: isSettled
                                      ? intelliumCyan
                                      : billColor(bill.category),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bill.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: intelliumTextPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${bill.category} | Due: ${formatCalendarDate(resolveUpcomingBillDate(bill) ?? bill.dueDate)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: intelliumTextMuted,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      bill.paidDate != null
                                          ? isSettled
                                              ? '${bill.isRecurring ? 'Recurring bill' : 'One-time bill'} | Settled: ${formatCalendarDate(bill.paidDate!)}'
                                              : '${bill.isRecurring ? 'Recurring bill' : 'One-time bill'} | Last settled: ${formatCalendarDate(bill.paidDate!)}'
                                          : (bill.isRecurring
                                              ? 'Recurring bill'
                                              : 'One-time bill'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isSettled
                                            ? intelliumCyan
                                            : intelliumPurple,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 96),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        formatPhp(bill.amount),
                                        style: const TextStyle(
                                            color: intelliumTextPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(
                                            minWidth: 36, minHeight: 36),
                                        padding: EdgeInsets.zero,
                                        onPressed: () =>
                                            showAddBillSheet(editIndex: index),
                                        icon: const Icon(Icons.edit_outlined),
                                        color: intelliumTextMuted,
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(
                                            minWidth: 36, minHeight: 36),
                                        padding: EdgeInsets.zero,
                                        onPressed: () => togglePaid(index),
                                        icon: Icon(
                                          isSettled
                                              ? Icons.check_circle_rounded
                                              : Icons
                                                  .radio_button_unchecked_rounded,
                                        ),
                                        color: isSettled
                                            ? intelliumCyan
                                            : intelliumTextMuted,
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(
                                            minWidth: 36, minHeight: 36),
                                        padding: EdgeInsets.zero,
                                        onPressed: () => deleteBill(index),
                                        icon: const Icon(
                                            Icons.delete_outline_rounded),
                                        color: intelliumTextMuted,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class ClickableCard extends StatelessWidget {
  final BoxDecoration decoration;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Widget child;
  final VoidCallback? onTap;
  final double? width;

  const ClickableCard({
    super.key,
    required this.decoration,
    required this.borderRadius,
    required this.padding,
    required this.child,
    this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: width,
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(borderRadius: borderRadius),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class SalaryOverviewScreen extends StatelessWidget {
  const SalaryOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderDetailScreen(
      title: 'Available Balance',
      description: 'Available balance details are not available yet.',
      icon: Icons.account_balance_wallet_rounded,
    );
  }
}

class SalaryScreen extends StatelessWidget {
  const SalaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderDetailScreen(
      title: 'Opening Balance',
      description: 'Opening balance details are not available yet.',
      icon: Icons.payments_rounded,
    );
  }
}

class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BillsTrackerScreen();
  }
}

class DailyBudgetScreen extends StatelessWidget {
  const DailyBudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderDetailScreen(
      title: 'Daily Spending Limit',
      description: 'Daily spending limit details are not available yet.',
      icon: Icons.today_rounded,
    );
  }
}

class SalaryAfterBillsScreen extends StatelessWidget {
  const SalaryAfterBillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderDetailScreen(
      title: 'Income',
      description: 'Income entry details are not available yet.',
      icon: Icons.account_balance_wallet_rounded,
    );
  }
}

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExpenseTrackerScreen();
  }
}

class AddBillScreen extends StatefulWidget {
  const AddBillScreen({super.key});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    super.dispose();
  }

  void _save() {
    if (saving) return;
    final nameValue = nameController.text.trim();
    final amountText = amountController.text.trim();
    final amountError = validatePesoAmountInput(
      amountText,
      fieldLabel: 'amount',
    );

    if (nameValue.isEmpty) {
      showAppMessage(context, 'Enter a deduction title');
      return;
    }
    if (amountError != null) {
      showAppMessage(context, amountError);
      return;
    }
    final amountValue = parseMoneyInput(amountText)!;
    setState(() => saving = true);

    Navigator.pop(
      context,
      FixedExpenseItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: nameValue,
        amount: amountValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: intelliumBackground,
      appBar: AppBar(
        backgroundColor: intelliumBackground,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Add Fixed Deduction',
          style: TextStyle(
              color: intelliumTextPrimary, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Fixed Deduction',
                style: TextStyle(
                  color: intelliumTextPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: nameController,
                style: const TextStyle(color: intelliumTextPrimary),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'Deduction Title', hintText: 'Ex. Insurance'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                style: const TextStyle(color: intelliumTextPrimary),
                decoration: const InputDecoration(
                    labelText: 'Amount', hintText: 'Ex. 750.00'),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Save Deduction',
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderDetailScreen extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _PlaceholderDetailScreen({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: intelliumBackground,
      appBar: AppBar(
        backgroundColor: intelliumBackground,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: const TextStyle(
              color: intelliumTextPrimary, fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: intelliumSurface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, color: intelliumCyan, size: 34),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: intelliumTextPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: intelliumTextMuted,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HeroCard extends StatelessWidget {
  final List<Color> colors;
  final String title;
  final String value;
  final String badge;
  final double? progress;
  final Color? progressColor;
  final VoidCallback? onTap;

  const HeroCard({
    super.key,
    required this.colors,
    required this.title,
    required this.value,
    required this.badge,
    this.progress,
    this.progressColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final borderRadius = BorderRadius.circular(28);
    return ClickableCard(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      borderRadius: borderRadius,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: ui.isJade
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF143A2C),
                  Color(0xFF0D241B),
                  Color(0xFF07120E)
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
        border: ui.isJade ? Border.all(color: const Color(0x552EE6A6)) : null,
        boxShadow: ui.isJade
            ? [
                const BoxShadow(
                  color: Color(0x552EE6A6),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: ui.isJade ? ui.textSecondary : Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: ui.isJade ? .08 : .14),
              borderRadius: BorderRadius.circular(14),
              border:
                  ui.isJade ? Border.all(color: const Color(0x442EE6A6)) : null,
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: ui.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: .12),
                valueColor: AlwaysStoppedAnimation<Color>(
                    progressColor ?? const Color(0xFF00C896)),
              ),
            ),
          ]
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Shared widgets
// -----------------------------------------------------------------------------

class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    final borderRadius = BorderRadius.circular(24);
    return ClickableCard(
      padding: const EdgeInsets.all(18),
      borderRadius: borderRadius,
      decoration: ui.cardDecoration(radius: 24),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: ui.iconChipBackground(color),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(color: ui.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: ui.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const PrimaryButton(
      {super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    return Center(
      child: Container(
        width: 48,
        height: 5,
        decoration: BoxDecoration(
          color: ui.isJade ? const Color(0x552EE6A6) : Colors.white24,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final ui = SweldoVisualStyle.fromContext(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: ui.cardDecoration(radius: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: ui.iconChipBackground(
                Theme.of(context).colorScheme.primary,
                radius: 18),
            child: Icon(icon,
                color: Theme.of(context).colorScheme.primary, size: 28),
          ),
          const SizedBox(height: 14),
          Text(title,
              style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: ui.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
