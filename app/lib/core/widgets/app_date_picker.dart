import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import '../../features/calendar/domain/calendar_month.dart';

/// アプリの日付の選択（F-VW-04）。週の始まりを、アプリの設定に合わせる
///
/// なぜ：Flutter の showDatePicker は、週の始まりをアプリの言語の決まり
/// （日本語は日曜）から取り、端末やアプリの設定を見ない。そこで、言語の部品
/// （MaterialLocalizations）のうち週の始まりだけを差し替えて渡す。
/// 日付の選択は、どの画面でもこの関数を使う（設定の渡し忘れを防ぐ）
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  // 画面で weekStartProvider を watch して渡す（必須なので渡し忘れはコンパイルで分かる）
  required WeekStart weekStart,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: (context, child) => Localizations.override(
      context: context,
      delegates: [_WeekStartDelegate(weekStart)],
      child: child,
    ),
  );
}

/// 週の始まりだけを差し替えた日本語の言語の部品を返す
class _WeekStartDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _WeekStartDelegate(this.weekStart);

  final WeekStart weekStart;

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ja';

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    // 書式は flutter_localizations と同じ作り方（GlobalMaterialLocalizations.delegate）
    const name = 'ja';
    return WeekStartMaterialLocalizationsJa(
      weekStart: weekStart,
      fullYearFormat: intl.DateFormat.y(name),
      compactDateFormat: intl.DateFormat.yMd(name),
      shortDateFormat: intl.DateFormat.yMMMd(name),
      mediumDateFormat: intl.DateFormat.MMMEd(name),
      longDateFormat: intl.DateFormat.yMMMMEEEEd(name),
      yearMonthFormat: intl.DateFormat.yMMMM(name),
      shortMonthDayFormat: intl.DateFormat.MMMd(name),
      decimalFormat: intl.NumberFormat.decimalPattern(name),
      twoDigitZeroPaddedFormat: intl.NumberFormat('00', name),
    );
  }

  @override
  bool shouldReload(_WeekStartDelegate old) => old.weekStart != weekStart;
}

/// 日本語の言語の部品で、週の始まりだけをアプリの設定にしたもの
class WeekStartMaterialLocalizationsJa extends MaterialLocalizationJa {
  const WeekStartMaterialLocalizationsJa({
    required this.weekStart,
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });

  final WeekStart weekStart;

  /// 0 が日曜、1 が月曜（MaterialLocalizations の決まり）
  @override
  int get firstDayOfWeekIndex => weekStart == WeekStart.monday ? 1 : 0;
}
