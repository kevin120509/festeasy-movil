import 'package:festeasy/services/provider_solicitudes_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProviderSolicitudDetailPage extends StatefulWidget {
  const ProviderSolicitudDetailPage({
    required this.solicitud,
    super.key,
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
      backgroundColor: const Color(0xFFF8FFFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF010302),
        title: const Text(
          'Solicitud',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF010302),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFE01D25)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Número y estado
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Row(
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
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Solicitud #${_solicitud.numeroSolicitud}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF010302),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getEstadoColor(
                        _solicitud.estado,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getEstadoLabel(_solicitud.estado),
                      style: TextStyle(
                        color: _getEstadoColor(_solicitud.estado),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // INFORMACIÓN DEL CLIENTE
            Container(
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
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE5E7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person, color: Color(0xFFE01D25)),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cliente',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _clienteNombre ??
                              _solicitud.clienteNombre ??
                              'Cliente',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color(0xFF010302),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // DETALLES DEL EVENTO
            Container(
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
                    const Text(
                      'Detalles del Evento',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF010302),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_solicitud.tituloEvento != null)
                      _buildDetailRow(
                        icon: Icons.celebration,
                        label: 'Tipo de evento',
                        value: _solicitud.tituloEvento!,
                      ),
                    _buildDetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Fecha y hora',
                      value: formatter.format(_solicitud.fechaServicio),
                    ),
                    _buildDetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Ubicación',
                      value: _solicitud.direccionServicio,
                    ),
                    if (_solicitud.latitudServicio != null &&
                        _solicitud.longitudServicio != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 44, bottom: 8),
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
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F7F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              size: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Paquetes solicitados',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF010302),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._items.map(
                        (item) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F7F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item['cantidad']}x ${item['nombre_paquete_snapshot'] ?? 'Paquete'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Color(0xFF010302),
                                  ),
                                ),
                              ),
                              Text(
                                '\$${((item['precio_unitario'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.green,
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
            Builder(
              builder: (context) {
                // Calcular anticipo y liquidación basados en el monto total
                final montoTotal = _solicitud.montoTotal;
                final anticipo = _solicitud.montoAnticipo > 0
                    ? _solicitud.montoAnticipo
                    : montoTotal * 0.5;
                final liquidacion = _solicitud.montoLiquidacion > 0
                    ? _solicitud.montoLiquidacion
                    : montoTotal * 0.5;

                return Container(
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
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.attach_money,
                                size: 18,
                                color: Colors.green[700],
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Montos',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF010302),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildMontoRow(
                          label: 'Monto Total',
                          value: '\$${montoTotal.toStringAsFixed(2)}',
                          valueColor: Colors.green,
                          isBold: true,
                        ),
                        const SizedBox(height: 10),
                        _buildMontoRow(
                          label: 'Anticipo (50%)',
                          value: '\$${anticipo.toStringAsFixed(2)}',
                          valueColor: Colors.blue[700]!,
                        ),
                        const SizedBox(height: 10),
                        _buildMontoRow(
                          label: 'Liquidación (50%)',
                          value: '\$${liquidacion.toStringAsFixed(2)}',
                          valueColor: Colors.amber[700]!,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // ACCIONES
            if (isPendiente)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _aceptarSolicitud,
                      icon: const Icon(Icons.check_circle),
                      label: const Text(
                        'Aceptar Solicitud',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _rechazarSolicitud,
                      icon: const Icon(Icons.cancel),
                      label: const Text(
                        'Rechazar Solicitud',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            // Botón para validar PIN cuando está reservado
            else if (_solicitud.isReservado)
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Icon(
                            Icons.verified,
                            color: Colors.green,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '¡Reserva Confirmada!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'El cliente ya pagó el anticipo',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _showValidarPinDialog,
                      icon: const Icon(Icons.lock_open),
                      label: const Text(
                        'Validar Entrega con PIN',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE01D25),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Solicita el PIN de 4 dígitos al cliente\npara confirmar la entrega del servicio',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            // Estado entregado pendiente de liquidación
            else if (_solicitud.estado == 'entregado_pendiente_liq')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.hourglass_bottom,
                      color: Colors.amber,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Entrega Validada',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Esperando pago de liquidación del cliente',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            // Estado finalizado
            else if (_solicitud.estado == 'finalizado')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.teal, size: 48),
                    SizedBox(height: 8),
                    Text(
                      '¡Servicio Completado!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'El pago ha sido recibido al 100%',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
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
                        ? 'aceptada - esperando pago'
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

  Future<void> _showValidarPinDialog() async {
    final pinController = TextEditingController();
    var isValidating = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.lock, color: Color(0xFFE01D25)),
              const SizedBox(width: 8),
              Flexible(
                child: const Text(
                  'Validar PIN de Entrega',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Solicita al cliente el PIN de 4 dígitos que aparece en su app o web.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 16,
                ),
                decoration: InputDecoration(
                  hintText: '----',
                  hintStyle: TextStyle(
                    fontSize: 32,
                    color: Colors.grey[300],
                    letterSpacing: 16,
                  ),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFE01D25),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isValidating
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isValidating
                  ? null
                  : () async {
                      if (pinController.text.length != 4) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ingresa un PIN de 4 dígitos'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isValidating = true);

                      try {
                        await ProviderSolicitudesService.instance
                            .validarPinEntrega(
                              solicitudId: _solicitud.id,
                              pinIngresado: pinController.text,
                            );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (e) {
                        setDialogState(() => isValidating = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE01D25),
              ),
              child: isValidating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Validar PIN'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      // Recargar datos de la solicitud
      final updated = await ProviderSolicitudesService.instance
          .getSolicitudById(_solicitud.id);
      if (updated != null && mounted) {
        setState(() => _solicitud = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡PIN validado! Entrega confirmada'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onStatusChanged?.call();
      }
    }
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.grey[600]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF010302),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMontoRow({
    required String label,
    required String value,
    required Color valueColor,
    bool isBold = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 16 : 14,
              color: valueColor,
            ),
          ),
        ],
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
      case 'entregado_pendiente_liq':
        return 'Pendiente Liquidación';
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
        return Colors.amber;
      case 'finalizado':
        return Colors.teal;
      case 'rechazada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
