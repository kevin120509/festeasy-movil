import 'package:flutter/material.dart';
import 'package:festeasy/app/view/checkout_page.dart';

class CartPage extends StatefulWidget {
  final Map<String, int> cartItems;
  final List<Map<String, dynamic>> allItems;
  final String providerName;

  const CartPage({
    Key? key,
    required this.cartItems,
    required this.allItems,
    required this.providerName,
  }) : super(key: key);

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late Map<String, int> cartItems;

  @override
  void initState() {
    super.initState();
    cartItems = Map.from(widget.cartItems);
  }

  double get subtotal {
    double total = 0;
    for (final entry in cartItems.entries) {
      final item = widget.allItems.firstWhere(
        (e) => e['id'] == entry.key,
        orElse: () => {'price': 0.0},
      );
      total += (item['price'] as double) * entry.value;
    }
    return total;
  }

  double get serviceFee => subtotal * 0.05;
  double get taxes => subtotal * 0.08;
  double get total => subtotal + serviceFee + taxes;

  int get totalItemsCount {
    return cartItems.values.fold(0, (a, b) => a + b);
  }

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
              style: TextStyle(color: Color(0xFFE01D25), fontWeight: FontWeight.w600),
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
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: cartEntries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final entry = cartEntries[index];
        final item = widget.allItems.firstWhere(
          (e) => e['id'] == entry.key,
          orElse: () => {
            'id': entry.key,
            'name': 'Item',
            'description': '',
            'price': 0.0,
          },
        );
        return _buildCartItem(item, entry.value);
      },
    );
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
                    Text(
                      '\$${(price * qty).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFFE01D25),
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
              onPressed: cartItems.isNotEmpty
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => CheckoutPage(
                            cartItems: cartItems,
                            allItems: widget.allItems,
                            providerName: widget.providerName,
                            subtotal: subtotal,
                            serviceFee: serviceFee,
                            taxes: taxes,
                            total: total,
                          ),
                        ),
                      );
                    }
                  : null,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continuar al Pago',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
