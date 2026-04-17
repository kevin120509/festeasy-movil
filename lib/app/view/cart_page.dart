import 'package:festeasy/app/view/request_status_page.dart';
import 'package:festeasy/service_session_data.dart';
import 'package:festeasy/services/cart_service.dart';
import 'package:festeasy/services/solicitud_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartPage extends StatefulWidget {
  const CartPage({
    required this.cartItems,
    required this.allItems,
    required this.providerName,
    required this.providerUserId,
    required this.categoryName,
    super.key,
    this.initialAddress,
    this.initialDate,
    this.initialTime,
    this.carritoId,
    this.initialGuests,
  });
  final Map<String, int> cartItems;
  final List<Map<String, dynamic>> allItems;
  final String providerName;
  final String providerUserId;
  final String categoryName;
  final String? initialAddress;
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final String? carritoId;
  final int? initialGuests;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late Map<String, int> cartItems;
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = const TimeOfDay(hour: 20, minute: 0);
  String address = '';
  Map<String, dynamic>? _providerProfile;
  bool _isSubmitting = false;
  String selectedPaymentMethod = 'Tarjeta';
  String eventName = '';
  int? guests;
  final TextEditingController _eventController = TextEditingController();
  final TextEditingController _guestsController = TextEditingController();
  final List<Map<String, Object>> paymentMethods = [
    {
      'id': 'Tarjeta',
      'label': 'Tarjeta',
      'sublabel': 'Stripe',
      'icon': Icons.credit_card,
    },
    {
      'id': 'SPEI',
      'label': 'SPEI',
      'sublabel': 'Transferencia',
      'icon': Icons.account_balance,
    },
    {
      'id': 'Efectivo',
      'label': 'Efectivo',
      'sublabel': 'Oxxo Pay',
      'icon': Icons.money,
    },
  ];

  @override
  void initState() {
    super.initState();
    cartItems = Map.from(widget.cartItems);
    address = widget.initialAddress ?? '';
    if (widget.initialDate != null) selectedDate = widget.initialDate!;
    if (widget.initialTime != null) selectedTime = widget.initialTime!;
    eventName = ServiceSessionData.getInstance().getEventNameForCart(widget.carritoId, widget.categoryName) ?? widget.categoryName;
    guests = ServiceSessionData.getInstance().getGuestsForCart(widget.carritoId) ?? widget.initialGuests;
    _eventController.text = eventName;
    _guestsController.text = guests?.toString() ?? '';

    _fetchProviderProfile();
  }

  Future<void> _fetchProviderProfile() async {
    try {
      final client = Supabase.instance.client;
      final perfil = await client
          .from('perfil_proveedor')
          .select(
            'id, usuario_id, nombre_negocio, descripcion, telefono, avatar_url, direccion_formato',
          )
          .or(
            'usuario_id.eq.${widget.providerUserId},id.eq.${widget.providerUserId}',
          )
          .maybeSingle();
      if (perfil != null) {
        setState(() {
          _providerProfile = perfil;
        });
      }
    } catch (_) {
      // ignore
    }
  }

  String _monthName(int month) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return months[month - 1];
  }

  double get subtotal {
    double total = 0;
    for (final entry in cartItems.entries) {
      final item = widget.allItems.firstWhere(
        (e) => e['id'] == entry.key,
        orElse: () => <String, Object>{'price': 0.0},
      );
      total += ((item['price'] as num?)?.toDouble() ?? 0.0) * entry.value;
    }
    return total;
  }

  double get serviceFee => subtotal * 0.05;
  double get taxes => subtotal * 0.08;
  double get total => subtotal + serviceFee + taxes;

  @override
  Widget build(BuildContext context) {
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
          'Detalles del Pedido',
          style: TextStyle(
            color: Color(0xFF010302),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final confirm = await _showConfirmDialog(
                '¿Vaciar carrito?',
                'Se eliminarán todos los productos de este proveedor.',
              );
              if (confirm != true) return;

              if (widget.carritoId != null) {
                try {
                  await Supabase.instance.client
                      .from('items_carrito')
                      .delete()
                      .eq('carrito_id', widget.carritoId!)
                      .filter('paquete_id', 'in', cartItems.keys.toList());
                  
                  ServiceSessionData.getInstance().clearCartForProvider(widget.providerUserId);
                  setState(() {
                    cartItems.clear();
                  });
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al vaciar: $e')),
                    );
                  }
                }
              } else {
                ServiceSessionData.getInstance().clearCartForProvider(widget.providerUserId);
                setState(() {
                  cartItems.clear();
                });
              }
            },
            child: const Text(
              'Vaciar',
              style: TextStyle(
                color: Color(0xFF8D72C2),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: cartItems.isEmpty
          ? _buildEmptyCart()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_providerProfile != null) ...[
                        _buildProviderCard(_providerProfile!),
                        const SizedBox(height: 16),
                      ],
                      _buildServiceDetailsEditor(),
                      const SizedBox(height: 16),
                      ..._buildCartItemsList(),
                      const SizedBox(height: 16),
                      _buildPaymentMethods(),
                    ],
                  ),
                ),
                _buildCostSummary(),
              ],
            ),
    );
  }

  Widget _buildEmptyCart() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Tu carrito está vacío',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCartItemsList() {
    final cartEntries = cartItems.entries.toList();
    final itemsWidgets = <Widget>[];

    for (final entry in cartEntries) {
      final item = widget.allItems.firstWhere(
        (e) => e['id'] == entry.key,
        orElse: () => <String, Object>{
          'id': entry.key,
          'name': 'Item',
          'description': '',
          'price': 0.0,
        },
      );
      itemsWidgets.add(_buildCartItem(item, entry.value));
      itemsWidgets.add(const SizedBox(height: 14));
    }
    return itemsWidgets;
  }

  Widget _buildProviderCard(Map<String, dynamic> profile) {
    final avatar = profile['avatar_url'] as String?;
    final name = profile['nombre_negocio'] as String? ?? widget.providerName;
    final phone = profile['telefono'] as String?;
    final addressFmt = profile['direccion_formato'] as String?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFF0E6FF),
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            child: avatar == null
                ? const Icon(Icons.person, color: Color(0xFF8D72C2))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (addressFmt != null)
                  Text(addressFmt, style: const TextStyle(color: Colors.grey)),
                if (phone != null)
                  Text(phone, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceDetailsEditor() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalles del Servicio',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          // Nombre del Evento y URL
          TextField(
            controller: _eventController,
            decoration: InputDecoration(
              labelText: 'Nombre del Evento',
              prefixIcon: const Icon(Icons.celebration, color: Color(0xFF8D72C2), size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (val) {
              eventName = val;
              ServiceSessionData.getInstance().setEventNameForCart(widget.carritoId, val);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _guestsController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Número de Invitados (Opcional)',
              prefixIcon: const Icon(Icons.people, color: Color(0xFF8D72C2), size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (val) {
              guests = int.tryParse(val);
              ServiceSessionData.getInstance().setGuestsForCart(widget.carritoId, guests);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFF8D72C2), size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${selectedDate.day} ${_monthName(selectedDate.month)}, ${selectedDate.year}',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _pickTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, color: Color(0xFF8D72C2), size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            selectedTime.format(context),
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Dirección del Evento',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _editAddress,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFF8D72C2), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address.isNotEmpty ? address : 'Toca para agregar dirección',
                      style: TextStyle(
                        color: address.isNotEmpty ? Colors.black : Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(Icons.edit, color: Colors.grey.shade400, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editAddress() {
    final controller = TextEditingController(text: address);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dirección del evento'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ingresa la dirección completa',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8D72C2),
            ),
            onPressed: () {
              setState(() {
                address = controller.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Método de Pago',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          children: paymentMethods.map((m) {
            final id = m['id']! as String;
            final label = m['label']! as String;
            final sub = m['sublabel']! as String;
            final icon = m['icon']! as IconData;
            final selected = id == selectedPaymentMethod;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => selectedPaymentMethod = id),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFFE9E9) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF8D72C2)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        color: selected ? const Color(0xFF8D72C2) : Colors.grey,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? const Color(0xFF8D72C2)
                              : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  Widget _buildCartItem(Map<String, dynamic> item, int qty) {
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
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
        children: [
          // Ícono del paquete
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFF0E6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2,
              size: 32,
              color: Color(0xFF8D72C2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if ((item['description'] as String).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item['description'] as String,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '\$${(price * qty).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF8D72C2),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildQuantitySelector(item['id'] as String, qty),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(String itemId, int qty) {
    return Row(
      children: [
        GestureDetector(
          onTap: () async {
            if (qty == 1) {
              final confirm = await _showConfirmDialog(
                '¿Eliminar producto?',
                '¿Estás seguro de que quieres quitar este item del carrito?',
              );
              if (confirm != true) return;
            }

            setState(() {
              if (qty > 1) {
                cartItems[itemId] = qty - 1;
              } else {
                cartItems.remove(itemId);
              }
            });
            ServiceSessionData.getInstance().updateCartItemQuantity(itemId, (cartItems[itemId] ?? 0));
            // Sincronizar con DB
            if (widget.carritoId != null) {
              final newQty = cartItems[itemId] ?? 0;
              if (newQty > 0) {
                CartService.instance.addItemToCart(
                  carritoId: widget.carritoId!,
                  paqueteId: itemId,
                  cantidad: newQty,
                  precioUnitario: 0.0,
                ).catchError((e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: const Color(0xFF8D72C2)),
                    );
                  }
                });
              } else {
                // Eliminar del carrito
                Supabase.instance.client.from('items_carrito')
                    .delete()
                    .eq('carrito_id', widget.carritoId!)
                    .eq('paquete_id', itemId)
                    .catchError((e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: const Color(0xFF8D72C2)),
                        );
                      }
                    });
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.remove, size: 18, color: Colors.grey),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '$qty',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              cartItems[itemId] = qty + 1;
            });
            ServiceSessionData.getInstance().updateCartItemQuantity(itemId, qty + 1);
            // Sincronizar con DB
            if (widget.carritoId != null) {
              CartService.instance.addItemToCart(
                carritoId: widget.carritoId!,
                paqueteId: itemId,
                cantidad: qty + 1,
                precioUnitario: 0.0,
              ).catchError((e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: const Color(0xFF8D72C2)),
                  );
                }
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF8D72C2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add, size: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildCostSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Resumen de Costos',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF010302),
            ),
          ),
          const SizedBox(height: 16),
          _buildCostRow('Subtotal', subtotal),
          const SizedBox(height: 8),
          _buildCostRow('Comisión de servicio (5%)', serviceFee),
          const SizedBox(height: 8),
          _buildCostRow('Impuestos', taxes),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF010302),
                ),
              ),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Color(0xFF8D72C2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8D72C2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: (cartItems.isNotEmpty && !_isSubmitting)
                  ? _submitSolicitud
                  : null,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Mandar Solicitud',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.send, color: Colors.white),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitSolicitud() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final serviceDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      // Crear solicitud única para este proveedor (mantener compatibilidad)
      final solicitud = await SolicitudService.instance.createSolicitud(
        providerUserId: widget.providerUserId,
        address: address,
        serviceDateLocal: serviceDateTime,
        tituloEvento: eventName,
        montoTotal: total,
        cartItems: cartItems,
        allItems: widget.allItems,
      );

      if (!mounted) return;

      // Marcar el carrito como convertido
      if (widget.carritoId != null) {
        try {
          await CartService.instance.convertCart(widget.carritoId!);
        } catch (_) {
          // Ignorar error al marcar carrito
        }
      }

      // Volver a la pantalla anterior (Detalles del Carrito) informando éxito
      Navigator.of(context).pop(true);

      // Ahora push RequestStatusPage encima del Dashboard
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => RequestStatusPage(solicitudId: solicitud.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar la solicitud: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildCostRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }


  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar', style: TextStyle(color: Color(0xFF8D72C2))),
          ),
        ],
      ),
    );
  }
}
