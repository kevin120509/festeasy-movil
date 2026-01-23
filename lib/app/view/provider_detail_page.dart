import 'package:festeasy/app/view/cart_page.dart';
import 'package:festeasy/services/favorite_service.dart';
import 'package:festeasy/services/provider_database_service.dart';
import 'package:flutter/material.dart';

class ProviderDetailPage extends StatefulWidget {

  const ProviderDetailPage({
    required this.providerId, required this.providerName, required this.category, required this.rating, required this.reviews, super.key,
    this.perfilId,
    this.usuarioId,
    this.address,
    this.phone,
    this.thumbnail,
    this.descripcion,
    this.serviceAddress,
    this.serviceDate,
    this.serviceTime,
  });
  final String providerId;
  final String? perfilId;
  final String? usuarioId;
  final String providerName;
  final String category;
  final double rating;
  final int reviews;
  final String? address;
  final String? phone;
  final String? thumbnail;
  final String? descripcion;
  final String? serviceAddress;
  final DateTime? serviceDate;
  final TimeOfDay? serviceTime;

  @override
  State<ProviderDetailPage> createState() => _ProviderDetailPageState();
}

class _ProviderDetailPageState extends State<ProviderDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isFavorite = false;
  bool isLoading = true;

  String get _providerUserId => widget.usuarioId ?? widget.providerId;

  // Paquetes cargados desde la base de datos
  List<PaqueteData> paquetesDB = [];

  // Carrito local
  final Map<String, int> cartItems = {};

  double get totalPrice {
    double total = 0;
    for (final entry in cartItems.entries) {
      // Buscar en paquetes de la BD
      final paquete = paquetesDB.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => PaqueteData(id: '', nombre: '', precioBase: 0),
      );
      total += paquete.precioBase * entry.value;
    }
    return total;
  }

  int get totalItemsCount {
    return cartItems.values.fold(0, (a, b) => a + b);
  }

  // Convertir paquetes a formato para el carrito
  List<Map<String, dynamic>> get allItemsForCart {
    return paquetesDB
        .map(
          (p) => {
            'id': p.id,
            'name': p.nombre,
            'description': p.descripcion ?? '',
            'price': p.precioBase,
          },
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    // Cargar estado de favorito
    final fav = await FavoriteService.instance.isFavorite(widget.providerId);
    if (mounted) {
      setState(() {
        isFavorite = fav;
      });
    }
    // Cargar paquetes
    await _loadPackages();
  }

  Future<void> _loadPackages() async {
    try {
      final packages = await ProviderDatabaseService.instance
          .getProviderPackages(widget.providerId);

      if (mounted) {
        setState(() {
          paquetesDB = packages;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFF),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(child: _buildProviderInfo()),
              SliverToBoxAdapter(child: _buildTabs()),
              SliverToBoxAdapter(child: _buildTabContent()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          // Bottom bar con total y carrito
          if (totalItemsCount > 0) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: Colors.white,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      actions: [
        // Botón de carrito con badge
        GestureDetector(
          onTap: () {
            if (totalItemsCount > 0) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => CartPage(
                    cartItems: cartItems,
                    allItems: allItemsForCart,
                    providerName: widget.providerName,
                    providerUserId: _providerUserId,
                    categoryName: widget.category,
                    initialAddress: widget.serviceAddress,
                    initialDate: widget.serviceDate,
                    initialTime: widget.serviceTime,
                  ),
                ),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart, color: Colors.white),
                if (totalItemsCount > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE01D25),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '$totalItemsCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Botón de favorito
        GestureDetector(
          onTap: () async {
            // Toggle favorite
            final newStatus = await FavoriteService.instance.toggleFavorite(
              widget.providerId,
            );
            if (mounted) {
              setState(() {
                isFavorite = newStatus;
              });
            }
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? const Color(0xFFE01D25) : Colors.white,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: widget.thumbnail != null && widget.thumbnail!.isNotEmpty
            ? Image.network(
                widget.thumbnail!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFF4F7F9),
                  child: Center(
                    child: Icon(Icons.storefront, size: 80, color: Colors.grey),
                  ),
                ),
              )
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE01D25), Color(0xFF8B0000)],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.storefront,
                        size: 80,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.providerName.isNotEmpty
                            ? widget.providerName[0].toUpperCase()
                            : 'P',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProviderInfo() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.providerName,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF010302),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE01D25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.rating}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '(${widget.reviews} reseñas)',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(width: 16),
              Text(
                widget.category,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Expertos en transformar espacios vacíos en experiencias memorables. Especialistas en bodas y...',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF4F7F9), width: 2),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (_) => setState(() {}),
        labelColor: const Color(0xFFE01D25),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFFE01D25),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        tabs: const [
          Tab(text: 'Paquetes'),
          Tab(text: 'Reseñas'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    if (_tabController.index == 0) {
      return _buildPackagesTab();
    } else {
      return _buildReviewsTab();
    }
  }

  Widget _buildPackagesTab() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE01D25)),
          ),
        ),
      );
    }

    if (paquetesDB.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 60,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'Este proveedor aún no tiene paquetes publicados',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Puedes contactarlo para más información',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Paquetes Disponibles',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF010302),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE01D25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${paquetesDB.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...paquetesDB.map(_buildPackageCardDB),
        ],
      ),
    );
  }

  Widget _buildPackageCardDB(PaqueteData pkg) {
    final qty = cartItems[pkg.id] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: qty > 0
            ? Border.all(color: const Color(0xFFE01D25), width: 2)
            : null,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icono del paquete
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
                      pkg.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (pkg.descripcion != null &&
                        pkg.descripcion!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        pkg.descripcion!,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '\$${pkg.precioBase.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFFE01D25),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Items incluidos
          if (pkg.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Incluye:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF010302),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...pkg.items
                      .take(4)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Color(0xFF4CAF50),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${item.cantidad} ${item.unidad ?? 'x'} ${item.nombre}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (pkg.items.length > 4)
                    Text(
                      '+ ${pkg.items.length - 4} items más...',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFE01D25),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Botón agregar o selector de cantidad
          if (qty == 0)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE01D25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  setState(() {
                    cartItems[pkg.id] = 1;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${pkg.nombre} agregado al carrito'),
                      backgroundColor: const Color(0xFF4CAF50),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                label: const Text(
                  'Agregar al Carrito',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'En carrito',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _buildQuantitySelector(pkg.id, qty),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(String itemId, int qty) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: qty == 1 ? Colors.red.shade50 : const Color(0xFFF4F7F9),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
              ),
              child: Icon(
                qty == 1 ? Icons.delete_outline : Icons.remove,
                size: 20,
                color: qty == 1 ? Colors.red : const Color(0xFFE01D25),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$qty',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                cartItems[itemId] = qty + 1;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFE01D25),
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(12),
                ),
              ),
              child: const Icon(Icons.add, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Center(
        child: Text(
          'Reseñas de clientes próximamente...',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
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
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                Text(
                  '\$${totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Color(0xFF010302),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE01D25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  // Navegar al carrito
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => CartPage(
                        cartItems: cartItems,
                        allItems: allItemsForCart,
                        providerName: widget.providerName,
                        providerUserId: _providerUserId,
                        categoryName: widget.category,
                        initialAddress: widget.serviceAddress,
                        initialDate: widget.serviceDate,
                        initialTime: widget.serviceTime,
                      ),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Ver Carrito',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalItemsCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
