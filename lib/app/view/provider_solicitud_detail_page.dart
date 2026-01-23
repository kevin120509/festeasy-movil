import 'package:festeasy/services/provider_solicitudes_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProviderSolicitudDetailPage extends StatefulWidget {

  const ProviderSolicitudDetailPage({
    required this.solicitud, super.key,
    this.onStatusChanged,
  });
  final ProviderSolicitudData solicitud;
  final VoidCallback? onStatusChanged;

  @override
  State<ProviderSolicitudDetailPage> createState() =>
      _ProviderSolicitudDetailPageState();
}

class _ProviderSolicitudDetailPageState
    extends State<ProviderSolicitudDetailPage> {
  bool _isLoading = false;
  late ProviderSolicitudData _solicitud;
  List<Map<String, dynamic>> _items = [];
  String? _clienteNombre;

  @override
  void initState() {
    super.initState();
    _solicitud = widget.solicitud;
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadItems(), _loadClienteNombre()]);
  }

  Future<void> _loadItems() async {
    try {
      final client = Supabase.instance.client;
      final result = await client
          .from('items_solicitud')
          .select('nombre_paquete_snapshot, cantidad, precio_unitario')
          .eq('solicitud_id', _solicitud.id);
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(result);
        });
      }
    } catch (e) {
      debugPrint('Error cargando items: $e');
    }
  }

  Future<void> _loadClienteNombre() async {
    try {
      final client = Supabase.instance.client;
      debugPrint(
        '🔍 Buscando cliente con usuario_id: ${_solicitud.clienteUsuarioId}',
      );

      if (_solicitud.clienteUsuarioId.isEmpty) {
        debugPrint('❌ clienteUsuarioId está vacío');
        return;
      }

      // Intentar buscar por usuario_id
      var result = await client
          .from('perfil_cliente')
          .select('nombre_completo')
          .eq('usuario_id', _solicitud.clienteUsuarioId)
          .maybeSingle();

      // Si no encuentra, intentar buscar por id
      if (result == null) {
        debugPrint('🔍 No encontrado por usuario_id, intentando por id...');
        result = await client
            .from('perfil_cliente')
            .select('nombre_completo')
            .eq('id', _solicitud.clienteUsuarioId)
            .maybeSingle();
      }

      if (mounted && result != null) {
        debugPrint('✅ Cliente encontrado: ${result['nombre_completo']}');
        setState(() {
          _clienteNombre = result!['nombre_completo'] as String?;
        });
      } else {
        debugPrint('❌ No se encontró perfil de cliente');
      }
    } catch (e) {
      debugPrint('❌ Error cargando nombre del cliente: $e');
    }
  }

  Future<void> _aceptarSolicitud() async {
    setState(() => _isLoading = true);

    try {
      final updated = await ProviderSolicitudesService.instance
          .aceptarSolicitud(_solicitud.id);

      if (mounted) {
        setState(() => _solicitud = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Solicitud aceptada! Esperando pago del cliente'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onStatusChanged?.call();

        // Volver a la pantalla anterior después de 1 segundo
        await Future<void>.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rechazarSolicitud() async {
    // Mostrar diálogo con opciones de motivo
    final motivo = await _showMotiveDialog();
    if (motivo == null) return;

    setState(() => _isLoading = true);

    try {
      final updated = await ProviderSolicitudesService.instance
          .rechazarSolicitud(solicitudId: _solicitud.id, motivo: motivo);

      if (mounted) {
        setState(() => _solicitud = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud rechazada'),
            backgroundColor: Colors.orange,
          ),
        );
        widget.onStatusChanged?.call();

        // Volver a la pantalla anterior después de 1 segundo
        await Future<void>.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _showMotiveDialog() async {
    const motivos = [
      'Fecha no disponible',
      'Ubicación fuera de cobertura',
      'Presupuesto insuficiente',
      'No disponibilidad de equipo',
      'Otro',
    ];

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Motivo del rechazo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: motivos
              .map(
                (motivo) => ListTile(
                  title: Text(motivo),
                  onTap: () => Navigator.pop(context, motivo),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy hh:mm');
    final isPendiente = _solicitud.isPendiente;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitud'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Número y estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Solicitud #${_solicitud.numeroSolicitud}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(
                    _getEstadoLabel(_solicitud.estado),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: _getEstadoColor(_solicitud.estado),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // INFORMACIÓN DEL CLIENTE
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFFFE5E7),
                      child: Icon(Icons.person, color: Color(0xFFE01D25)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _clienteNombre ?? _solicitud.clienteNombre ?? 'Cliente',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // DETALLES DEL EVENTO
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalles del Evento',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_solicitud.tituloEvento != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tipo de evento:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            _solicitud.tituloEvento!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    Text(
                      'Fecha y hora:',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      formatter.format(_solicitud.fechaServicio),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ubicación:',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      _solicitud.direccionServicio,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (_solicitud.latitudServicio != null &&
                        _solicitud.longitudServicio != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '📍 ${_solicitud.latitudServicio!.toStringAsFixed(4)}, ${_solicitud.longitudServicio!.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                    // Paquetes solicitados
                    if (_items.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        'Paquetes solicitados:',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      ..._items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item['cantidad']}x ${item['nombre_paquete_snapshot'] ?? 'Paquete'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                '\$${((item['precio_unitario'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // MONTOS
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Montos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Monto Total:',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        Text(
                          '\$${_solicitud.montoTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Anticipo (50%):',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        Text(
                          '\$${_solicitud.montoAnticipo.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Liquidación (50%):',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        Text(
                          '\$${_solicitud.montoLiquidacion.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.amber[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ACCIONES
            if (isPendiente)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _aceptarSolicitud,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Aceptar Solicitud'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _rechazarSolicitud,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Rechazar Solicitud'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Esta solicitud ya fue ${_solicitud.isRechazada
                        ? 'rechazada'
                        : _solicitud.espeandoAnticipo
                        ? 'aceptada'
                        : 'procesada'}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
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
