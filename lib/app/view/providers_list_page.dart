import 'package:festeasy/app/view/provider_detail_page_client.dart';
import 'package:festeasy/service_session_data.dart';
import 'package:festeasy/services/provider_search_service.dart';
import 'package:flutter/material.dart';

class ProvidersListPage extends StatefulWidget {
  const ProvidersListPage({super.key});

  @override
  State<ProvidersListPage> createState() => _ProvidersListPageState();
}

class _ProvidersListPageState extends State<ProvidersListPage> {
  late ServiceSessionData _sessionData;
  late Future<List<ProviderSearchResult>> _providersFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sessionData = ServiceSessionData.getInstance();
    _loadProviders();
  }

  void _loadProviders() {
    if (_sessionData.hasInitialData() && _sessionData.categoryId != null) {
      setState(() {
        _isLoading = true;
      });
      
      _providersFuture = ProviderSearchService.instance.searchProvidersByCategory(
        categoryId: _sessionData.categoryId!,
        latitude: _sessionData.latitude ?? 20.962632, // Default Mérida
        longitude: _sessionData.longitude ?? -87.307022,
      ).then((results) {
        setState(() {
          _isLoading = false;
        });
        return results;
      }).catchError((Object error) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
        return <ProviderSearchResult>[];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Proveedores de ${_sessionData.categoryName ?? 'Servicios'}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFE01D25),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : FutureBuilder<List<ProviderSearchResult>>(
              future: _providersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadProviders,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                final providers = snapshot.data ?? [];

                if (providers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No se encontraron proveedores',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ubicación: ${_sessionData.address ?? 'No especificada'}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadProviders,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: providers.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final provider = providers[index];
                    return _buildProviderCard(context, provider);
                  },
                );
              },
            ),
    );
  }

  Widget _buildProviderCard(BuildContext context, ProviderSearchResult provider) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => _navigateToProviderDetail(provider),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar y información básica
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[300],
                    ),
                    child: provider.avatarUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              provider.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.store, size: 40),
                                );
                              },
                            ),
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.store, size: 40),
                          ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre
                        Text(
                          provider.nombreNegocio,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Descripción
                        if (provider.descripcion != null)
                          Text(
                            provider.descripcion!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 8),
                        // Distancia y Rating
                        Row(
                          children: [
                            if (provider.distanciaKm != null) ...[
                              const Icon(Icons.location_on, size: 14, color: Color(0xFFE01D25)),
                              const SizedBox(width: 4),
                              Text(
                                '${provider.distanciaKm!.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFE01D25),
                                ),
                              ),
                            ],
                            const SizedBox(width: 12),
                            if (provider.calificacionPromedio != null) ...[
                              const Icon(Icons.star, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                provider.calificacionPromedio!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Arrow
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
            // Divider
            Divider(
              indent: 0,
              endIndent: 0,
              height: 1,
              color: Colors.grey[300],
            ),
            // Ubicación
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      provider.direccionFormato ?? 'Ubicación no disponible',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToProviderDetail(ProviderSearchResult provider) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProviderDetailPageClient(provider: provider),
      ),
    );
  }
}
