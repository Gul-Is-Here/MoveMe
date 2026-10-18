const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "15 Oct 2026"
String formatDay(DateTime at) => '${at.day} ${_months[at.month - 1]} ${at.year}';

/// "15 Oct 2026, 3:40 PM"
String formatDayTime(DateTime at) {
  final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final minute = at.minute.toString().padLeft(2, '0');
  return '${formatDay(at)}, $hour:$minute ${at.hour < 12 ? 'AM' : 'PM'}';
}
