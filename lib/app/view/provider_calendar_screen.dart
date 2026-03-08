import 'package:festeasy/services/auth_service.dart';
import 'package:festeasy/services/provider_solicitudes_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class ProviderCalendarScreen extends StatefulWidget {
  const ProviderCalendarScreen({super.key});

  @override
  State<ProviderCalendarScreen> createState() => _ProviderCalendarScreenState();
}

class _ProviderCalendarScreenState extends State<ProviderCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;
  List<ProviderSolicitudData> _allEventos = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    initializeDateFormatting('es', null).then((_) {
      _loadEventos();
    });
  }

  Future<void> _loadEventos() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user != null) {
        final eventos = await ProviderSolicitudesService.instance
            .getAllSolicitudes(user.id);
        if (mounted) {
          setState(() {
            // Filtrar eventos rechazados si es necesario. Por ahora mostramos los que no están rechazados
            _allEventos = eventos.where((e) => !e.isRechazada).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading eventos: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<ProviderSolicitudData> _getEventsForDay(DateTime day) {
    return _allEventos.where((evento) {
      return isSameDay(evento.fechaServicio, day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE01D25)),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width > 800;
    final eventsForSelectedDay = _getEventsForDay(_selectedDay ?? _focusedDay);
    final dateFormatter = DateFormat('EEEE, d \'de\' MMMM \'de\' yyyy', 'es');

    Widget calendarCard = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: TableCalendar<ProviderSolicitudData>(
        locale: 'es_ES',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          if (!isSameDay(_selectedDay, selectedDay)) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          }
        },
        eventLoader: _getEventsForDay,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(
            color: Color(0xFFE01D25),
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: const Color(0xFFE01D25).withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          markerDecoration: const BoxDecoration(
            color: Color(0xFF2C3E50),
            shape: BoxShape.circle,
          ),
          weekendTextStyle: const TextStyle(color: Color(0xFFE01D25)),
        ),
      ),
    );

    Widget eventsSection = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      // Si estamos en un Layout horizontal, usamos expanded, si en column ocupa la altura necesaria
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Eventos del Día',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedDay != null ? dateFormatter.format(_selectedDay!) : '',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 32),
          if (eventsForSelectedDay.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.calendar_today,
                      color: Colors.grey.shade400,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sin eventos programados',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Selecciona otra fecha o gestiona tus bloqueos.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black38,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: eventsForSelectedDay.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final evento = eventsForSelectedDay[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              evento.tituloEvento ?? 'Evento sin título',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getColorForEstado(evento.estado).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _formatearEstado(evento.estado),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getColorForEstado(evento.estado),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            evento.clienteNombre ?? 'Cliente',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('HH:mm').format(evento.fechaServicio),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mi Calendario',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gestión centralizada de eventos y disponibilidad.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: calendarCard),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: eventsSection),
              ],
            )
          else
            Column(
              children: [
                calendarCard,
                const SizedBox(height: 24),
                eventsSection,
              ],
            ),
        ],
      ),
    );
  }

  Color _getColorForEstado(String estado) {
    switch (estado) {
      case 'pendiente_aprobacion':
        return Colors.orange;
      case 'esperando_anticipo':
        return Colors.amber;
      case 'reservado':
        return Colors.blue;
      case 'en_progreso':
        return Colors.purple;
      case 'entregado_pendiente_liq':
        return Colors.teal;
      case 'finalizado':
        return Colors.green;
      case 'rechazada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatearEstado(String estado) {
    switch (estado) {
      case 'pendiente_aprobacion':
        return 'Pendiente';
      case 'esperando_anticipo':
        return 'Esperando Anticipo';
      case 'reservado':
        return 'Reservado';
      case 'en_progreso':
        return 'En Progreso';
      case 'entregado_pendiente_liq':
        return 'Entregado';
      case 'finalizado':
        return 'Finalizado';
      case 'rechazada':
        return 'Rechazado';
      default:
        return estado;
    }
  }
}
