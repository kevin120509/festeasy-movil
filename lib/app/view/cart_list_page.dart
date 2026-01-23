import 'package:festeasy/services/cart_service.dart';
import 'package:festeasy/services/solicitud_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Modelo para item del carrito con info del proveedor
class CartItemWithProvider {
  final String itemId;
  final String paqueteId;
  final String paqueteNombre;
  final double precioUnitario;
  final int cantidad;
  final String proveedorUsuarioId;
  final String proveedorNombre;
  final String? proveedorAvatarUrl;

  CartItemWithProvider({
    required this.itemId,
    required this.paqueteId,
    required this.paqueteNombre,
    required this.precioUnitario,
    required this.cantidad,
    required this.proveedorUsuarioId,
    required this.proveedorNombre,
    this.proveedorAvatarUrl,
  });
}

class CartListPage extends StatefulWidget {
  const CartListPage({super.key, this.onSolicitudesEnviadas});

  /// Callback que se ejecuta cuando se envían solicitudes exitosamente
  final VoidCallback? onSolicitudesEnviadas;

  @override
  State<CartListPage> createState() => _CartListPageState();
}

class _CartListPageState extends State<CartListPage> {
  List<CartItemWithProvider> _allItems = [];
  CartData? _activeCart;
  bool _isLoading = true;
  bool _isSending = false;

  // Datos del evento (compartidos entre todos los proveedores)
  DateTime _fechaServicio = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _horaServicio = const TimeOfDay(hour: 14, minute: 0);
  String _direccion = '';

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Obtener carrito activo
      final cartResult = await client
          .from('carrito')
          .select()
          .eq('cliente_usuario_id', user.id)
          .eq('estado', 'activo')
          .maybeSingle();

      if (cartResult == null) {
        setState(() {
          _activeCart = null;
          _allItems = [];
          _isLoading = false;
        });
        return;
      }

      _activeCart = CartData.fromMap(cartResult);

      // Cargar datos del evento del carrito
      if (_activeCart!.fechaServicioDeseada != null) {
        _fechaServicio = _activeCart!.fechaServicioDeseada!;
      }
      if (_activeCart!.direccionServicio != null) {
        _direccion = _activeCart!.direccionServicio!;
      }

      // Obtener items del carrito con info del paquete y proveedor
      final itemsResult = await client
          .from('items_carrito')
          .select('''
            id,
            cantidad,
            precio_unitario_momento,
            paquete_id,
            paquetes_proveedor(
              id,
              nombre,
              precio_base,
              proveedor_usuario_id
            )
          ''')
          .eq('carrito_id', _activeCart!.id);

      final items = <CartItemWithProvider>[];

      for (final item in (itemsResult as List)) {
        final paquete = item['paquetes_proveedor'] as Map<String, dynamic>?;
        if (paquete == null) continue;

        final proveedorUsuarioId = paquete['proveedor_usuario_id'] as String;

        // Obtener perfil del proveedor
        final providerProfile = await client
            .from('perfil_proveedor')
            .select('nombre_negocio, avatar_url')
            .eq('usuario_id', proveedorUsuarioId)
            .maybeSingle();

        items.add(
          CartItemWithProvider(
            itemId: item['id'] as String,
            paqueteId: paquete['id'] as String,
            paqueteNombre: paquete['nombre'] as String? ?? 'Paquete',
            precioUnitario:
                (item['precio_unitario_momento'] as num?)?.toDouble() ??
                (paquete['precio_base'] as num?)?.toDouble() ??
                0,
            cantidad: item['cantidad'] as int? ?? 1,
            proveedorUsuarioId: proveedorUsuarioId,
            proveedorNombre:
                providerProfile?['nombre_negocio'] as String? ?? 'Proveedor',
            proveedorAvatarUrl: providerProfile?['avatar_url'] as String?,
          ),
        );
      }

      setState(() {
        _allItems = items;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando carrito: $e');
      setState(() => _isLoading = false);
    }
  }

  // Agrupar items por proveedor
  Map<String, List<CartItemWithProvider>> get _itemsByProvider {
    final grouped = <String, List<CartItemWithProvider>>{};
    for (final item in _allItems) {
      grouped.putIfAbsent(item.proveedorUsuarioId, () => []).add(item);
    }
    return grouped;
  }

  // Total general
  double get _totalGeneral {
    return _allItems.fold(
      0,
      (sum, item) => sum + (item.precioUnitario * item.cantidad),
    );
  }

  // Total por proveedor
  double _totalByProvider(String proveedorId) {
    return _allItems
        .where((i) => i.proveedorUsuarioId == proveedorId)
        .fold(0, (sum, item) => sum + (item.precioUnitario * item.cantidad));
  }

  Future<void> _updateItemQuantity(String itemId, int newQuantity) async {
    if (newQuantity < 1) {
      await _removeItem(itemId);
      return;
    }

    try {
      final client = Supabase.instance.client;
      await client
          .from('items_carrito')
          .update({'cantidad': newQuantity})
          .eq('id', itemId);

      setState(() {
        final index = _allItems.indexWhere((i) => i.itemId == itemId);
        if (index != -1) {
          final old = _allItems[index];
          _allItems[index] = CartItemWithProvider(
            itemId: old.itemId,
            paqueteId: old.paqueteId,
            paqueteNombre: old.paqueteNombre,
            precioUnitario: old.precioUnitario,
            cantidad: newQuantity,
            proveedorUsuarioId: old.proveedorUsuarioId,
            proveedorNombre: old.proveedorNombre,
            proveedorAvatarUrl: old.proveedorAvatarUrl,
          );
        }
      });
    } catch (e) {
      debugPrint('Error actualizando cantidad: $e');
    }
  }

  Future<void> _removeItem(String itemId) async {
    try {
      final client = Supabase.instance.client;
      await client.from('items_carrito').delete().eq('id', itemId);

      setState(() {
        _allItems.removeWhere((i) => i.itemId == itemId);
      });
    } catch (e) {
      debugPrint('Error eliminando item: $e');
    }
  }

  Future<void> _sendAllSolicitudes() async {
    if (_allItems.isEmpty) return;
    if (_direccion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa la dirección del evento'),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final providers = _itemsByProvider;
      var successCount = 0;
      var errorCount = 0;

      final serviceDateTime = DateTime(
        _fechaServicio.year,
        _fechaServicio.month,
        _fechaServicio.day,
        _horaServicio.hour,
        _horaServicio.minute,
      );

      for (final entry in providers.entries) {
        final providerUserId = entry.key;
        final items = entry.value;
        final providerName = items.first.proveedorNombre;

        // Calcular total para este proveedor
        final total = items.fold<double>(
          0,
          (sum, item) => sum + (item.precioUnitario * item.cantidad),
        );

        // Preparar datos para SolicitudService
        final cartItems = <String, int>{};
        final allItemsData = <Map<String, dynamic>>[];

        for (final item in items) {
          cartItems[item.paqueteId] = item.cantidad;
          allItemsData.add({
            'id': item.paqueteId,
            'name': item.paqueteNombre,
            'price': item.precioUnitario,
          });
        }

        try {
          await SolicitudService.instance.createSolicitud(
            providerUserId: providerUserId,
            address: _direccion,
            serviceDateLocal: serviceDateTime,
            tituloEvento: 'Evento - $providerName',
            montoTotal: total,
            cartItems: cartItems,
            allItems: allItemsData,
          );
          successCount++;
        } catch (e) {
          debugPrint('Error enviando solicitud a $providerName: $e');
          errorCount++;
        }
      }

      // Marcar carrito como convertido
      if (_activeCart != null && successCount > 0) {
        await CartService.instance.convertCart(_activeCart!.id);
      }

      if (mounted) {
        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorCount > 0
                    ? '$successCount solicitudes enviadas, $errorCount fallidas'
                    : '¡$successCount solicitudes enviadas exitosamente!',
              ),
              backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
            ),
          );

          // Limpiar estado local
          setState(() {
            _allItems = [];
            _activeCart = null;
          });

          // Notificar al padre para actualizar badge y navegar a Mis Eventos
          widget.onSolicitudesEnviadas?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo enviar ninguna solicitud'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaServicio,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _fechaServicio = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _horaServicio,
    );
    if (picked != null) {
      setState(() => _horaServicio = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Mi Carrito',
          style: TextStyle(
            color: Color(0xFF010302),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF010302)),
            onPressed: _loadCart,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE01D25)),
              ),
            )
          : _allItems.isEmpty
          ? _buildEmptyCart()
          : _buildCartContent(),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Tu carrito está vacío',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega paquetes de proveedores\npara planificar tu evento',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent() {
    final dateFormat = DateFormat('dd MMM yyyy', 'es');
    final providers = _itemsByProvider;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCart,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Datos del evento
                  _buildEventDataCard(dateFormat),
                  const SizedBox(height: 20),

                  // Items agrupados por proveedor
                  Text(
                    'Proveedores (${providers.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ...providers.entries.map(
                    (entry) => _buildProviderCard(entry.key, entry.value),
                  ),

                  const SizedBox(height: 20),

                  // Resumen total
                  _buildTotalCard(),

                  const SizedBox(height: 100), // Espacio para el botón flotante
                ],
              ),
            ),
          ),
        ),

        // Botón de enviar
        _buildSendButton(),
      ],
    );
  }

  Widget _buildEventDataCard(DateFormat dateFormat) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event, color: Color(0xFFE01D25)),
              SizedBox(width: 8),
              Text(
                'Datos del Evento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 24),

          // Fecha
          InkWell(
            onTap: _selectDate,
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fecha',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Text(
                        dateFormat.format(_fechaServicio),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit, size: 18, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Hora
          InkWell(
            onTap: _selectTime,
            child: Row(
              children: [
                Icon(Icons.access_time, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hora',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Text(
                        _horaServicio.format(context),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit, size: 18, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dirección
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dirección',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Ingresa la dirección del evento',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      onChanged: (value) => _direccion = value,
                      controller: TextEditingController(text: _direccion),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(
    String proveedorId,
    List<CartItemWithProvider> items,
  ) {
    final providerName = items.first.proveedorNombre;
    final providerAvatar = items.first.proveedorAvatarUrl;
    final total = _totalByProvider(proveedorId);

    return Container(
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
        children: [
          // Header del proveedor
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF5F5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFFFE5E7),
                  backgroundImage: providerAvatar != null
                      ? NetworkImage(providerAvatar)
                      : null,
                  child: providerAvatar == null
                      ? const Icon(
                          Icons.store,
                          color: Color(0xFFE01D25),
                          size: 20,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    providerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFFE01D25),
                  ),
                ),
              ],
            ),
          ),

          // Items
          ...items.map((item) => _buildItemRow(item)),
        ],
      ),
    );
  }

  Widget _buildItemRow(CartItemWithProvider item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.paqueteNombre,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '\$${item.precioUnitario.toStringAsFixed(2)} c/u',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          // Controles de cantidad
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.grey,
                iconSize: 24,
                onPressed: () =>
                    _updateItemQuantity(item.itemId, item.cantidad - 1),
              ),
              Text(
                '${item.cantidad}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: const Color(0xFFE01D25),
                iconSize: 24,
                onPressed: () =>
                    _updateItemQuantity(item.itemId, item.cantidad + 1),
              ),
            ],
          ),
          // Subtotal
          SizedBox(
            width: 70,
            child: Text(
              '\$${(item.precioUnitario * item.cantidad).toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    final providers = _itemsByProvider;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE01D25), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total General',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '\$${_totalGeneral.toStringAsFixed(2)} MXN',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE01D25),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${providers.length} proveedor(es)',
                style: TextStyle(color: Colors.grey[600]),
              ),
              Text(
                '${_allItems.length} item(s)',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    final providers = _itemsByProvider;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSending ? null : _sendAllSolicitudes,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE01D25),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: _isSending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Enviar ${providers.length} Solicitud(es)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
