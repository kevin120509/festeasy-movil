import 'package:festeasy/app/view/request_status_page.dart';
import 'package:festeasy/services/solicitud_service.dart';
import 'package:flutter/material.dart';

class CheckoutPage extends StatefulWidget {

  const CheckoutPage({
    required this.cartItems, required this.allItems, required this.providerName, required this.providerUserId, required this.categoryName, required this.subtotal, required this.serviceFee, required this.taxes, required this.total, super.key,
    this.initialDate,
    this.initialTime,
    this.initialAddress,
    this.initialPaymentMethod,
  });
  final Map<String, int> cartItems;
  final List<Map<String, dynamic>> allItems;
  final String providerName;
  final String providerUserId;
  final String categoryName;
  final double subtotal;
  final double serviceFee;
  final double taxes;
  final double total;
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final String? initialAddress;
  final String? initialPaymentMethod;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = const TimeOfDay(hour: 20, minute: 0);
  String address = 'Av. Paseo de la Reforma 505';
  String selectedPaymentMethod = 'Tarjeta';
  bool _isSubmitting = false;

  final paymentMethods = [
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
          'Checkout',
          style: TextStyle(
            color: Color(0xFF010302),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildServiceDetails(),
              const SizedBox(height: 24),
              _buildMapSection(),
              const SizedBox(height: 24),
              _buildPaymentMethods(),
              const SizedBox(height: 24),
              _buildOrderSummary(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      // Button is rendered overlapping the order card to match design
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) selectedDate = widget.initialDate!;
    if (widget.initialTime != null) selectedTime = widget.initialTime!;
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      address = widget.initialAddress!;
    }
    if (widget.initialPaymentMethod != null && widget.initialPaymentMethod!.isNotEmpty) {
      selectedPaymentMethod = widget.initialPaymentMethod!;
    }
  }

  Widget _buildServiceDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detalles del Servicio',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF010302),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fecha', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Color(0xFFE01D25),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${selectedDate.day} ${_monthName(selectedDate.month)}, ${selectedDate.year}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hora de Inicio',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: Color(0xFFE01D25),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            selectedTime.format(context),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Dirección del Evento',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(Icons.search, color: Color(0xFFE01D25)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Stack(
            children: [
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 60, color: Colors.grey),
                    Text(
                      'Mapa (Google Maps)',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Center(
                child: Icon(
                  Icons.location_pin,
                  color: Color(0xFFE01D25),
                  size: 40,
                ),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Text(
                    'Ajustar Pin',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Método de Pago',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF010302),
              ),
            ),
            Row(
              children: [
                Icon(Icons.lock, color: Color(0xFFE01D25), size: 16),
                SizedBox(width: 4),
                Text(
                  'Seguro',
                  style: TextStyle(
                    color: Color(0xFFE01D25),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: paymentMethods.map((method) {
            final isSelected = selectedPaymentMethod == method['id'];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedPaymentMethod = method['id']! as String;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFE5E7) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFE01D25)
                          : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Icon(
                            method['icon']! as IconData,
                            color: isSelected
                                ? const Color(0xFFE01D25)
                                : Colors.grey,
                            size: 28,
                          ),
                          if (isSelected)
                            const Positioned(
                              right: -4,
                              top: -4,
                              child: Icon(
                                Icons.check_circle,
                                color: Color(0xFFE01D25),
                                size: 14,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        method['label']! as String,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isSelected
                              ? const Color(0xFFE01D25)
                              : const Color(0xFF010302),
                        ),
                      ),
                      Text(
                        method['sublabel']! as String,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
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

  Widget _buildOrderSummary() {
    final width = MediaQuery.of(context).size.width - 40;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // The summary card placed below the button
        Padding(
          padding: const EdgeInsets.only(top: 36),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                ...widget.cartItems.entries.map((entry) {
                  final item = widget.allItems.firstWhere(
                    (e) => e['id'] == entry.key,
                    orElse: () => <String, Object>{'name': 'Item', 'price': 0.0},
                  );
                  final price = (item['price'] as double) * entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] as String,
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                              ),
                              const Text(
                                'Servicio Básico',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '\$${price.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 6),
                const Divider(),
                const SizedBox(height: 10),
                _buildSummaryRow('Impuestos (IVA)', widget.taxes),
                const SizedBox(height: 12),
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
                      '\$${widget.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Color(0xFFE01D25),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // Overlapping confirm button
        Positioned(
          top: 0,
          child: SizedBox(
            width: width,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE01D25),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 6,
              ),
              onPressed: _isSubmitting ? null : _confirmPayment,
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
                          'Confirmar Reservación y Pagar',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, color: Colors.white),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
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

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE01D25),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _isSubmitting ? null : _confirmPayment,
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
                      'Confirmar Reservación y Pagar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.white),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFFE01D25)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFFE01D25)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  Future<void> _confirmPayment() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

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
        montoTotal: widget.total,
        cartItems: widget.cartItems,
        allItems: widget.allItems,
      );

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => RequestStatusPage(solicitudId: solicitud.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo confirmar el pago: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
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
}
