import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/dependencies/dependencies.dart';
import '../../medications/domain/medication.dart';
import '../../medications/domain/medication_intake.dart';
import 'package:flutter/foundation.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({
    super.key,
    required this.refreshSignal,
  });

  final ValueListenable<int> refreshSignal;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  List<_IntakeDisplayItem> _items = [];
  bool _isLoading = true;

  Timer? _clockTimer;
  DateTime? _loadedDay;

  static const Color _background = Color(0xFFF0F9F7);
  static const Color _primary = Color(0xFF008B8B);
  static const Color _text = Color(0xFF102D3A);
  static const Color _secondaryText = Color(0xFF354957);
  static const Color _lateBackground = Color(0xFFFFE5E5);
  static const Color _lateColor = Color(0xFFD32F2F);

  @override
  void initState() {
    super.initState();

    widget.refreshSignal.addListener(_onRefreshSignalChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadTodayIntakes();
      }
    });
  }

  void _onRefreshSignalChanged() {
    if (mounted) {
      _loadTodayIntakes();
    }
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_onRefreshSignalChanged);
    _clockTimer?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime date) {
    final localDate = date.toLocal();

    return '${localDate.hour.toString().padLeft(2, '0')}:'
        '${localDate.minute.toString().padLeft(2, '0')}';
  }

  String _formatAmount(Medication medication) {
    final amount = medication.dose.amount;

    final formattedAmount = amount == amount.roundToDouble()
        ? amount.toInt().toString()
        : amount.toString();

    return '$formattedAmount ${medication.dose.unit.symbol}';
  }

  Future<void> _loadTodayIntakes() async {
    if (!mounted || (_isLoading && _loadedDay != null)) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final deps = Dependencies.of(context);
      final now = DateTime.now();

      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final intakes = await deps.historyRepository.getBetween(
        startInclusive: startOfDay,
        endExclusive: endOfDay,
      );

      final displayItems = <_IntakeDisplayItem>[];

      for (final intake in intakes) {
        if (intake.status != IntakeStatus.pending) continue;

        final medication = await deps.medicationRepository
            .getById(intake.medicationId);

        if (medication != null && medication.isActive) {
          displayItems.add(
            _IntakeDisplayItem(
              intake: intake,
              medication: medication,
            ),
          );
        }
      }

      displayItems.sort(
        (a, b) => a.intake.scheduledAt.compareTo(
          b.intake.scheduledAt,
        ),
      );

      if (!mounted) return;

      setState(() {
        _items = displayItems;
        _isLoading = false;
        _loadedDay = startOfDay;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível carregar as doses: $e'),
        ),
      );
    }
  }

  Future<void> _recordTaken(MedicationIntake intake) async {
    try {
      final deps = Dependencies.of(context);

      await deps.historyRepository.save(
        intake.recordTaken(at: DateTime.now()),
      );

      await _loadTodayIntakes();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível confirmar a dose: $e'),
        ),
      );
    }
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Olá!',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: _text,
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_none,
              color: _primary,
              size: 34,
            ),
            Positioned(
              right: -2,
              top: -3,
              child: Container(
                width: 11,
                height: 11,
                decoration: const BoxDecoration(
                  color: Color(0xFFE53935),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNextMedication(_IntakeDisplayItem item) {
    final medication = item.medication;
    final intake = item.intake;

    final isLate = intake.scheduledAt.isBefore(DateTime.now());

    final cardColor = isLate
        ? _lateBackground
        : Colors.white;

    final buttonColor = isLate
        ? _lateColor
        : _primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF183744).withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Próximo medicamento',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: _text,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isLate
                    ? const Color(0xFFFFBDBD)
                    : const Color(0xFFE5ECEE),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLate) ...[
                  const Text(
                    'Medicamento Atrasado',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _lateColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  _formatTime(intake.scheduledAt),
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  medication.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatAmount(medication),
                  style: const TextStyle(
                    fontSize: 17,
                    color: _secondaryText,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _recordTaken(intake),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'TOMAR AGORA',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingItem(_IntakeDisplayItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF183744).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              _formatTime(item.intake.scheduledAt),
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: _text,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.medication.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatAmount(item.medication),
                  style: const TextStyle(
                    fontSize: 16,
                    color: _secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Você não possui doses pendentes para hoje.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 17,
          color: _secondaryText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextItem = _items.isNotEmpty ? _items.first : null;

    final upcomingItems = _items.length > 1
        ? _items.sublist(1).take(4).toList()
        : <_IntakeDisplayItem>[];

    return Container(
      color: _background,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTodayIntakes,
          color: _primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [
              _buildHeader(),
              const SizedBox(height: 30),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _primary,
                    ),
                  ),
                )
              else if (nextItem == null)
                _buildEmptyState()
              else ...[
                _buildNextMedication(nextItem),
                const SizedBox(height: 28),
                const Text(
                  'Próximos horários',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 16),
                ...upcomingItems.map(_buildUpcomingItem),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IntakeDisplayItem {
  const _IntakeDisplayItem({
    required this.intake,
    required this.medication,
  });

  final MedicationIntake intake;
  final Medication medication;
}
