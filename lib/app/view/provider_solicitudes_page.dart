import 'package:festeasy/app/view/provider_solicitud_detail_page.dart';
import 'package:festeasy/services/auth_service.dart';
import 'package:festeasy/services/provider_solicitudes_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProviderSolicitudesPage extends StatefulWidget {

  const ProviderSolicitudesPage({super.key, this.onSolicitudUpdated});
  final VoidCallback? onSolicitudUpdated;

  @override
  State<ProviderSolicitudesPage> createState() =>
      _ProviderSolicitudesPageState();
}

class _ProviderSolicitudesPageState extends State<ProviderSolicitudesPage> {
  late Future<List<ProviderSolicitudData>> _solicitudesFuture;
  String _filterEstado =
      'todas'; // 'todas', 'pendiente', 'rechazada', 'reservado'

  @override
  void initState() {
    super.initState();
    _loadSolicitudes();
  }

  void _loadSolicitudes() {
    final user = AuthService.instance.currentUser;
    debugPrint('🔍 [ProviderSolicitudes] currentUser: ${user?.id}');

    if (user != null) {
      if (_filterEstado == 'todas') {
        _solicitudesFuture = ProviderSolicitudesService.instance
            .getAllSolicitudes(user.id);
      } else if (_filterEstado == 'pendiente') {
        _solicitudesFuture = ProviderSolicitudesService.instance
            .getSolicitudesByEstado(user.id, 'pendiente_aprobacion');
      } else if (_filterEstado == 'rechazada') {
        _solicitudesFuture = ProviderSolicitudesService.instance
            .getSolicitudesByEstado(user.id, 'rechazada');
      } else if (_filterEstado == 'reservado') {
        _solicitudesFuture = ProviderSolicitudesService.instance
            .getSolicitudesByEstado(user.id, 'reservado');
      }
    } else {
      debugPrint('❌ [ProviderSolicitudes] No user logged in');
    }
  }

  String _getEstadoLabel(String estado) {
    switch (estado) {
      case 'pendiente_aprobacion':
        return 'Pendiente';
      case 'esperando_anticipo':
        return 'Esperando Pago';
      case 'reservado':
        return 'Reservado';
      case 'en_progreso':
        return 'En Progreso';
      case 'entregado_pendiente_liq':
        return 'Pendiente Liquidación';
      case 'finalizado':
        return 'Finalizado';
      case 'rechazada':
        return 'Rechazada';
      case 'cancelada':
        return 'Cancelada';
      default:
        return estado;
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'pendiente_aprobacion':
        return Colors.orange;
      case 'esperando_anticipo':
        return Colors.blue;
      case 'reservado':
        return Colors.green;
      case 'en_progreso':
        return Colors.purple;
      case 'finalizado':
        return Colors.teal;
      case 'rechazada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filtros
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _FilterChip(
                label: 'Todas',
                isSelected: _filterEstado == 'todas',
                onSelected: () {
                  setState(() {
                    _filterEstado = 'todas';
                    _loadSolicitudes();
                  });
                },
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Pendientes',
                isSelected: _filterEstado == 'pendiente',
                onSelected: () {
                  setState(() {
                    _filterEstado = 'pendiente';
                    _loadSolicitudes();
                  });
                },
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Reservadas',
                isSelected: _filterEstado == 'reservado',
                onSelected: () {
                  setState(() {
                    _filterEstado = 'reservado';
                    _loadSolicitudes();
                  });
                },
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Rechazadas',
                isSelected: _filterEstado == 'rechazada',
                onSelected: () {
                  setState(() {
                    _filterEstado = 'rechazada';
                    _loadSolicitudes();
                  });
                },
              ),
            ],
          ),
        ),
        // Listado
        Expanded(
          child: FutureBuilder<List<ProviderSolicitudData>>(
            future: _solicitudesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 12),
                      Text('Error: ${snapshot.error}'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(_loadSolicitudes);
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                );
              }

              final solicitudes = snapshot.data ?? [];

              if (solicitudes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No hay solicitudes',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Las solicitudes de clientes aparecerán aquí',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: solicitudes.length,
                itemBuilder: (context, index) {
                  final solicitud = solicitudes[index];
                  return _SolicitudCard(
                    solicitud: solicitud,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ProviderSolicitudDetailPage(
                            solicitud: solicitud,
                            onStatusChanged: () {
                              setState(_loadSolicitudes);
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.red,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class _SolicitudCard extends StatelessWidget {

  const _SolicitudCard({required this.solicitud, required this.onTap});
  final ProviderSolicitudData solicitud;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy');

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Solicitud #${solicitud.numeroSolicitud}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Chip(
                    label: Text(
                      _getEstadoLabel(solicitud.estado),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: _getEstadoColor(solicitud.estado),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Cliente
              if (solicitud.clienteNombre != null)
                Row(
                  children: [
                    Icon(Icons.person, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      solicitud.clienteNombre!,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Icon(Icons.person, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text('Cliente', style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              const SizedBox(height: 8),
              // Fecha
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    formatter.format(solicitud.fechaServicio),
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Ubicación
              Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      solicitud.direccionServicio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Monto y evento
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (solicitud.tituloEvento != null)
                    Text(
                      solicitud.tituloEvento!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Text(
                    '\$${solicitud.montoTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getEstadoLabel(String estado) {
    switch (estado) {
      case 'pendiente_aprobacion':
        return 'Pendiente';
      case 'esperando_anticipo':
        return 'Esperando Pago';
      case 'reservado':
        return 'Reservado';
      case 'en_progreso':
        return 'En Progreso';
      case 'finalizado':
        return 'Finalizado';
      case 'rechazada':
        return 'Rechazada';
      default:
        return estado;
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'pendiente_aprobacion':
        return Colors.orange;
      case 'esperando_anticipo':
        return Colors.blue;
      case 'reservado':
        return Colors.green;
      case 'en_progreso':
        return Colors.purple;
      case 'finalizado':
        return Colors.teal;
      case 'rechazada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
