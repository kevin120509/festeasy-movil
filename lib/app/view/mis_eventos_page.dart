import 'package:festeasy/app/view/request_status_page.dart';
import 'package:festeasy/services/solicitud_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MisEventosPage extends StatefulWidget {
  const MisEventosPage({super.key});

  @override
  State<MisEventosPage> createState() => _MisEventosPageState();
}

class _MisEventosPageState extends State<MisEventosPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SolicitudData> _solicitudes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSolicitudes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSolicitudes() async {
    setState(() => _isLoading = true);
    try {
      final solicitudes = await SolicitudService.instance
          .getAllSolicitudesForClient();
      if (mounted) {
        setState(() {
          _solicitudes = solicitudes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando solicitudes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Filtrar solicitudes por categoría
  List<SolicitudData> get _activas => _solicitudes.where((s) {
    return s.estado == 'pendiente_aprobacion' ||
        s.estado == 'esperando_anticipo' ||
        s.estado == 'reservado' ||
        s.estado == 'entregado_pendiente_liq' ||
        s.estado == 'en_progreso';
  }).toList();

  List<SolicitudData> get _proximas => _solicitudes.where((s) {
    return s.estado == 'reservado' || 
        s.estado == 'entregado_pendiente_liq' ||
        s.estado == 'en_progreso';
  }).toList();

  List<SolicitudData> get _historial => _solicitudes.where((s) {
    return s.estado == 'finalizado' ||
        s.estado == 'cancelada' ||
        s.estado == 'rechazada' ||
        s.estado == 'abandonada';
  }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Mis Eventos',
          style: TextStyle(
            color: Color(0xFF010302),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFE01D25),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFE01D25),
          tabs: [
            Tab(text: 'Activas (${_activas.length})'),
            Tab(text: 'Próximas (${_proximas.length})'),
            Tab(text: 'Historial (${_historial.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE01D25)),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSolicitudes,
              color: const Color(0xFFE01D25),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSolicitudesList(
                    _activas,
                    emptyMessage: 'No tienes solicitudes activas',
                  ),
                  _buildSolicitudesList(
                    _proximas,
                    emptyMessage: 'No tienes eventos próximos',
                  ),
                  _buildSolicitudesList(
                    _historial,
                    emptyMessage: 'No tienes eventos en historial',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSolicitudesList(
    List<SolicitudData> solicitudes, {
    required String emptyMessage,
  }) {
    if (solicitudes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadSolicitudes,
              child: const Text('Actualizar'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: solicitudes.length,
      itemBuilder: (context, index) {
        final solicitud = solicitudes[index];
        return _buildSolicitudCard(solicitud);
      },
    );
  }

  Widget _buildSolicitudCard(SolicitudData solicitud) {
    final estadoInfo = _getEstadoInfo(solicitud.estado);
    final dateFormat = DateFormat('dd MMM yyyy', 'es');

    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .push(
              MaterialPageRoute<void>(
                builder: (context) =>
                    RequestStatusPage(solicitudId: solicitud.id),
              ),
            )
            .then((_) => _loadSolicitudes()); // Recargar al volver
      },
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: (estadoInfo['color'] as Color).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        estadoInfo['icon'] as IconData,
                        size: 18,
                        color: estadoInfo['color'] as Color,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        estadoInfo['label'] as String,
                        style: TextStyle(
                          color: estadoInfo['color'] as Color,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '#${solicitud.numeroSolicitud}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            // Contenido
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Proveedor
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE5E7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.store,
                          color: Color(0xFFE01D25),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              solicitud.providerName ?? 'Proveedor',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (solicitud.tituloEvento != null)
                              Text(
                                solicitud.tituloEvento!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${solicitud.montoTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFFE01D25),
                            ),
                          ),
                          Text(
                            'MXN',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Detalles
                  Row(
                    children: [
                      _buildDetailChip(
                        Icons.calendar_today,
                        dateFormat.format(solicitud.fechaServicio),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDetailChip(
                          Icons.location_on,
                          solicitud.direccionServicio.isNotEmpty
                              ? solicitud.direccionServicio
                              : 'Sin dirección',
                        ),
                      ),
                    ],
                  ),
                  // PIN de seguridad (solo si está reservado y tiene PIN)
                  if (solicitud.estado == 'reservado' &&
                      solicitud.pinValidacion != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'PIN de entrega: ',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            solicitud.pinValidacion!,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Botón de acción según estado
                  if (solicitud.estado == 'esperando_anticipo') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute<void>(
                                  builder: (context) => RequestStatusPage(
                                    solicitudId: solicitud.id,
                                  ),
                                ),
                              )
                              .then((_) => _loadSolicitudes());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE01D25),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Pagar Anticipo',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                  // Botón de pagar liquidación
                  if (solicitud.estado == 'entregado_pendiente_liq') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute<void>(
                                  builder: (context) => RequestStatusPage(
                                    solicitudId: solicitud.id,
                                  ),
                                ),
                              )
                              .then((_) => _loadSolicitudes());
                        },
                        icon: const Icon(Icons.payment),
                        label: const Text(
                          'Pagar Liquidación',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getEstadoInfo(String estado) {
    switch (estado) {
      case 'pendiente_aprobacion':
        return {
          'label': 'Esperando aprobación',
          'color': Colors.orange,
          'icon': Icons.hourglass_empty,
        };
      case 'esperando_anticipo':
        return {
          'label': 'Esperando anticipo',
          'color': Colors.amber,
          'icon': Icons.payment,
        };
      case 'reservado':
        return {
          'label': 'Reservado',
          'color': Colors.green,
          'icon': Icons.check_circle,
        };
      case 'en_progreso':
        return {
          'label': 'En progreso',
          'color': Colors.blue,
          'icon': Icons.play_circle,
        };
      case 'entregado_pendiente_liq':
        return {
          'label': 'Pendiente liquidación',
          'color': Colors.amber,
          'icon': Icons.delivery_dining,
        };
      case 'finalizado':
        return {
          'label': 'Finalizado',
          'color': Colors.teal,
          'icon': Icons.verified,
        };
      case 'cancelada':
        return {
          'label': 'Cancelada',
          'color': Colors.grey,
          'icon': Icons.cancel,
        };
      case 'rechazada':
        return {'label': 'Rechazada', 'color': Colors.red, 'icon': Icons.block};
      case 'abandonada':
        return {
          'label': 'Abandonada',
          'color': Colors.grey,
          'icon': Icons.timer_off,
        };
      default:
        return {
          'label': estado.replaceAll('_', ' '),
          'color': Colors.grey,
          'icon': Icons.info,
        };
    }
  }
}
