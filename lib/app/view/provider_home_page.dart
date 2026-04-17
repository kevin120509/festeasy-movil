import 'dart:io';
import 'package:flutter/services.dart';

import 'package:festeasy/app/view/chat_list_page.dart';
import 'package:festeasy/app/view/login_page.dart';
import 'package:festeasy/app/view/mis_eventos_page.dart';
import 'package:festeasy/app/view/producto_card.dart';
import 'package:festeasy/app/view/producto_form_dialog.dart';
import 'package:festeasy/app/view/provider_paquete_detail_page.dart';
import 'package:festeasy/app/view/provider_calendar_screen.dart';
import 'package:festeasy/app/view/provider_notifications_page.dart';
import 'package:festeasy/app/view/provider_setup_page.dart';
import 'package:festeasy/app/view/provider_solicitudes_page.dart';
import 'package:festeasy/services/auth_service.dart';
import 'package:festeasy/services/provider_inventario_service.dart';
import 'package:festeasy/services/provider_paquetes_service.dart';
import 'package:festeasy/services/provider_perfil_service.dart';
import 'package:festeasy/services/provider_solicitudes_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:festeasy/app/view/provider_finanzas_page.dart';

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
                    icon: const Icon(Icons.delete, color: const Color(0xFF8D72C2), size: 20),
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
  List<ProductoInventarioData> _productos = [];
  FiltroInventario _filtroActual = FiltroInventario.todos;
  FiltroInventario _filtroPaquetes = FiltroInventario.todos;
  bool _isLoadingPerfil = true;
  bool _isLoadingPaquetes = true;
  bool _isLoadingSolicitudes = true;
  bool _isLoadingProductos = true;

  @override
  void initState() {
    super.initState();
    _loadPerfil();
    _loadPaquetes();
    _loadSolicitudes();
    _loadProductos();
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

  Future<void> _loadProductos() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user != null) {
        final productos = await ProviderInventarioService.instance.getProductos(
          user.id,
        );
        if (mounted) {
          setState(() {
            _productos = productos;
            _isLoadingProductos = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading productos: $e');
      if (mounted) {
        setState(() => _isLoadingProductos = false);
      }
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
  /// Estructura sincronizada con web: packages/{userId}-{timestamp}-{random}.{ext}
  Future<String?> _uploadPhotoToSupabase({required XFile imageFile}) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return null;

      // Leer los bytes de la imagen
      final fileBytes = await imageFile.readAsBytes();

      // Subir a Supabase Storage (estructura sincronizada con web)
      final photoUrl = await ProviderPaquetesService.instance.uploadFotoPaquete(
        proveedorUsuarioId: user.id,
        fileBytes: fileBytes,
        fileName: imageFile.name,
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
    final stockController = TextEditingController(text: '0');
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
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                    ),
                    items: categorias
                        .map(
                          (cat) => DropdownMenuItem(
                            value: cat['id'] as String,
                            child: Text(
                              cat['nombre'] as String,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                  const SizedBox(height: 12),
                  // Stock Disponible
                  TextField(
                    controller: stockController,
                    decoration: const InputDecoration(
                      labelText: 'Stock Disponible',
                      hintText: 'Ej: 10',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
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
                        ...fotosSeleccionadas.asMap().entries.map(
                          (entry) => _ImagePreviewItem(
                            image: entry.value,
                            index: entry.key,
                            onDelete: () {
                              setState(() {
                                fotosSeleccionadas.removeAt(entry.key);
                              });
                            },
                          ),
                        ),
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
                          stock: int.tryParse(stockController.text) ?? 0,
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
                                backgroundColor: const Color(0xFF8D72C2),
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

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar aplicación'),
        content: const Text('¿Estás seguro de que quieres salir de FestEasy?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8D72C2),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmation();
        if (shouldPop && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FFFF),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF010302),
          title: const Text(
            'Mi Negocio',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF010302),
            ),
          ),
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(
                Icons.chat_bubble_outline,
                color: Color(0xFF8D72C2),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ChatListPage(isProvider: true),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.notifications, color: Color(0xFF8D72C2)),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ProviderNotificationsPage(),
                  ),
                );
              },
            ),
            IconButton(
              icon: _perfil?.avatarUrl != null
                  ? CircleAvatar(
                      backgroundImage: NetworkImage(_perfil!.avatarUrl!),
                      radius: 16,
                    )
                  : const Icon(Icons.person, color: Color(0xFF8D72C2)),
              onPressed: () {
                if (_perfil != null) {
                  _showAjustesDialog();
                }
              },
            ),
          ],
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildDashboardTab(),
            _buildSolicitudesTab(),
            _buildInventarioTab(),
            _buildPaquetesTab(),
            _buildCalendarioTab(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF8D72C2),
            unselectedItemColor: Colors.grey,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'Inicio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.assignment),
                label: 'Solicitudes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2),
                label: 'Inventario',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shopping_bag),
                label: 'Paquetes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month),
                label: 'Calendario',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAjustesDialog() async {
    if (_perfil == null) return;

    final nombreController = TextEditingController(
      text: _perfil!.nombreNegocio,
    );
    final descripcionController = TextEditingController(
      text: _perfil!.descripcion ?? '',
    );
    final telefonoController = TextEditingController(
      text: _perfil!.telefono ?? '',
    );
    final correoController = TextEditingController(
      text: _perfil!.correoElectronico ?? '',
    );

    XFile? nuevaFoto;
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Ajustes de Perfil'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: nuevaFoto != null
                              ? FileImage(File(nuevaFoto!.path))
                                    as ImageProvider
                              : (_perfil!.avatarUrl != null
                                    ? NetworkImage(_perfil!.avatarUrl!)
                                    : null),
                          child: nuevaFoto == null && _perfil!.avatarUrl == null
                              ? const Icon(
                                  Icons.store,
                                  size: 50,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () async {
                              final image = await _pickImage();
                              if (image != null) {
                                setDialogState(() => nuevaFoto = image);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF8D72C2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Negocio',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descripcionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: telefonoController,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono de Contacto',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: correoController,
                      decoration: const InputDecoration(
                        labelText: 'Correo de Contacto',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF8D72C2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
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
                                  backgroundColor: const Color(0xFF8D72C2),
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
                        if (confirm ?? false) {
                          await AuthService.instance.signOut();
                          if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute<void>(
                                builder: (context) => const LoginPage(),
                              ),
                              (route) => false,
                            );
                          }
                        }
                      },
                child: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(color: const Color(0xFF8D72C2)),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: isLoading ? null : () => Navigator.pop(context),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8D72C2),
                    ),
                    onPressed: isLoading
                        ? null
                        : () async {
                            setDialogState(() => isLoading = true);
                            try {
                              String? newAvatarUrl = _perfil!.avatarUrl;
                              if (nuevaFoto != null) {
                                final bytes = await nuevaFoto!.readAsBytes();
                                newAvatarUrl = await ProviderPerfilService
                                    .instance
                                    .uploadAvatar(
                                      usuarioId:
                                          AuthService.instance.currentUser!.id,
                                      fileBytes: bytes,
                                      fileName:
                                          'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
                                    );
                              }

                              await ProviderPerfilService.instance.updatePerfil(
                                perfilId: _perfil!.id,
                                nombreNegocio: nombreController.text.trim(),
                                descripcion:
                                    descripcionController.text.trim().isEmpty
                                    ? null
                                    : descripcionController.text.trim(),
                                telefono: telefonoController.text.trim().isEmpty
                                    ? null
                                    : telefonoController.text.trim(),
                                correoElectronico:
                                    correoController.text.trim().isEmpty
                                    ? null
                                    : correoController.text.trim(),
                                avatarUrl: newAvatarUrl,
                              );

                              if (mounted) {
                                Navigator.pop(context);
                                _loadPerfil();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Perfil actualizado excitosamente',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              setDialogState(() => isLoading = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: const Color(0xFF8D72C2),
                                  ),
                                );
                              }
                            }
                          },
                    child: const Text(
                      'Guardar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadPerfil(),
          _loadPaquetes(),
          _loadSolicitudes(),
          _loadProductos(),
        ]);
      },
      color: const Color(0xFF8D72C2),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
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
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D72C2)),
        ),
      );
    }

    if (_perfil == null) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF0E6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF8D72C2).withOpacity(0.3)),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFF8D72C2),
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Perfil Incompleto',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF010302),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Completa tu perfil para que los clientes te encuentren',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final completed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (context) => const ProviderSetupPage(),
                        ),
                      );
                      if (completed ?? false) {
                        _loadPerfil();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8D72C2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('Completar Ahora'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '¡Hola, ${_perfil!.nombreNegocio}! 👋',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF010302),
              ),
            ),
          ],
        ),

      ],
    );
  }

  Widget _buildEstadoNegocio() {
    if (_perfil == null) {
      return const SizedBox();
    }

    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estado de tu Negocio',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF010302),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _perfil!.estado == 'active'
                      ? Colors.green[50]
                      : const Color(0xFFF0E6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _perfil!.estado == 'active'
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: _perfil!.estado == 'active'
                      ? Colors.green
                      : const Color(0xFFFF0B0B),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _perfil!.estado == 'active' ? 'Activo' : 'Bloqueado',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF010302),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tu perfil está ${_perfil!.estado == 'active' ? 'visible' : 'oculto'} para clientes',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: const Color(0xFFF4F7F9)),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Color(0xFF8D72C2),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cobertura: ${_perfil!.radioCoberturaKm} km',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF010302),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _perfil!.direccionFormato ?? 'Ubicación no definida',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: const Color(0xFFF4F7F9)),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MisFinanzasPage(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Color(0xFF1EAD13),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mis Finanzas',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF010302),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ingresos, gastos y analíticas',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ],
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
            const Text(
              'Solicitudes Pendientes',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF010302),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _currentIndex = 1);
              },
              child: const Text(
                'Ver todas',
                style: TextStyle(color: Color(0xFF8D72C2)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingSolicitudes)
          Container(
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
            padding: const EdgeInsets.all(24),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D72C2)),
              ),
            ),
          )
        else if (_solicitudes.isEmpty)
          Container(
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
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7F9),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(Icons.inbox, size: 40, color: Colors.grey[400]),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No hay solicitudes pendientes',
                  style: TextStyle(
                    color: Color(0xFF010302),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Las solicitudes aparecerán aquí cuando los clientes te contacten',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          )
        else
          Column(
            children: _solicitudes.take(3).map((solicitud) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0E6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.request_quote,
                      color: Color(0xFF8D72C2),
                    ),
                  ),
                  title: Text(
                    solicitud.tituloEvento ?? 'Solicitud',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF010302),
                    ),
                  ),
                  subtitle: Text(
                    'Fecha: ${solicitud.fechaServicio.toString().split(' ')[0]}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Color(0xFF8D72C2),
                  ),
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
            const Text(
              'Tus Paquetes',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF010302),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _currentIndex = 2);
              },
              child: const Text(
                'Ver todos',
                style: TextStyle(color: Color(0xFF8D72C2)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingPaquetes)
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D72C2)),
            ),
          )
        else if (_paquetes.isEmpty)
          Container(
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
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7F9),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.inventory_2,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No tienes paquetes creados',
                  style: TextStyle(
                    color: Color(0xFF010302),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _currentIndex = 2);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Crear Paquete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8D72C2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: _paquetes.take(2).map((paquete) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0E6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.inventory_2,
                      color: Color(0xFF8D72C2),
                    ),
                  ),
                  title: Text(
                    paquete.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF010302),
                    ),
                  ),
                  subtitle: Text(
                    '\$${paquete.precioBase.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: paquete.isPublished
                          ? Colors.green[50]
                          : paquete.isDraft
                          ? Colors.orange[50]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      paquete.estado,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: paquete.isPublished
                            ? Colors.green[700]
                            : paquete.isDraft
                            ? Colors.orange[700]
                            : Colors.grey[700],
                      ),
                    ),
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

  Widget _buildInventarioTab() {
    return Column(
      children: [
        // ---------- SECCIÓN DE PAQUETES (TOP) ----------
        if (_paquetes.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tus Paquetes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF010302),
                  ),
                ),
              ],
            ),
          ),
        if (_paquetes.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 16), // Alineación exacta a la izquierda
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildFiltroPaquetesButton('Todos', FiltroInventario.todos),
                const SizedBox(width: 8),
                _buildFiltroPaquetesButton('Stock bajo', FiltroInventario.bajo),
                const SizedBox(width: 8),
                _buildFiltroPaquetesButton('Sin stock', FiltroInventario.agotado),
              ],
            ),
          ),
        if (_paquetes.isNotEmpty)
          SizedBox(
            height: 220, // Aumentado verticalmente
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: _paquetes.where((p) {
                if (_filtroPaquetes == FiltroInventario.todos) return true;
                if (_filtroPaquetes == FiltroInventario.bajo) return p.getEstadoStock() == 'stockBajo';
                if (_filtroPaquetes == FiltroInventario.agotado) return p.getEstadoStock() == 'sinStock';
                return true;
              }).length,
              itemBuilder: (context, index) {
                final filteredPaquetes = _paquetes.where((p) {
                  if (_filtroPaquetes == FiltroInventario.todos) return true;
                  if (_filtroPaquetes == FiltroInventario.bajo) return p.getEstadoStock() == 'stockBajo';
                  if (_filtroPaquetes == FiltroInventario.agotado) return p.getEstadoStock() == 'sinStock';
                  return true;
                }).toList();
                
                final paquete = filteredPaquetes[index];
                final estadoStockColor = paquete.getEstadoStock() == 'sinStock' ? const Color(0xFF8D72C2) : (paquete.getEstadoStock() == 'stockBajo' ? Colors.orange : Colors.green);
                final estadoStockLabel = paquete.getEstadoStock() == 'sinStock' ? 'SIN STOCK' : (paquete.getEstadoStock() == 'stockBajo' ? 'STOCK BAJO' : 'STOCK ALTO');

                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => ProviderPaqueteDetailPage(
                          paquete: paquete,
                          onPaqueteUpdated: _loadPaquetes,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 240,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PAQUETE',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: estadoStockColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                estadoStockLabel,
                                style: TextStyle(
                                  color: estadoStockColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          paquete.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF010302),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PRECIO',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '\$${paquete.precioBase.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF010302),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'STOCK',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  paquete.stock.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF00A878),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Botones de Editar y Eliminar
                        SizedBox(
                          height: 40,
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('Editar', style: TextStyle(fontSize: 12)),
                                  onPressed: () => _showEditPaqueteDialog(paquete),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 48,
                                child: OutlinedButton(
                                  onPressed: () => _showDeletePaqueteConfirm(paquete),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    foregroundColor: const Color(0xFF8D72C2),
                                    side: const BorderSide(color: Color(0xFF8D72C2)),
                                  ),
                                  child: const Icon(Icons.delete, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        
        // ---------- SECCIÓN DE PRODUCTOS (BOTTOM) ----------
        // Header con botones de filtro
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Todos los productos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF010302),
                    ),
                  ),
                  FloatingActionButton.extended(
                    onPressed: () async {
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (_) => const ProductoFormDialog(),
                      );
                      if (result ?? false) {
                        _loadProductos();
                      }
                    },
                    backgroundColor: const Color(0xFF8D72C2),
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Filtros
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFiltroButton('Todos', FiltroInventario.todos),
                    const SizedBox(width: 8),
                    _buildFiltroButton('Stock bajo', FiltroInventario.bajo),
                    const SizedBox(width: 8),
                    _buildFiltroButton('Sin stock', FiltroInventario.agotado),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Contenido
        Expanded(
          child: _isLoadingProductos
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF8D72C2),
                    ),
                  ),
                )
              : _productos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay productos',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (_) => const ProductoFormDialog(),
                          );
                          if (result ?? false) {
                            _loadProductos();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8D72C2),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Crear Producto'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProductos,
                  color: const Color(0xFF8D72C2),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: ProviderInventarioService.filtrarProductos(
                      _productos,
                      _filtroActual,
                    ).length,
                    itemBuilder: (context, index) {
                      final productos =
                          ProviderInventarioService.filtrarProductos(
                            _productos,
                            _filtroActual,
                          );
                      final producto = productos[index];

                      return ProductoCard(
                        producto: producto,
                        onEdit: () async {
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (_) =>
                                ProductoFormDialog(producto: producto),
                          );
                          if (result ?? false) {
                            _loadProductos();
                          }
                        },
                        onDelete: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Eliminar Producto'),
                              content: Text(
                                '¿Estás seguro de que deseas eliminar "${producto.nombre}"?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8D72C2),
                                  ),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    'Eliminar',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirm ?? false) {
                            try {
                              await ProviderInventarioService.instance
                                  .deleteProducto(producto.id);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '"${producto.nombre}" eliminado',
                                    ),
                                  ),
                                );
                                _loadProductos();
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: const Color(0xFF8D72C2),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        onToggleDestacado: (nuevoEstado) async {
                          try {
                            await ProviderInventarioService.instance
                                .toggleDestacado(producto.id, nuevoEstado);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    nuevoEstado
                                        ? '"${producto.nombre}" destacado'
                                        : '"${producto.nombre}" sin destacar',
                                  ),
                                ),
                              );
                              _loadProductos();
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: const Color(0xFF8D72C2),
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFiltroButton(String label, FiltroInventario filtro) {
    final isActive = _filtroActual == filtro;
    return FilterChip(
      label: Text(label),
      selected: isActive,
      onSelected: (selected) {
        setState(() => _filtroActual = filtro);
      },
      backgroundColor: Colors.grey[200],
      selectedColor: const Color(0xFF8D72C2),
      labelStyle: TextStyle(
        color: isActive ? Colors.white : Colors.black,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildFiltroPaquetesButton(String label, FiltroInventario filtro) {
    final isActive = _filtroPaquetes == filtro;
    return FilterChip(
      label: Text(label),
      selected: isActive,
      onSelected: (selected) {
        setState(() => _filtroPaquetes = filtro);
      },
      backgroundColor: Colors.grey[200],
      selectedColor: const Color(0xFF8D72C2),
      labelStyle: TextStyle(
        color: isActive ? Colors.white : Colors.black,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildPaquetesTab() {
    if (_isLoadingPaquetes) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D72C2)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mis Paquetes',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Color(0xFF010302),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _showCreatePaqueteDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nuevo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8D72C2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_paquetes.isEmpty)
          Container(
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
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7F9),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.inventory_2,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No tienes paquetes creados',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Color(0xFF010302),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Crea tu primer paquete para empezar a recibir solicitudes',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          )
        else
          Column(
            children: _paquetes.map((paquete) {
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) => ProviderPaqueteDetailPage(
                        paquete: paquete,
                        onPaqueteUpdated: _loadPaquetes,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
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
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0E6FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2,
                                      color: Color(0xFF8D72C2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          paquete.nombre,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: Color(0xFF010302),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '\$${paquete.precioBase.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: paquete.isPublished
                                    ? Colors.green[50]
                                    : paquete.isDraft
                                    ? Colors.orange[50]
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                paquete.estado,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: paquete.isPublished
                                      ? Colors.green[700]
                                      : paquete.isDraft
                                      ? Colors.orange[700]
                                      : Colors.grey[700],
                                ),
                              ),
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
                                  color: Colors.grey[600],
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${paquete.items!.length} items incluidos',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.touch_app,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Toca para ver detalles',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: const Color(0xFF8D72C2).withOpacity(0.6),
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
    return const ProviderCalendarScreen();
  }

  void _showEditPaqueteDialog(PaqueteProveedorData paquete) {
    final nombreController = TextEditingController(text: paquete.nombre);
    final descriptionController = TextEditingController(
      text: paquete.descripcion,
    );
    final priceController = TextEditingController(
      text: paquete.precioBase.toString(),
    );
    final stockController = TextEditingController(
      text: paquete.stock.toString(),
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
              TextField(
                controller: stockController,
                decoration: const InputDecoration(labelText: 'Stock Disponible'),
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
                    ...?paquete.detallesJson,
                    'tipoCobro': tipoCobroSelected,
                    'fotos': paquete.fotos,
                    'stock': int.tryParse(stockController.text) ?? 0,
                  },
                );

                if (mounted) {
                  Navigator.pop(context);
                  _loadPaquetes();
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
                  _loadPaquetes();
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8D72C2)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
