import 'package:flutter/material.dart';
import 'package:festeasy/app/view/request_status_page.dart';
import 'package:festeasy/services/solicitud_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartPage extends StatefulWidget {
  final Map<String, int> cartItems;
  final List<Map<String, dynamic>> allItems;
  final String providerName;
  final String providerUserId;
  final String categoryName;
  final String? initialAddress;
  final DateTime? initialDate;
  final TimeOfDay? initialTime;

  const CartPage({
    super.key,
    required this.cartItems,
    required this.allItems,
    required this.providerName,
    required this.providerUserId,
    required this.categoryName,
    this.initialAddress,
    this.initialDate,
    this.initialTime,
  });

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
      total += (item['price'] as double) * entry.value;
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
          'Tu Carrito',
          style: TextStyle(
            color: Color(0xFF010302),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                cartItems.clear();
              });
            },
            child: const Text(
              'Vaciar',
              style: TextStyle(
                color: Color(0xFFE01D25),
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
                Expanded(child: _buildCartList()),
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

  Widget _buildCartList() {
    final cartEntries = cartItems.entries.toList();
    final children = <Widget>[];
    if (_providerProfile != null) {
      children.add(_buildProviderCard(_providerProfile!));
      children.add(const SizedBox(height: 16));
    }
    children.add(_buildServiceDetailsEditor());
    children.add(const SizedBox(height: 16));

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
      children.add(_buildCartItem(item, entry.value));
      children.add(const SizedBox(height: 14));
    }

    children.add(const SizedBox(height: 12));
    children.add(_buildPaymentMethods());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
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
            backgroundColor: const Color(0xFFFFE5E7),
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            child: avatar == null
                ? const Icon(Icons.person, color: Color(0xFFE01D25))
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalles del Servicio',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Color(0xFFE01D25),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${selectedDate.day} ${_monthName(selectedDate.month)}, ${selectedDate.year}',
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, color: Color(0xFFE01D25)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            selectedTime.format(context),
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
            style: TextStyle(color: Colors.grey),
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
                  const Icon(Icons.location_on, color: Color(0xFFE01D25)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address.isNotEmpty
                          ? address
                          : 'Toca para agregar dirección',
                      style: TextStyle(
                        color: address.isNotEmpty ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                  Icon(Icons.edit, color: Colors.grey.shade400, size: 18),
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
              backgroundColor: const Color(0xFFE01D25),
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
            final id = m['id'] as String;
            final label = m['label'] as String;
            final sub = m['sublabel'] as String;
            final icon = m['icon'] as IconData;
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
                          ? const Color(0xFFE01D25)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        color: selected ? const Color(0xFFE01D25) : Colors.grey,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? const Color(0xFFE01D25)
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
    final price = item['price'] as double;

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
              color: const Color(0xFFFFE5E7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2,
              size: 32,
              color: Color(0xFFE01D25),
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
                          color: Color(0xFFE01D25),
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
          onTap: () {
            setState(() {
              if (qty > 1) {
                cartItems[itemId] = qty - 1;
              } else {
                cartItems.remove(itemId);
              }
            });
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
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE01D25),
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
                  color: Color(0xFFE01D25),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE01D25),
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

      final solicitud = await SolicitudService.instance.createSolicitud(
        providerUserId: widget.providerUserId,
        address: address,
        serviceDateLocal: serviceDateTime,
        tituloEvento: widget.categoryName,
        montoTotal: total,
        cartItems: cartItems,
        allItems: widget.allItems,
      );

      if (!mounted) return;

      // Volver al ClientHomePage (hacer pop de CartPage y las pantallas intermedias)
      // Contamos las rutas: CartPage -> ProviderDetailPage -> ClientHomePage
      Navigator.of(context).pop(); // Sale de CartPage
      Navigator.of(context).pop(); // Sale de ProviderDetailPage (si existe)

      // Ahora push RequestStatusPage encima del ClientHomePage
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
}
