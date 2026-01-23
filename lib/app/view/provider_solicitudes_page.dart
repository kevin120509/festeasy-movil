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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filtros
        Container(
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        ),
        // Listado
        Expanded(
          child: FutureBuilder<List<ProviderSolicitudData>>(
            future: _solicitudesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFE01D25),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red[400],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF010302)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(_loadSolicitudes);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE01D25),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final solicitudes = snapshot.data ?? [];

              if (solicitudes.isEmpty) {
                return Center(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F7F9),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            Icons.inbox,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No hay solicitudes',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF010302),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Las solicitudes de clientes aparecerán aquí',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: solicitudes.length,
                itemBuilder: (context, index) {
                  final solicitud = solicitudes[index];
                  return _SolicitudCard(
                    solicitud: solicitud,
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
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
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE01D25) : const Color(0xFFF4F7F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE01D25)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF010302),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE5E7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.request_quote,
                          color: Color(0xFFE01D25),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Solicitud #${solicitud.numeroSolicitud}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF010302),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getEstadoColor(solicitud.estado).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getEstadoLabel(solicitud.estado),
                      style: TextStyle(
                        color: _getEstadoColor(solicitud.estado),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Cliente
              _buildInfoRow(
                icon: Icons.person_outline,
                text: solicitud.clienteNombre ?? 'Cliente',
                iconColor: Colors.grey[600]!,
              ),
              const SizedBox(height: 10),
              // Fecha
              _buildInfoRow(
                icon: Icons.calendar_today_outlined,
                text: formatter.format(solicitud.fechaServicio),
                iconColor: Colors.grey[600]!,
              ),
              const SizedBox(height: 10),
              // Ubicación
              _buildInfoRow(
                icon: Icons.location_on_outlined,
                text: solicitud.direccionServicio,
                iconColor: Colors.grey[600]!,
                maxLines: 1,
              ),
              const SizedBox(height: 16),
              // Monto y evento
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (solicitud.tituloEvento != null)
                      Expanded(
                        child: Text(
                          solicitud.tituloEvento!,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    Text(
                      '\$${solicitud.montoTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Ver detalles',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFFE01D25).withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: const Color(0xFFE01D25).withOpacity(0.8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
    required Color iconColor,
    int maxLines = 2,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
        ),
      ],
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
      case 'entregado_pendiente_liq':
        return 'Pend. Liquidación';
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
      case 'entregado_pendiente_liq':
        return Colors.amber[700]!;
      case 'finalizado':
        return Colors.teal;
      case 'rechazada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
