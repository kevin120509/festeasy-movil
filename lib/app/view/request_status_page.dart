import 'dart:async';

import 'package:festeasy/app/view/provider_detail_page_client.dart';
import 'package:festeasy/services/provider_search_service.dart';
import 'package:festeasy/services/solicitud_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RequestStatusPage extends StatefulWidget {

  const RequestStatusPage({required this.solicitudId, super.key});
  final String solicitudId;

  @override
  State<RequestStatusPage> createState() => _RequestStatusPageState();
}

class _RequestStatusPageState extends State<RequestStatusPage> {
  SolicitudData? _solicitud;
  String? _providerName;
  String? _providerPhotoUrl;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _isCancelling = false;
  bool _isDeleting = false;
  bool _isPayingAnticipo = false;

  Timer? _ticker;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _startTicker();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final solicitud = await SolicitudService.instance.getSolicitudById(
        widget.solicitudId,
      );

      if (solicitud != null) {
        // Fallback: el servicio ya intenta resolver el nombre del proveedor.
        final resolvedName = solicitud.providerName;
        if (resolvedName != null && resolvedName.trim().isNotEmpty) {
          _providerName = resolvedName.trim();
        }

        final client = Supabase.instance.client;

        // Cargar items de la solicitud
        try {
          final itemsResult = await client
              .from('items_solicitud')
              .select('nombre_paquete_snapshot, cantidad, precio_unitario')
              .eq('solicitud_id', widget.solicitudId);
          _items = List<Map<String, dynamic>>.from(itemsResult);
        } catch (_) {
          _items = [];
        }

        // Obtener nombre del proveedor desde su perfil
        if (solicitud.proveedorUsuarioId.isNotEmpty) {
          try {
            // Primero intentar buscar por usuario_id
            var perfil = await client
                .from('perfil_proveedor')
                .select('nombre_negocio, avatar_url')
                .eq('usuario_id', solicitud.proveedorUsuarioId)
                .maybeSingle();

            // Si no se encuentra, intentar buscar por id del perfil
            perfil ??= await client
                  .from('perfil_proveedor')
                  .select('nombre_negocio, avatar_url')
                  .eq('id', solicitud.proveedorUsuarioId)
                  .maybeSingle();

            if (perfil != null) {
              final nombre = perfil['nombre_negocio'] as String?;
              if (nombre != null && nombre.trim().isNotEmpty) {
                _providerName = nombre.trim();
              }
              _providerPhotoUrl = perfil['avatar_url'] as String?;
            }
          } catch (_) {
            // ignorar fallos al obtener el perfil
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _solicitud = solicitud;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _subscribeRealtime() {
    final client = Supabase.instance.client;
    final channel = client.channel('solicitud:${widget.solicitudId}');

    _channel = channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'solicitudes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.solicitudId,
          ),
          callback: (_) {
            _load();
          },
        )
        .subscribe();
  }

  Duration _remaining() {
    final solicitud = _solicitud;
    if (solicitud == null) return Duration.zero;

    // Si está cancelada, rechazada o finalizada, mostrar cero
    if (solicitud.estado == 'cancelada' ||
        solicitud.estado == 'rechazada' ||
        solicitud.estado == 'abandonada' ||
        solicitud.estado == 'finalizado') {
      return Duration.zero;
    }

    final nowUtc = DateTime.now().toUtc();

    // Si la solicitud está pendiente de aprobación, cuenta 24h desde creadoEn
    if (solicitud.estado == 'pendiente_aprobacion') {
      final deadline = solicitud.creadoEn.add(const Duration(hours: 24));
      final diff = deadline.difference(nowUtc);
      if (diff.isNegative) return Duration.zero;
      return diff;
    }

    // Si está esperando anticipo, usar expiracion_anticipo
    if (solicitud.estado == 'esperando_anticipo' &&
        solicitud.expiracionAnticipo != null) {
      final diff = solicitud.expiracionAnticipo!.difference(nowUtc);
      if (diff.isNegative) return Duration.zero;
      return diff;
    }

    return Duration.zero;
  }

  String _formatHHMMSS(Duration d) {
    final totalSeconds = d.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(hours)}:${two(minutes)}:${two(seconds)}';
  }

  Future<void> _cancelSolicitud() async {
    if (_isCancelling) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      await SolicitudService.instance.cancelSolicitud(widget.solicitudId);
      if (!mounted) return;
      // Recargar para mostrar el nuevo estado
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cancelar la solicitud.')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isCancelling = false;
      });
    }
  }

  Future<void> _deleteSolicitud() async {
    if (_isDeleting) return;

    // Confirmar eliminación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar solicitud'),
        content: const Text(
          '¿Estás seguro de eliminar esta solicitud? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await SolicitudService.instance.deleteSolicitud(widget.solicitudId);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Solicitud eliminada')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
      });
    }
  }

  Future<void> _payAnticipo() async {
    if (_isPayingAnticipo) return;

    setState(() {
      _isPayingAnticipo = true;
    });

    try {
      // Simular pago del anticipo - actualizar estado a "reservado"
      final anticipoAmount = (_solicitud?.montoTotal ?? 0) * 0.5;
      await SolicitudService.instance.updateSolicitud(widget.solicitudId, {
        'estado': 'reservado',
        'monto_anticipo': anticipoAmount,
      });

      if (!mounted) return;
      await _load();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Anticipo pagado! Tu reserva está confirmada.'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al procesar pago: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isPayingAnticipo = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final solicitud = _solicitud;
    final remaining = _remaining();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF010302)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Estado de Solicitud',
          style: TextStyle(
            color: Color(0xFF010302),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE01D25)),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFFE01D25),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _buildProviderCard(solicitud),
                    const SizedBox(height: 24),
                    // Contador - solo mostrar si NO está reservado
                    if (solicitud?.estado != 'reservado')
                      Center(
                        child: Column(
                          children: [
                            Text(
                              _formatHHMMSS(remaining),
                              style: const TextStyle(
                                color: Color(0xFFE01D25),
                                fontWeight: FontWeight.w900,
                                fontSize: 56,
                                height: 1,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _TimeLabel('HRS'),
                                SizedBox(width: 40),
                                _TimeLabel('MIN'),
                                SizedBox(width: 40),
                                _TimeLabel('SEC'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              (solicitud?.estado ?? 'pendiente_aprobacion') ==
                                      'pendiente_aprobacion'
                                  ? 'Esperando respuesta del proveedor...\nTienes 24 horas disponibles para pagar el anticipo una vez que el proveedor acepte tu solicitud'
                                  : 'Estado: ${solicitud?.estado.replaceAll('_', ' ') ?? ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFF010302),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (solicitud?.estado == 'esperando_anticipo')
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'Tienes 24 horas para pagar el anticipo y asegurar tu servicio',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                    // Mostrar solo el estado cuando está reservado
                    if (solicitud?.estado == 'reservado')
                      Center(
                        child: Text(
                          'Estado: reservado',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF010302),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Detalles del evento
                    _buildSectionTitle('Detalles del evento'),
                    const SizedBox(height: 12),
                    _buildInfoCard([
                      _buildInfoRow(
                        Icons.event,
                        'Evento',
                        solicitud?.tituloEvento ?? 'Sin título',
                      ),
                      _buildInfoRow(
                        Icons.calendar_today,
                        'Fecha',
                        solicitud != null
                            ? DateFormat(
                                'dd/MM/yyyy',
                              ).format(solicitud.fechaServicio)
                            : '-',
                      ),
                      _buildInfoRow(
                        Icons.location_on,
                        'Dirección',
                        solicitud?.direccionServicio.isNotEmpty ?? false
                            ? solicitud!.direccionServicio
                            : 'No especificada',
                      ),
                    ]),
                    const SizedBox(height: 20),
                    // Items solicitados
                    _buildSectionTitle('Servicios solicitados'),
                    const SizedBox(height: 12),
                    if (_items.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'No hay items registrados',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: _items.asMap().entries.map((entry) {
                            final item = entry.value;
                            final nombre =
                                item['nombre_paquete_snapshot'] as String? ??
                                '';
                            final cantidad = item['cantidad'] as int? ?? 0;
                            final precio =
                                (item['precio_unitario'] as num?)?.toDouble() ??
                                0;
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                border: entry.key < _items.length - 1
                                    ? Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFE5E7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'x$cantidad',
                                        style: const TextStyle(
                                          color: Color(0xFFE01D25),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      nombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '\$${(precio * cantidad).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFE01D25),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 20),
                    // Resumen de costos
                    _buildSectionTitle('Resumen'),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final montoTotal = solicitud?.montoTotal ?? 0;
                        final anticipo = (solicitud?.montoAnticipo ?? 0) > 0
                            ? solicitud!.montoAnticipo
                            : montoTotal * 0.5;
                        final liquidacion = (solicitud?.montoLiquidacion ?? 0) > 0
                            ? solicitud!.montoLiquidacion
                            : montoTotal * 0.5;
                        return _buildInfoCard([
                          _buildCostRow('Total', montoTotal),
                          _buildCostRow('Anticipo (50%)', anticipo),
                          _buildCostRow('Liquidación (50%)', liquidacion),
                        ]);
                      },
                    ),
                    const SizedBox(height: 30),
                    // Botón Regresar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE01D25),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'Regresar',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Botón de anticipo
                    if (solicitud?.estado == 'esperando_anticipo')
                      Center(
                        child: ElevatedButton(
                          onPressed: _isPayingAnticipo ? null : _payAnticipo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _isPayingAnticipo
                                ? 'Procesando...'
                                : 'Pagar Anticipo (\$${((_solicitud?.montoTotal ?? 0) * 0.5).toStringAsFixed(2)})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    if (solicitud?.estado == 'reservado')
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '✓ Reserva Confirmada - Anticipo Pagado',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.green,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    // Botón según estado
                    if (solicitud?.estado == 'cancelada')
                      Center(
                        child: TextButton.icon(
                          onPressed: _isDeleting ? null : _deleteSolicitud,
                          icon: _isDeleting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                          label: Text(
                            _isDeleting
                                ? 'Eliminando...'
                                : 'Eliminar solicitud',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                    else if (solicitud?.estado != 'finalizado' &&
                        solicitud?.estado != 'rechazada' &&
                        solicitud?.estado != 'abandonada')
                      Center(
                        child: TextButton(
                          onPressed: _isCancelling ? null : _cancelSolicitud,
                          child: Text(
                            _isCancelling
                                ? 'Cancelando...'
                                : 'Cancelar solicitud',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: Color(0xFF010302),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE01D25), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            '\$${amount.toStringAsFixed(2)} MXN',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(SolicitudData? solicitud) {
    return GestureDetector(
      onTap: () {
        if (solicitud != null && solicitud.proveedorUsuarioId.isNotEmpty) {
          // Crear ProviderSearchResult con los datos disponibles
          final provider = ProviderSearchResult(
            perfilId: '',
            usuarioId: solicitud.proveedorUsuarioId,
            nombreNegocio: _providerName ?? 'Proveedor',
            avatarUrl: _providerPhotoUrl,
          );
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => ProviderDetailPageClient(provider: provider),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      child: Row(
        children: [
          // Foto del proveedor
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE5E7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              image: _providerPhotoUrl != null && _providerPhotoUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(_providerPhotoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _providerPhotoUrl == null || _providerPhotoUrl!.isEmpty
                ? const Icon(Icons.person, color: Color(0xFFE01D25), size: 36)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _providerName ?? 'Proveedor',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF010302),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            color: Color(0xFF4CAF50),
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Verificado',
                            style: TextStyle(
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Punto verde de online
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {

  const _TimeLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.grey,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }
}
