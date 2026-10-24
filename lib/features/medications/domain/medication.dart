enum DoseUnit {
  unit('un'),
  milligram('mg'),
  milliliter('mL');

  const DoseUnit(this.symbol);

  final String symbol;
}

class MedicationDose {
  MedicationDose({required this.amount, required this.unit}) {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be greater than zero.');
    }
  }

  final double amount;
  final DoseUnit unit;
}

class ScheduledTime implements Comparable<ScheduledTime> {
  ScheduledTime({required this.hour, required this.minute}) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(hour, 'hour', 'Must be between 0 and 23.');
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', 'Must be between 0 and 59.');
    }
  }

  final int hour;
  final int minute;

  @override
  int compareTo(ScheduledTime other) {
    final hourComparison = hour.compareTo(other.hour);
    return hourComparison != 0
        ? hourComparison
        : minute.compareTo(other.minute);
  }

  @override
  bool operator ==(Object other) =>
      other is ScheduledTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

class MedicationSchedule {
  MedicationSchedule({
    required Set<int> daysOfWeek,
    required List<ScheduledTime> times,
  }) : daysOfWeek = Set.unmodifiable(daysOfWeek),
       times = List.unmodifiable(times) {
    if (this.daysOfWeek.isEmpty ||
        this.daysOfWeek.any(
          (day) => day < DateTime.monday || day > DateTime.sunday,
        )) {
      throw ArgumentError.value(
        daysOfWeek,
        'daysOfWeek',
        'Must contain weekdays from 1 (Monday) to 7 (Sunday).',
      );
    }
    if (this.times.isEmpty) {
      throw ArgumentError.value(
        times,
        'times',
        'At least one time is required.',
      );
    }
    if (this.times.toSet().length != this.times.length) {
      throw ArgumentError.value(times, 'times', 'Times must be unique.');
    }
  }

  final Set<int> daysOfWeek;
  final List<ScheduledTime> times;

  bool get isEveryDay => daysOfWeek.length == DateTime.daysPerWeek;
}

class Medication {
  Medication({
    required String id,
    required String name,
    required this.dose,
    required List<MedicationSchedule> schedules,
    required this.createdAt,
    this.deactivatedAt,
  }) : id = id.trim(),
       name = name.trim(),
       schedules = List.unmodifiable(schedules) {
    if (this.id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (this.name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty.');
    }
    if (this.schedules.isEmpty) {
      throw ArgumentError.value(
        schedules,
        'schedules',
        'At least one schedule is required.',
      );
    }
    if (deactivatedAt != null && deactivatedAt!.isBefore(createdAt)) {
      throw ArgumentError.value(
        deactivatedAt,
        'deactivatedAt',
        'Must not be before the medication was created.',
      );
    }
  }

  final String id;
  final String name;
  final MedicationDose dose;
  final List<MedicationSchedule> schedules;
  final DateTime createdAt;
  final DateTime? deactivatedAt;

  bool get isActive => deactivatedAt == null;

  Medication deactivate({required DateTime at}) {
    if (!isActive) {
      return this;
    }
    if (at.isBefore(createdAt)) {
      throw ArgumentError.value(at, 'at', 'Must not be before creation.');
    }

    return Medication(
      id: id,
      name: name,
      dose: dose,
      schedules: schedules,
      createdAt: createdAt,
      deactivatedAt: at,
    );
  }
}
