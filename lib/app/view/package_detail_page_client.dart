import 'package:carousel_slider/carousel_slider.dart';
import 'package:festeasy/app/view/cart_page.dart';
import 'package:festeasy/app/view/cart_list_page.dart';
import 'package:festeasy/service_session_data.dart';
import 'package:festeasy/services/cart_service.dart';
import 'package:festeasy/services/provider_paquetes_service.dart';
import 'package:festeasy/services/provider_search_service.dart';
import 'package:flutter/material.dart';

class PackageDetailPageClient extends StatefulWidget {
  const PackageDetailPageClient({
    required this.paquete,
    required this.provider,
    super.key,
  });
  final PaqueteProveedorData paquete;
  final ProviderSearchResult provider;

  @override
  State<PackageDetailPageClient> createState() =>
      _PackageDetailPageClientState();
}

class _PackageDetailPageClientState extends State<PackageDetailPageClient> {
  late int _cantidad;
  int _currentPhotoIndex = 0;
  late ServiceSessionData _sessionData;

  @override
  void initState() {
    super.initState();
    _cantidad = 1;
    _sessionData = ServiceSessionData.getInstance();
  }

  Future<void> _addToCart() async {
    _sessionData.addCartItem(
      packageId: widget.paquete.id,
      packageName: widget.paquete.nombre,
      packagePrice: widget.paquete.precioBase,
      quantity: _cantidad,
      providerUserId: widget.provider.usuarioId,
      providerName: widget.provider.nombreNegocio,
      providerAvatarUrl: widget.provider.avatarUrl ?? '',
    );

    // Guardar en la BD
    try {
      final cartService = CartService.instance;

      // Crear o obtener carrito
      final carritoId = await cartService.createOrGetCart(
        categoryId: _sessionData.categoryId ?? '',
        fechaServicio: _sessionData.date,
        direccion: _sessionData.address,
      );
      _sessionData.carritoId = carritoId;

      // Agregar item al carrito
      await cartService.addItemToCart(
        carritoId: carritoId,
        paqueteId: widget.paquete.id,
        cantidad: _cantidad,
        precioUnitario: widget.paquete.precioBase,
      );
    } catch (e) {
      debugPrint('[PackageDetailPage] ERROR guardando en DB: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar en la base de datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Mostrar confirmación
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_cantidad ${widget.paquete.nombre} agregado al carrito',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    setState(() {});
  }

  void _goToCart() {
    Navigator.of(context).push(
      MaterialPageRoute<bool?>(
        builder: (context) => CartListPage(isStandalone: true),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detalle del Paquete',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFE01D25),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(
                  Icons.shopping_cart,
                  color: Colors.white,
                ),
                if (_sessionData.hasCartItems())
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _sessionData.cartItemCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _goToCart,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fotos del paquete
            _buildPhotoCarousel(),
            const SizedBox(height: 16),
            // Información del proveedor
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[300],
                    ),
                    child: widget.provider.avatarUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              widget.provider.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.store, size: 24);
                              },
                            ),
                          )
                        : const Icon(Icons.store, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.provider.nombreNegocio,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (widget.provider.distanciaKm != null)
                          Text(
                            '${widget.provider.distanciaKm!.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Nombre y descripción del paquete
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.paquete.nombre,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.paquete.descripcion != null)
                    Text(
                      widget.paquete.descripcion!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Precio
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE01D25).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Precio unitario',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      '\$${widget.paquete.precioBase.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE01D25),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 24),
            // Selector de cantidad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cantidad',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        // Botón menos
                        Expanded(
                          child: InkWell(
                            onTap: _cantidad > 1
                                ? () => setState(() => _cantidad--)
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: const Icon(Icons.remove),
                            ),
                          ),
                        ),
                        // Número
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                _cantidad.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Botón más
                        Expanded(
                          child: InkWell(
                            onTap: _cantidad < 10
                                ? () => setState(() => _cantidad++)
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: const Icon(Icons.add),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Subtotal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subtotal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '\$${(widget.paquete.precioBase * _cantidad).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Botones de acción
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Botón agregar al carrito
                  ElevatedButton(
                    onPressed: _addToCart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE01D25),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text(
                      'Añadir al Carrito',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Botón ir al carrito (si hay items)
                  if (_sessionData.hasCartItems())
                    OutlinedButton(
                      onPressed: _goToCart,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: const BorderSide(color: Color(0xFFE01D25)),
                      ),
                      child: const Text(
                        'Ir al Carrito',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE01D25),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCarousel() {
    if (widget.paquete.fotos.isEmpty) {
      return Container(
        width: double.infinity,
        height: 300,
        color: Colors.grey[300],
        child: const Icon(Icons.shopping_bag, size: 64),
      );
    }

    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 300,
            viewportFraction: 1,
            onPageChanged: (index, reason) {
              setState(() {
                _currentPhotoIndex = index;
              });
            },
          ),
          items: widget.paquete.fotos.map((photoUrl) {
            return Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, size: 64),
                );
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Indicadores
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.paquete.fotos.length,
            (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPhotoIndex == index
                    ? const Color(0xFFE01D25)
                    : Colors.grey,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDetallesList() {
    final detalles = widget.paquete.detallesJson ?? {};
    final items = <Widget>[];

    final ignoredKeys = [
      'fotos',
      'imagenes',
      'cargos_adicionales',
      'tipoCobro',
    ];

    detalles.forEach((key, value) {
      if (value != null &&
          value.toString().isNotEmpty &&
          !ignoredKeys.contains(key)) {
        items.add(
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                size: 16,
                color: Color(0xFFE01D25),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$key: $value',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
        items.add(const SizedBox(height: 8));
      }
    });

    return items.isNotEmpty
        ? items
        : [
            Text(
              'Sin detalles adicionales',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ];
  }
}
