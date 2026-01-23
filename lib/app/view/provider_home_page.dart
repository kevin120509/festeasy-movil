import 'dart:io';

import 'package:festeasy/app/view/provider_paquete_detail_page.dart';
import 'package:festeasy/app/view/provider_setup_page.dart';
import 'package:festeasy/app/view/provider_solicitudes_page.dart';
import 'package:festeasy/services/auth_service.dart';
import 'package:festeasy/services/provider_paquetes_service.dart';
import 'package:festeasy/services/provider_perfil_service.dart';
import 'package:festeasy/services/provider_solicitudes_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProviderHomePage extends StatefulWidget {
  const ProviderHomePage({super.key, this.userName = 'Proveedor'});
  final String userName;

  @override
  State<ProviderHomePage> createState() => _ProviderHomePageState();
}

class _ImagePreviewItem extends StatelessWidget {

  const _ImagePreviewItem({
    required this.image,
    required this.index,
    required this.onDelete,
  });
  final XFile image;
  final int index;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: 150,
                color: Colors.grey[200],
                child: Image.file(
                  File(image.path),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Error cargando',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: onDelete,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderHomePageState extends State<ProviderHomePage> {
  int _currentIndex = 0;
  ProviderPerfilData? _perfil;
  List<PaqueteProveedorData> _paquetes = [];
  List<ProviderSolicitudData> _solicitudes = [];
  bool _isLoadingPerfil = true;
  bool _isLoadingPaquetes = true;
  bool _isLoadingSolicitudes = true;

  @override
  void initState() {
    super.initState();
    _loadPerfil();
    _loadPaquetes();
    _loadSolicitudes();
  }

  Future<void> _loadPerfil() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user != null) {
        final perfil = await ProviderPerfilService.instance.getPerfilByUserId(
          user.id,
        );
        if (mounted) {
          setState(() {
            _perfil = perfil;
            _isLoadingPerfil = false;
          });
        }

        // Si no tiene perfil completo, mostrar setup
        if (perfil == null || !perfil.isCompleteProfile) {
          if (mounted) {
            final completed = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (context) => const ProviderSetupPage(),
              ),
            );
            if (completed ?? false) {
              _loadPerfil();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _loadPaquetes() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user != null) {
        final paquetes = await ProviderPaquetesService.instance
            .getPaquetesByProveedor(user.id);
        if (mounted) {
          setState(() {
            _paquetes = paquetes;
            _isLoadingPaquetes = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading paquetes: $e');
    }
  }

  Future<void> _loadSolicitudes() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user != null) {
        final solicitudes = await ProviderSolicitudesService.instance
            .getSolicitudesByEstado(user.id, 'pendiente_aprobacion');
        if (mounted) {
          setState(() {
            _solicitudes = solicitudes;
            _isLoadingSolicitudes = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading solicitudes: $e');
    }
  }

  /// Selecciona una foto de la galería o cámara
  Future<XFile?> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      return image;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Sube una foto a Supabase y retorna la URL
  Future<String?> _uploadPhotoToSupabase({
    required XFile imageFile,
    required String paqueteId,
  }) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return null;

      // Leer los bytes de la imagen
      final fileBytes = await imageFile.readAsBytes();

      // Subir a Supabase Storage
      final photoUrl = await ProviderPaquetesService.instance.uploadFotoPaquete(
        proveedorUsuarioId: user.id,
        paqueteId: paqueteId,
        fileBytes: fileBytes,
        fileName: '${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      return photoUrl;
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error subiendo foto: $e')));
      }
      return null;
    }
  }

  Future<void> _showCreatePaqueteDialog() async {
    final nombreController = TextEditingController();
    final descripcionController = TextEditingController();
    final precioController = TextEditingController();
    String? selectedCategoryId;
    var tipoCobro = 'fijo'; // 'fijo' o 'por_persona'
    var categorias = <Map<String, dynamic>>[];
    final fotosSeleccionadas = <XFile>[]; // Cambiar a XFile

    // Cargar categorías
    try {
      categorias = await ProviderPaquetesService.instance.getCategorias();
    } catch (e) {
      debugPrint('Error loading categorias: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Crear Nuevo Paquete'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Paquete',
                      hintText: 'Ej: Paquete Gold',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descripcionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Detalles del paquete...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                    ),
                    items: categorias
                        .map(
                          (cat) => DropdownMenuItem(
                            value: cat['id'] as String,
                            child: Text(cat['nombre'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => selectedCategoryId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Tipo de Cobro
                  Text(
                    'Tipo de Cobro',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('Precio Fijo'),
                        subtitle: const Text('Mismo precio para todos'),
                        value: 'fijo',
                        groupValue: tipoCobro,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setState(() => tipoCobro = value ?? 'fijo');
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Precio por Persona'),
                        subtitle: const Text(
                          'Multiplica por cantidad de personas',
                          overflow: TextOverflow.ellipsis,
                        ),
                        value: 'por_persona',
                        groupValue: tipoCobro,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setState(() => tipoCobro = value ?? 'fijo');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Precio
                  TextField(
                    controller: precioController,
                    decoration: InputDecoration(
                      labelText: tipoCobro == 'fijo'
                          ? 'Precio Total'
                          : 'Precio por Persona',
                      hintText: '0.00',
                      prefixText: r'$ ',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Fotos
                  Text(
                    'Fotos del Paquete',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (fotosSeleccionadas.isEmpty)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final image = await _pickImage();
                        if (image != null) {
                          setState(() {
                            fotosSeleccionadas.add(image);
                          });
                        }
                      },
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Agregar Foto'),
                    )
                  else
                    Column(
                      children: [
                        ...fotosSeleccionadas
                            .asMap()
                            .entries
                            .map(
                              (entry) => _ImagePreviewItem(
                                image: entry.value,
                                index: entry.key,
                                onDelete: () {
                                  setState(() {
                                    fotosSeleccionadas.removeAt(entry.key);
                                  });
                                },
                              ),
                            )
                            ,
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: fotosSeleccionadas.length < 5
                              ? () async {
                                  final image = await _pickImage();
                                  if (image != null) {
                                    setState(() {
                                      fotosSeleccionadas.add(image);
                                    });
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: Text(
                            'Agregar más (${fotosSeleccionadas.length}/5)',
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nombreController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El nombre es requerido')),
                  );
                  return;
                }

                if (selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Selecciona una categoría')),
                  );
                  return;
                }

                final precioBase = double.tryParse(precioController.text) ?? 0;

                try {
                  final user = AuthService.instance.currentUser;
                  if (user != null) {
                    // Crear el paquete primero
                    final paquete = await ProviderPaquetesService.instance
                        .createPaquete(
                          proveedorUsuarioId: user.id,
                          categoriaServicioId: selectedCategoryId!,
                          nombre: nombreController.text,
                          descripcion: descripcionController.text.isEmpty
                              ? null
                              : descripcionController.text,
                          precioBase: precioBase,
                          tipoCobro: tipoCobro,
                          fotos: [], // Fotos vacías por ahora
                        );

                    // Subir fotos si existen
                    final fotosUrls = <String>[];
                    if (fotosSeleccionadas.isNotEmpty) {
                      // Validar tamaño de archivos antes de subir
                      for (final foto in fotosSeleccionadas) {
                        final file = File(foto.path);
                        final fileSizeBytes = await file.length();
                        final fileSizeMB = fileSizeBytes / (1024 * 1024);

                        if (fileSizeMB > 5) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${foto.name} excede 5MB'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          throw Exception(
                            '${foto.name} excede el límite de 5MB',
                          );
                        }
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Subiendo fotos...'),
                            duration: Duration(seconds: 60),
                          ),
                        );
                      }

                      for (final foto in fotosSeleccionadas) {
                        final url = await _uploadPhotoToSupabase(
                          imageFile: foto,
                          paqueteId: paquete.id,
                        );
                        if (url != null) {
                          fotosUrls.add(url);
                        }
                      }

                      // Actualizar paquete con URLs de fotos
                      await ProviderPaquetesService.instance.updatePaquete(
                        paqueteId: paquete.id,
                        detallesJson: {
                          'tipoCobro': tipoCobro,
                          'fotos': fotosUrls,
                        },
                      );
                    }

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            fotosUrls.isNotEmpty
                                ? 'Paquete creado con ${fotosUrls.length} fotos'
                                : 'Paquete creado exitosamente',
                          ),
                        ),
                      );
                      _loadPaquetes();
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Negocio'),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.person),
            onSelected: (value) async {
              if (value == 'logout') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Cerrar Sesión'),
                    content: const Text(
                      '¿Estás seguro de que deseas cerrar sesión?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE01D25),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Cerrar Sesión',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
                if ((confirm ?? false) && mounted) {
                  await AuthService.instance.signOut();
                  if (mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Color(0xFFE01D25)),
                    SizedBox(width: 12),
                    Text('Cerrar Sesión'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboardTab(),
          _buildSolicitudesTab(),
          _buildPaquetesTab(),
          _buildCalendarioTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Inicio'),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Solicitudes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Paquetes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Calendario',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadPerfil(), _loadPaquetes(), _loadSolicitudes()]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBienvenida(),
              const SizedBox(height: 24),
              _buildEstadoNegocio(),
              const SizedBox(height: 24),
              _buildSeccionSolicitudes(),
              const SizedBox(height: 24),
              _buildSeccionPaquetes(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBienvenida() {
    if (_isLoadingPerfil) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_perfil == null) {
      return Card(
        color: Colors.orange[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange[700], size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Perfil Incompleto',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Completa tu perfil para que los clientes te encuentren',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final completed = await Navigator.of(context)
                            .push<bool>(
                              MaterialPageRoute(
                                builder: (context) => const ProviderSetupPage(),
                              ),
                            );
                        if (completed ?? false) {
                          _loadPerfil();
                        }
                      },
                      child: const Text('Completar Ahora'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¡Bienvenido, ${_perfil!.nombreNegocio}!',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Tipo de Suscripción: ${_perfil!.tipoSuscripcion.toUpperCase()}',
          style: TextStyle(
            color: _perfil!.tipoSuscripcion == 'plus'
                ? Colors.amber[700]
                : Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEstadoNegocio() {
    if (_perfil == null) {
      return const SizedBox();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado de tu Negocio',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  _perfil!.estado == 'active'
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: _perfil!.estado == 'active'
                      ? Colors.green
                      : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _perfil!.estado == 'active' ? 'Activo' : 'Bloqueado',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Tu perfil está ${_perfil!.estado == 'active' ? 'visible' : 'oculto'} para clientes',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.blue[600], size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cobertura: ${_perfil!.radioCoberturaKm} km',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _perfil!.direccionFormato ?? 'Ubicación no definida',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionSolicitudes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Solicitudes Pendientes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton(
              onPressed: () {
                setState(() => _currentIndex = 1);
              },
              child: const Text('Ver todas'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingSolicitudes)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_solicitudes.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No hay solicitudes pendientes',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Las solicitudes aparecerán aquí cuando los clientes te contacten',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: _solicitudes.take(3).map((solicitud) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(Icons.request_quote, color: Colors.blue[600]),
                  title: Text(
                    solicitud.tituloEvento ?? 'Solicitud',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Fecha: ${solicitud.fechaServicio.toString().split(' ')[0]}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    setState(() => _currentIndex = 1);
                  },
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSeccionPaquetes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tus Paquetes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton(
              onPressed: () {
                setState(() => _currentIndex = 2);
              },
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingPaquetes)
          const Center(child: CircularProgressIndicator())
        else if (_paquetes.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.inventory_2, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No tienes paquetes creados',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _currentIndex = 2);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Crear Paquete'),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: _paquetes.take(2).map((paquete) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(paquete.nombre),
                  subtitle: Text(
                    '\$${paquete.precioBase.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                  trailing: Chip(
                    label: Text(
                      paquete.estado,
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                    backgroundColor: paquete.isPublished
                        ? Colors.green
                        : paquete.isDraft
                        ? Colors.orange
                        : Colors.grey,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSolicitudesTab() {
    return ProviderSolicitudesPage(
      onSolicitudUpdated: () {
        setState(() {});
      },
    );
  }

  Widget _buildPaquetesTab() {
    if (_isLoadingPaquetes) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mis Paquetes',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            ElevatedButton.icon(
              onPressed: _showCreatePaqueteDialog,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_paquetes.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('No tienes paquetes creados'),
              ],
            ),
          )
        else
          Column(
            children: _paquetes.map((paquete) {
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ProviderPaqueteDetailPage(
                        paquete: paquete,
                        onPaqueteUpdated: () {
                          setState(_loadPaquetes);
                        },
                      ),
                    ),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    paquete.nombre,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${paquete.precioBase.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Chip(
                              label: Text(
                                paquete.estado,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: paquete.isPublished
                                  ? Colors.green
                                  : paquete.isDraft
                                  ? Colors.orange
                                  : Colors.grey,
                            ),
                          ],
                        ),
                        if (paquete.descripcion != null &&
                            paquete.descripcion!.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              Text(
                                paquete.descripcion!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        if (paquete.items != null && paquete.items!.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              Text(
                                '${paquete.items!.length} items incluidos',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.info, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Toca para ver detalles',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
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

  Widget _buildCalendarioTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Calendario de Eventos',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Próximamente podrás ver tu agenda aquí',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  void _showEditPaqueteDialog(PaqueteProveedorData paquete) {
    final nombreController = TextEditingController(text: paquete.nombre);
    final descriptionController = TextEditingController(
      text: paquete.descripcion,
    );
    final priceController = TextEditingController(
      text: paquete.precioBase.toString(),
    );
    var tipoCobroSelected = paquete.tipoCobro;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Paquete'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Precio Base'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: tipoCobroSelected,
                items: const [
                  DropdownMenuItem(value: 'fijo', child: Text('Precio Fijo')),
                  DropdownMenuItem(
                    value: 'por_persona',
                    child: Text('Por Persona'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) tipoCobroSelected = value;
                },
                decoration: const InputDecoration(labelText: 'Tipo de Cobro'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ProviderPaquetesService.instance.updatePaquete(
                  paqueteId: paquete.id,
                  nombre: nombreController.text,
                  descripcion: descriptionController.text,
                  precioBase: double.tryParse(priceController.text),
                  detallesJson: {
                    'tipoCobro': tipoCobroSelected,
                    'fotos': paquete.fotos,
                    ...?paquete.detallesJson,
                  },
                );

                if (mounted) {
                  Navigator.pop(context);
                  setState(_loadPaquetes);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Paquete actualizado'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showDeletePaqueteConfirm(PaqueteProveedorData paquete) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Paquete'),
        content: Text(
          '¿Estás seguro de que deseas eliminar el paquete "${paquete.nombre}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ProviderPaquetesService.instance.deletePaquete(
                  paquete.id,
                );

                if (mounted) {
                  Navigator.pop(context);
                  setState(_loadPaquetes);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Paquete eliminado'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
