String _two(int n) => n.toString().padLeft(2, '0');

/// 時刻を 08:10 の形にする
String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// 日時を 11/02 08:10 の形にする
String formatDateTime(DateTime d) =>
    '${_two(d.month)}/${_two(d.day)} ${formatTime(d)}';

/// 体重を 4.2 kg の形にする（入力したとおりの桁）
String formatWeight(double kg) => '$kg kg';
