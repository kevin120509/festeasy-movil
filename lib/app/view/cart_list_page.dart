import 'package:festeasy/app/view/cart_page.dart';
import 'package:festeasy/app/view/client_notifications_page.dart';
import 'package:festeasy/app/view/profile_page.dart';
import 'package:festeasy/service_session_data.dart';
import 'package:festeasy/services/cart_service.dart';
import 'package:festeasy/services/client_perfil_service.dart';
import 'package:festeasy/services/solicitud_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartItemWithProvider {
  CartItemWithProvider({
    required this.itemId,
    required this.paqueteId,
    required this.paqueteNombre,
    required this.precioUnitario,
    required this.cantidad,
    required this.proveedorUsuarioId,
    required this.proveedorNombre,
    required this.carritoId,
    this.proveedorAvatarUrl,
  });
  final String itemId;
  final String paqueteId;
  final String paqueteNombre;
  final double precioUnitario;
  final int cantidad;
  final String proveedorUsuarioId;
  final String proveedorNombre;
  final String? proveedorAvatarUrl;
  final String carritoId;
}

class CartListPage extends StatefulWidget {
  const CartListPage({super.key, this.onSolicitudesEnviadas, this.isStandalone = false});
  final VoidCallback? onSolicitudesEnviadas;
  final bool isStandalone;

  @override
  State<CartListPage> createState() => CartListPageState();
}

class CartListPageState extends State<CartListPage> {
  List<CartItemWithProvider> _allItems = [];
  bool _isLoading = true;
  String? _avatarUrl;
  Map<String, dynamic>? _activeCartInfo;
  Map<String, Map<String, dynamic>> _cartsMap = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
    loadCart();
  }

  Future<void> _loadProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final perfil = await ClientPerfilService.instance.getPerfil(user.id);
        if (perfil != null && mounted) {
          setState(() {
            _avatarUrl = perfil.avatarUrl;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> loadCart() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Obtener todos los carritos activos
      final cartsListQuery = await Supabase.instance.client
          .from('carrito')
          .select()
          .eq('cliente_usuario_id', user.id)
          .eq('estado', 'activo');

      final cartsMap = <String, Map<String, dynamic>>{};
      for (final c in (cartsListQuery as List)) {
        cartsMap[c['id'] as String] = c as Map<String, dynamic>;
      }

      // Obtener items usando el servicio robusto (que ya trae carritoId)
      final itemsForSession = await CartService.instance.getCartItemsForLocalSession();
      
      final items = <CartItemWithProvider>[];
      for (final i in itemsForSession) {
        items.add(
          CartItemWithProvider(
            itemId: i['packageId'], 
            paqueteId: i['packageId'],
            paqueteNombre: i['packageName'],
            precioUnitario: i['packagePrice'],
            cantidad: i['quantity'],
            proveedorUsuarioId: i['providerUserId'],
            proveedorNombre: i['providerName'],
            proveedorAvatarUrl: i['providerAvatarUrl'],
            carritoId: i['carritoId'],
          ),
        );
      }

      if (mounted) {
        setState(() {
          _allItems = items;
          _cartsMap = cartsMap;
          _isLoading = false;
        });
      }

      if (mounted) {
        setState(() {
          _allItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando carrito: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar carrito: $e'),
            backgroundColor: const Color(0xFF8D72C2),
          ),
        );
      }
    }
  }

  Map<String, List<CartItemWithProvider>> get _itemsByProvider {
    final grouped = <String, List<CartItemWithProvider>>{};
    for (final item in _allItems) {
      // Agrupamos por combinación de carrito y proveedor
      final key = '${item.carritoId}_${item.proveedorUsuarioId}';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: widget.isStandalone,
        leading: widget.isStandalone ? IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF010302)),
          onPressed: () => Navigator.of(context).pop(),
        ) : null,
        title: const Text(
          'Mi Carrito',
          style: TextStyle(color: Color(0xFF010302), fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          if (!widget.isStandalone) IconButton(
            icon: const Icon(Icons.notifications, color: Color(0xFF8D72C2)),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClientNotificationsPage())),
          ),
          if (!widget.isStandalone) IconButton(
            icon: _avatarUrl != null
                ? CircleAvatar(radius: 14, backgroundImage: NetworkImage(_avatarUrl!))
                : const Icon(Icons.person_outline, color: Color(0xFF010302)),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilePage())).then((_) => _loadProfile()),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D72C2))))
          : _allItems.isEmpty
              ? _buildEmptyCart()
              : _buildCartDashboard(),
    );
  }

  Widget _buildEmptyCart() {
    return RefreshIndicator(
      onRefresh: loadCart,
      color: const Color(0xFF8D72C2),
      child: ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('Tu carrito está vacío', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartDashboard() {
    final groups = _itemsByProvider;
    return RefreshIndicator(
      onRefresh: loadCart,
      color: const Color(0xFF8D72C2),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final entry = groups.entries.elementAt(index);
          return _buildProviderSummaryCard(entry.key, entry.value);
        },
      ),
    );
  }

  Widget _buildProviderSummaryCard(String key, List<CartItemWithProvider> items) {
    final first = items.first;
    final totalItems = items.fold(0, (sum, i) => sum + i.cantidad);
    final totalAmount = items.fold(0.0, (sum, i) => sum + (i.precioUnitario * i.cantidad));
    
    final cartInfo = _cartsMap[first.carritoId];
    final eventName = cartInfo?['nombre_evento'] as String? ?? ServiceSessionData.getInstance().getEventNameForCart(first.carritoId, 'Evento sin nombre');

    return GestureDetector(
      onTap: () => _goToProviderCheckout(first.proveedorUsuarioId, items, first.carritoId),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: const Color(0xFFF0E6FF),
                  backgroundImage: first.proveedorAvatarUrl != null ? NetworkImage(first.proveedorAvatarUrl!) : null,
                  child: first.proveedorAvatarUrl == null ? const Icon(Icons.person, color: Color(0xFF8D72C2)) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(first.proveedorNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(eventName ?? 'Evento sin nombre', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total parcial', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    Text('\$${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF8D72C2))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF0E6FF), borderRadius: BorderRadius.circular(20)),
                  child: Text('$totalItems items', style: const TextStyle(color: Color(0xFF8D72C2), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _goToProviderCheckout(String providerId, List<CartItemWithProvider> items, String carritoId) {
    final cartInfo = _cartsMap[carritoId];
    if (cartInfo == null) return;

    final cartItemsMap = <String, int>{};
    final allItemsList = <Map<String, dynamic>>[];
    for (final i in items) {
      cartItemsMap[i.paqueteId] = i.cantidad;
      allItemsList.add({'id': i.paqueteId, 'name': i.paqueteNombre, 'price': i.precioUnitario, 'description': ''});
    }

    final dateStr = cartInfo['fecha_servicio_deseada'] as String?;
    final timeStr = cartInfo['hora_servicio_deseada'] as String?;

    Navigator.of(context).push(
      MaterialPageRoute<bool?>(
        builder: (context) => CartPage(
          cartItems: cartItemsMap,
          allItems: allItemsList,
          providerName: items.first.proveedorNombre,
          providerUserId: providerId,
          categoryName: cartInfo['nombre_evento'] ?? 'Servicio',
          initialAddress: cartInfo['direccion_servicio'],
          initialDate: dateStr != null ? DateTime.parse(dateStr) : null,
          initialTime: _parseTime(timeStr),
          carritoId: carritoId,
          initialGuests: cartInfo['numero_invitados'] as int?,
        ),
      ),
    ).then((result) {
      loadCart();
      if (result == true) {
        widget.onSolicitudesEnviadas?.call();
      }
    });
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || !timeStr.contains(':')) return null;
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) { return null; }
  }
}
