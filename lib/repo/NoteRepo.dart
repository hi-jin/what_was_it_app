import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:what_was_it_app/core/notification_plugin.dart';
import 'package:what_was_it_app/core/shared_preferences.dart';
import 'package:what_was_it_app/model/note.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NoteRepo extends StateNotifier<List<Note>> {
  NoteRepo(List<Note> list) : super(list);

  void saveNote(Note note) async {
    state = [note, ...state];

    int notificationId = _getNextNotificationId();

    for (tz.TZDateTime scheduledDate in _getNoteAlarmDate(note)) {
      // TODO map 동작 안하는데 왜 그런지 알아보기
      await _addNotification(scheduledDate, note, notificationId++);
    }

    await _setNextNotificationId(notificationId);

    prefs.setString('notes', jsonEncode(state));
  }

  void removeNote(int index) {
    _removeNotification(state.elementAt(index));

    state.removeAt(index);
    state = [...state];

    prefs.setString('notes', jsonEncode(state));
  }

  Future _removeNotification(Note note) async {
    if (note.notificationId != null && note.notificationId!.isNotEmpty) {
      note.notificationId!.map((e) async => await flutterLocalNotificationsPlugin.cancel(e));

      for (tz.TZDateTime scheduledDate in _getNoteAlarmDate(note)) {
        print("$scheduledDate에 알람이 삭제되었습니다."); // Test
      }
    }
  }

  List<tz.TZDateTime> _getNoteAlarmDate(Note note) {
    List<tz.TZDateTime> result = [];

    for (DateTime alarmDate in note.scheduleDates) {
      // TODO 알람 시각 유저가 정하도록
      final scheduledDate = tz.TZDateTime(tz.local, alarmDate.year, alarmDate.month, alarmDate.day, 9);
      result.add(scheduledDate);
    }
    // result = [tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1))]; // Test
    return result;
  }

  Future<void> _addNotification(tz.TZDateTime scheduledDate, Note note, int notificationId) async {
    note.notificationId = [...(note.notificationId ?? []), notificationId];

    DateTimeComponents? match;

    switch (note.repeatType) {
      case RepeatType.none:
        match = null;
        break;
      case RepeatType.daily:
        match = DateTimeComponents.time;
        break;
      case RepeatType.weekly:
        match = DateTimeComponents.dayOfWeekAndTime;
        break;
      case RepeatType.monthly:
        match = DateTimeComponents.dayOfMonthAndTime;
        break;
      case RepeatType.yearly:
        match = DateTimeComponents.dateAndTime;
        break;
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      "${note.title} 기억 나시나요?",
      note.keywords.reduce((value, element) => "$value, $element"),
      scheduledDate,
      _getNotificationDetails(),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidAllowWhileIdle: true,
      matchDateTimeComponents: match,
    );

    print("$scheduledDate에 알람이 설정됐습니다."); // Test
  }

  NotificationDetails _getNotificationDetails() {
    IOSNotificationDetails iosNotificationDetails = const IOSNotificationDetails();
    AndroidNotificationDetails androidNotificationDetails = const AndroidNotificationDetails(
      "whatWasIt",
      "what was it app",
      importance: Importance.max,
      priority: Priority.high,
    );
    return NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );
  }

  int _getNextNotificationId() {
    return prefs.getInt("notificationId") ?? 0;
  }

  Future<void> _setNextNotificationId(int id) async {
    await prefs.setInt("notificationId", id);
  }
}