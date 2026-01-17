import 'package:flutter/material.dart';

class ProviderResultsPage extends StatefulWidget {
  final String categoryName;
  final String categoryId;

  const ProviderResultsPage({
    Key? key,
    required this.categoryName,
    required this.categoryId,
  }) : super(key: key);

  @override
  State<ProviderResultsPage> createState() => _ProviderResultsPageState();
}

class _ProviderResultsPageState extends State<ProviderResultsPage> {
  int _currentIndex = 0;
  String _selectedFilter = 'Más cercanos';

  // Datos de ejemplo de proveedores
  final List<Map<String, dynamic>> providers = [
    {
      'name': 'Sonido Master DJ',
      'distance': '2.5 km',
      'category': 'Música y Audio',
      'rating': 4.9,
      'reviews': 120,
      'priceLevel': '\$\$',
      'priceLabel': 'Moderado',
      'isPopular': false,
      'isFavorite': false,
      'usersCount': 118,
      'image': null,
    },
    {
      'name': 'Banquetes Delicia',
      'distance': '5.0 km',
      'category': 'Catering',
      'rating': 4.7,
      'reviews': 85,
      'priceLevel': '\$\$\$',
      'priceLabel': 'Moderado',
      'isPopular': false,
      'isFavorite': false,
      'usersCount': 0,
      'image': null,
    },
    {
      'name': 'Sillas y Mesas Express',
      'distance': '1.2 km',
      'category': 'Mobiliario',
      'rating': 4.5,
      'reviews': 200,
      'priceLevel': '\$',
      'priceLabel': 'Económico',
      'isPopular': true,
      'isFavorite': false,
      'usersCount': 0,
      'image': null,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildFilters(),
            _buildResultsHeader(),
            Expanded(child: _buildProvidersList()),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE5E7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.celebration, color: Color(0xFFE01D25), size: 24),
          ),
          const SizedBox(width: 10),
          const Text(
            'FestEasy',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Color(0xFF010302),
            ),
          ),
          const Spacer(),
          // Notificaciones
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Color(0xFF010302)),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE01D25),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: const [
            Icon(Icons.search, color: Colors.grey),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Busca sillas, DJ, banquetes...',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final filters = ['Más cercanos', 'Precio bajo', 'Mejor valorados'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final filter = filters[index];
            final isSelected = _selectedFilter == filter;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE01D25) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFE01D25) : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    if (index == 0)
                      Icon(
                        Icons.near_me,
                        size: 16,
                        color: isSelected ? Colors.white : const Color(0xFFE01D25),
                      ),
                    if (index == 1)
                      Icon(
                        Icons.attach_money,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.grey,
                      ),
                    if (index == 2)
                      Icon(
                        Icons.star,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.amber,
                      ),
                    const SizedBox(width: 4),
                    Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF010302),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Resultados cercanos',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF010302),
            ),
          ),
          TextButton(
            onPressed: () {
              // Ver mapa
            },
            child: const Text(
              'Ver mapa',
              style: TextStyle(
                color: Color(0xFFE01D25),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvidersList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: providers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final provider = providers[index];
        return _buildProviderCard(provider);
      },
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          // Imagen del proveedor
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: Container(
                  height: 160,
                  width: double.infinity,
                  color: const Color(0xFFF4F7F9),
                  child: const Icon(Icons.image, size: 60, color: Colors.grey),
                ),
              ),
              // Badge Popular
              if (provider['isPopular'] == true)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE01D25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'POPULAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              // Rating
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${provider['rating']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        ' (${provider['reviews']})',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Info del proveedor
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        provider['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Color(0xFF010302),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        provider['isFavorite'] == true
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: const Color(0xFFE01D25),
                      ),
                      onPressed: () {
                        setState(() {
                          provider['isFavorite'] = !(provider['isFavorite'] as bool);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.grey, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${provider['distance']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    const Text('•', style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 6),
                    Text(
                      provider['category'] as String,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Usuarios (avatares)
                    if ((provider['usersCount'] as int) > 0)
                      Row(
                        children: [
                          ...List.generate(
                            2,
                            (i) => Container(
                              margin: EdgeInsets.only(left: i == 0 ? 0 : 0),
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.grey.shade300,
                                child: const Icon(Icons.person, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '+${provider['usersCount']}',
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    if ((provider['usersCount'] as int) == 0)
                      Text(
                        provider['priceLevel'] as String,
                        style: TextStyle(
                          color: (provider['priceLevel'] as String).length == 1
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    if ((provider['usersCount'] as int) == 0)
                      Text(
                        ' ${provider['priceLabel']}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFE01D25),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Color(0xFFE01D25)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                        elevation: 0,
                      ),
                      onPressed: () {
                        // Ver más detalles del proveedor
                      },
                      child: const Text(
                        'Ver más',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFE01D25),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explorar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: 'Favoritos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Reservas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
