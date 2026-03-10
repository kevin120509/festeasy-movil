import 'package:festeasy/app/view/provider_solicitud_detail_page.dart';
import 'package:festeasy/services/auth_service.dart';
import 'package:festeasy/services/provider_solicitudes_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Set global para persistir leídos temporalmente en la sesión activa
final Set<String> globalLeidasTemp = {};

class _NotificationModel {
  final String id;
  final String titulo;
  final String descripcion;
  final DateTime fecha;
  final String estado;
  final ProviderSolicitudData solicitud;
  bool leida;

  _NotificationModel({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.fecha,
    required this.estado,
    required this.solicitud,
    this.leida = false,
  });
}

class ProviderNotificationsPage extends StatefulWidget {
  const ProviderNotificationsPage({super.key});

  @override
  State<ProviderNotificationsPage> createState() =>
      _ProviderNotificationsPageState();
}

class _ProviderNotificationsPageState extends State<ProviderNotificationsPage> {
  bool _isLoading = true;
  List<_NotificationModel> _notificaciones = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user != null) {
        final solicitudes = await ProviderSolicitudesService.instance
            .getAllSolicitudes(user.id);

        final List<_NotificationModel> notifs = [];
        for (var s in solicitudes) {
          // Generar una notificacion basada en el estado actual de la solicitud
          String titulo = 'Actualización de solicitud';
          String descripcion =
              'El evento ${s.tituloEvento ?? 'sin título'} tiene una actualización.';

          switch (s.estado) {
            case 'pendiente_aprobacion':
              titulo = 'Nueva solicitud recibida';
              final time = DateFormat('HH:mm').format(s.fechaServicio);
              descripcion =
                  'Has recibido una nueva solicitud para el evento: ${s.tituloEvento ?? 'sin título'} ($time).';
              break;
            case 'esperando_anticipo':
              titulo = 'Solicitud aprobada';
              descripcion =
                  'La solicitud para ${s.tituloEvento ?? 'sin título'} fue aprobada. Esperando anticipo.';
              break;
            case 'reservado':
              titulo = 'Evento reservado';
              descripcion =
                  'Se ha confirmado el anticipo para el evento: ${s.tituloEvento ?? 'sin título'}.';
              break;
            case 'rechazada':
              titulo = 'Solicitud rechazada';
              descripcion =
                  'Has rechazado la solicitud para el evento: ${s.tituloEvento ?? 'sin título'}.';
              break;
            case 'cancelada':
              titulo = 'Evento cancelado';
              descripcion =
                  'El evento ${s.tituloEvento ?? 'sin título'} ha sido cancelado.';
              break;
          }

          notifs.add(
            _NotificationModel(
              id: s.id,
              titulo: titulo,
              descripcion: descripcion,
              fecha: s.actualizadoEn,
              estado: s.estado,
              solicitud: s,
              leida: globalLeidasTemp.contains(s.id),
            ),
          );
        }

        // Ordenar por fecha descendente
        notifs.sort((a, b) => b.fecha.compareTo(a.fecha));

        if (mounted) {
          setState(() {
            _notificaciones = notifs;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _marcarTodasComoLeidas() {
    setState(() {
      for (var n in _notificaciones) {
        n.leida = true;
        globalLeidasTemp.add(n.id);
      }
    });
  }

  void _marcarComoLeida(_NotificationModel notif) {
    setState(() {
      notif.leida = true;
      globalLeidasTemp.add(notif.id);
    });
  }

  String _timeAgo(DateTime date) {
    final now = DateTime.now().toUtc();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} d';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} h';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} m';
    } else {
      return 'Ahora mismo';
    }
  }

  IconData _getIconForEstado(String estado) {
    switch (estado) {
      case 'pendiente_aprobacion':
        return Icons.move_to_inbox;
      case 'esperando_anticipo':
        return Icons.check_circle_outline;
      case 'reservado':
        return Icons.event_available;
      case 'cancelada':
      case 'rechazada':
        return Icons.cancel_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  Color _getColorForEstado(String estado) {
    switch (estado) {
      case 'pendiente_aprobacion':
        return const Color(0xFFE01D25); // Rojo principal
      case 'esperando_anticipo':
      case 'reservado':
        return Colors.blue;
      case 'cancelada':
      case 'rechazada':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F9),
        elevation: 0,
        foregroundColor: const Color(0xFF2C3E50),
        title: const Text(''), // Dejamos el título para el body
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE01D25)),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Notificaciones 🔔',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Mantente al día con tu actividad',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: _marcarTodasComoLeidas,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            backgroundColor: Colors.white,
                          ),
                          child: const Text(
                            'Marcar todas como leídas',
                            style: TextStyle(
                              color: Color(0xFF2C3E50),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    if (_notificaciones.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Column(
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No tienes notificaciones',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _notificaciones.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final notif = _notificaciones[index];
                          return _buildNotificationCard(notif);
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildNotificationCard(_NotificationModel notif) {
    final estadoColor = _getColorForEstado(notif.estado);

    return InkWell(
      onTap: () {
        _marcarComoLeida(notif);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProviderSolicitudDetailPage(
              solicitud: notif.solicitud,
              onStatusChanged: _loadNotifications,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Borde de acento izquierdo
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: estadoColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icono circular
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F7F9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIconForEstado(notif.estado),
                          color: estadoColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Textos (Título y Descripción)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif.titulo,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              notif.descripcion,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Acciones (Fecha y botón More)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Text(
                                _timeAgo(notif.fecha),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert,
                                    size: 16,
                                    color: Colors.grey[400],
                                  ),
                                  padding: EdgeInsets.zero,
                                  onSelected: (value) {
                                    if (value == 'leida') {
                                      _marcarComoLeida(notif);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'leida',
                                      child: Text('Marcar como leída'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (!notif.leida)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE01D25),
                                shape: BoxShape.circle,
                              ),
                            )
                          else
                            const SizedBox(width: 8, height: 8),
                        ],
                      ),
                    ],
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
