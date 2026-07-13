import '../repositories/notification_settings_repository.dart';

class NotificationSettingsService {
  final NotificationSettingsRepository repository;

  NotificationSettingsService(this.repository);

  Future<Map<String, dynamic>> getSettingsForUser(int userId) async {
    var settings = await repository.getByUserId(userId);
    if (settings == null) {
      // Create default settings if not exists
      settings = await repository.createDefaultSettings(userId);
      if (settings == null) {
        throw Exception('Could not create default notification settings');
      }
    }
    return settings;
  }

  Future<Map<String, dynamic>> updateStudyReminder(
      int userId, int isEnabled, String time, List<int> days) async {
    // Validate time format HH:mm
    final timeRegex = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');
    if (!timeRegex.hasMatch(time)) {
      throw ArgumentError('Invalid time format. Use HH:mm (e.g. 19:30)');
    }

    // Validate days
    if (days.isEmpty) {
      throw ArgumentError('Days array cannot be empty');
    }
    for (var day in days) {
      if (day < 1 || day > 7) {
        throw ArgumentError('Invalid day: $day. Must be between 1 and 7.');
      }
    }

    // Sort and distinct days (optional but good practice)
    final uniqueDays = days.toSet().toList()..sort();

    final updated = await repository.updateStudyReminder(
        userId, isEnabled, time, uniqueDays);
    
    if (updated == null) {
      // It might be that the user has no settings yet
      await repository.createDefaultSettings(userId);
      final retryUpdate = await repository.updateStudyReminder(
          userId, isEnabled, time, uniqueDays);
      if (retryUpdate == null) {
        throw Exception('Failed to update study reminder settings');
      }
      return retryUpdate;
    }

    return updated;
  }
}
