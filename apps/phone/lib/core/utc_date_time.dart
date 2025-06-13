import 'package:intl/intl.dart';
import 'package:json_annotation/json_annotation.dart';

class UtcDateTime {
  final DateTime _utc;

  UtcDateTime._(this._utc);

  factory UtcDateTime(DateTime dt) {
    if (!dt.isUtc) {
      return UtcDateTime._(dt.toUtc());
    }
    return UtcDateTime._(dt);
  }

  /// ✅ ISO8601 String → UtcDateTime
  factory UtcDateTime.parse(String iso8601String) {
    final parsed = DateTime.parse(iso8601String);
    return UtcDateTime(parsed.toUtc());
  }

  factory UtcDateTime.parseLocal(String localIsoString) {
    final local = DateTime.parse(localIsoString);
    return UtcDateTime(local.toUtc());
  }


  factory UtcDateTime.now() => UtcDateTime._(DateTime.now().toUtc());

  DateTime get value => _utc;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is UtcDateTime && _utc == other._utc);

  @override
  int get hashCode => _utc.hashCode;

  @override
  String toString() => _utc.toIso8601String();

  static UtcDateTime? tryParse(String formattedString) {
    final tParsed = DateTime.tryParse(formattedString);
    return (tParsed == null) ? null : UtcDateTime._(tParsed);
  }
}

extension ForwardedFromDateTime on UtcDateTime {

  // 🧩 DateTime 기본 Getter
  int get year => _utc.year;

  int get month => _utc.month;

  int get day => _utc.day;

  int get hour => _utc.hour;

  int get minute => _utc.minute;

  int get second => _utc.second;

  int get millisecond => _utc.millisecond;

  int get microsecond => _utc.microsecond;

  int get weekday => _utc.weekday;

  int get dayOfYear => int.parse(DateFormat("D").format(_utc)); // intl 필요
  bool get isUtc => true; // 항상 true

  // 🧩 비교 & 연산
  UtcDateTime add(Duration duration) => UtcDateTime(_utc.add(duration));

  UtcDateTime subtract(Duration duration) =>
      UtcDateTime(_utc.subtract(duration));

  Duration difference(UtcDateTime other) => _utc.difference(other._utc);

  bool isBefore(UtcDateTime other) => _utc.isBefore(other._utc);

  bool isAfter(UtcDateTime other) => _utc.isAfter(other._utc);

  bool isAtSameMomentAs(UtcDateTime other) => _utc.isAtSameMomentAs(other._utc);

  int compareTo(UtcDateTime other) => _utc.compareTo(other._utc);

  // 🧩 Epoch & ISO
  int get millisecondsSinceEpoch => _utc.millisecondsSinceEpoch;

  int get microsecondsSinceEpoch => _utc.microsecondsSinceEpoch;

  // 🧩 JSON or display
  String toIso8601String() => _utc.toIso8601String();

  String format([String pattern = 'yyyy-MM-dd HH:mm']) =>
      DateFormat(pattern).format(_utc);

  // 🧩 UTC → DateTime 역변환
  DateTime toDateTime() => _utc;

  UtcDateTime toLocal() => UtcDateTime._(_utc.toLocal());
}

class UtcDateTimeConverter implements JsonConverter<UtcDateTime, String> {
  const UtcDateTimeConverter();

  @override
  UtcDateTime fromJson(String json) => UtcDateTime.parse(json);

  @override
  String toJson(UtcDateTime utcDateTime) => utcDateTime.toIso8601String();
}