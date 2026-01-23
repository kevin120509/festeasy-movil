import 'package:festeasy/services/auth_service.dart';
import 'package:festeasy/services/provider_perfil_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class ProviderSetupPage extends StatefulWidget {
  const ProviderSetupPage({super.key});

  @override
  State<ProviderSetupPage> createState() => _ProviderSetupPageState();
}

class _ProviderSetupPageState extends State<ProviderSetupPage> {
  late PageController _pageController;
  int _currentStep = 0;

  final _formKey = GlobalKey<FormState>();
  final _nombreNegocioController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categorias = [];
  double? _selectedLatitude;
  double? _selectedLongitude;
  int _radioCoberturaKm = 20;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadCategorias();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nombreNegocioController.dispose();
    _descripcionController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  Future<void> _loadCategorias() async {
    final categorias =
        await ProviderPerfilService.instance.getCategorias();
    setState(() {
      _categorias = categorias;
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        if (result == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permiso de ubicación denegado'),
              ),
            );
          }
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLatitude = position.latitude;
        _selectedLongitude = position.longitude;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error obteniendo ubicación: $e')),
        );
      }
    }
  }

  Future<void> _completeSetup() async {
    // Validar Paso 1
    if (_nombreNegocioController.text.isEmpty) {
      debugPrint('Validation failed: nombre vacío');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre del negocio requerido')),
      );
      return;
    }

    if (_selectedCategoryId == null) {
      debugPrint('Validation failed: categoría no seleccionada');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categoría requerida')),
      );
      return;
    }

    // Validar Paso 2
    if (_direccionController.text.isEmpty) {
      debugPrint('Validation failed: dirección vacía');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dirección requerida')),
      );
      return;
    }

    if (_selectedLatitude == null || _selectedLongitude == null) {
      debugPrint('Validation failed: ubicación no seleccionada');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar una ubicación')),
      );
      return;
    }

    setState(() => _isLoading = true);
    debugPrint('Starting setup completion...');

    try {
      final user = AuthService.instance.currentUser;
      debugPrint('Current user: ${user?.id}');
      if (user == null) throw Exception('Usuario no autenticado');

      // Crear o actualizar perfil del proveedor
      final perfilService = ProviderPerfilService.instance;
      var perfil =
          await perfilService.getPerfilByUserId(user.id);
      debugPrint('Existing profile: ${perfil?.id}');

      if (perfil == null) {
        // Crear nuevo perfil
        debugPrint('Creating new profile...');
        perfil = await perfilService.createPerfil(
          usuarioId: user.id,
          nombreNegocio: _nombreNegocioController.text,
          descripcion: _descripcionController.text,
          telefono: _telefonoController.text,
          categoriaPrincipalId: _selectedCategoryId,
        );
        debugPrint('Profile created: ${perfil.id}');
      } else {
        debugPrint('Updating existing profile...');
        // Si ya existe, actualizar datos básicos
        perfil = await perfilService.updatePerfil(
          perfilId: perfil.id,
          nombreNegocio: _nombreNegocioController.text,
          descripcion: _descripcionController.text,
          telefono: _telefonoController.text,
          categoriaPrincipalId: _selectedCategoryId,
        );
        debugPrint('Profile updated: ${perfil.id}');
      }

      // Actualizar con ubicación y cobertura
      debugPrint('Updating location...');
      await perfilService.updateUbicacion(
        perfilId: perfil.id,
        direccionFormato: _direccionController.text,
        latitud: _selectedLatitude!,
        longitud: _selectedLongitude!,
        radioCoberturaKm: _radioCoberturaKm,
      );
      debugPrint('Location updated successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Perfil configurado exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
        debugPrint('Returning to previous screen with true');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error in _completeSetup: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('Setup completion finished');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Perfil'),
        centerTitle: true,
        elevation: 0,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() => _currentStep = index);
        },
        children: [
          _buildStep1InfoBasica(),
          _buildStep2Ubicacion(),
          _buildStep3Resumen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildStep1InfoBasica() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              'Paso 1: Información Básica',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nombreNegocioController,
              decoration: InputDecoration(
                labelText: 'Nombre del Negocio',
                hintText: 'Ej: DJ Eventos Mérida',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'El nombre del negocio es requerido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryId,
              decoration: InputDecoration(
                labelText: 'Categoría Principal',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: _categorias
                  .map(
                    (cat) => DropdownMenuItem(
                      value: cat['id'] as String,
                      child: Text(cat['nombre'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedCategoryId = value);
              },
              validator: (value) {
                if (value == null) {
                  return 'Debes seleccionar una categoría';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descripcionController,
              decoration: InputDecoration(
                labelText: 'Descripción del Negocio',
                hintText: 'Cuéntanos sobre tu negocio...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _telefonoController,
              decoration: InputDecoration(
                labelText: 'Teléfono de Contacto',
                hintText: '9999999999',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Ubicacion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Paso 2: Ubicación y Cobertura',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ubicación Actual:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (_selectedLatitude != null && _selectedLongitude != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Latitud: ${_selectedLatitude!.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          'Longitud: ${_selectedLongitude!.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 24,
                        ),
                      ],
                    )
                  else
                    const Text(
                      'Ubica presiona el botón para obtener tu ubicación',
                      style: TextStyle(color: Colors.grey),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Obtener Mi Ubicación'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _direccionController,
            decoration: InputDecoration(
              labelText: 'Dirección Completa',
              hintText: 'Calle, número, referencia...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'La dirección es requerida';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Radio de Cobertura: $_radioCoberturaKm km',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Slider(
            value: _radioCoberturaKm.toDouble(),
            min: 5,
            max: 50,
            divisions: 9,
            label: '$_radioCoberturaKm km',
            onChanged: (value) {
              setState(() => _radioCoberturaKm = value.toInt());
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Esto define qué tan lejos atiendes solicitudes desde tu ubicación',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Resumen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Paso 3: Resumen',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildResumenItem(
                    'Nombre del Negocio',
                    _nombreNegocioController.text,
                  ),
                  const Divider(),
                  _buildResumenItem(
                    'Descripción',
                    _descripcionController.text.isNotEmpty
                        ? _descripcionController.text
                        : 'No especificada',
                  ),
                  const Divider(),
                  _buildResumenItem(
                    'Teléfono',
                    _telefonoController.text.isNotEmpty
                        ? _telefonoController.text
                        : 'No especificado',
                  ),
                  const Divider(),
                  _buildResumenItem(
                    'Dirección',
                    _direccionController.text,
                  ),
                  const Divider(),
                  _buildResumenItem(
                    'Cobertura',
                    '$_radioCoberturaKm km',
                  ),
                  const Divider(),
                  _buildResumenItem(
                    'Coordenadas',
                    _selectedLatitude != null
                        ? '${_selectedLatitude!.toStringAsFixed(4)}, ${_selectedLongitude!.toStringAsFixed(4)}'
                        : 'No definidas',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue),
            ),
            child: const Text(
              'Después de completar tu perfil, podrás crear paquetes/servicios para que los clientes puedan encontrarte y solicitar tus servicios.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: const Text('Anterior'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_currentStep < 2) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _completeSetup();
                      }
                    },
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _currentStep < 2 ? 'Siguiente' : 'Completar Setup',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
