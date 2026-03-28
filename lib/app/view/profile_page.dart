import 'dart:typed_data';

import 'package:festeasy/app/view/login_page.dart';
import 'package:festeasy/services/auth_service.dart';
import 'package:festeasy/services/client_perfil_service.dart';
import 'package:festeasy/services/client_direcciones_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  bool _isSaving = false;
  ClientPerfilData? _perfil;

  late TextEditingController _nombreController;
  late TextEditingController _telefonoController;

  XFile? _nuevaFoto;

  List<Map<String, String>> _direcciones = [];

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController();
    _telefonoController = TextEditingController();
    _loadPerfil();
  }

  Future<void> _loadPerfil() async {
    setState(() => _isLoading = true);
    try {
      final user = AuthService.instance.currentUser;
      if (user != null) {
        final config = await Future.wait([
          ClientPerfilService.instance.getPerfil(user.id),
          ClientDireccionesService.instance.loadDirecciones(),
        ]);

        final perfil = config[0] as ClientPerfilData?;
        final dirs = config[1] as List<Map<String, String>>;

        if (mounted) {
          setState(() {
            _direcciones = dirs;
            if (perfil != null) {
              _perfil = perfil;
              _nombreController.text = perfil.nombreCompleto;
              _telefonoController.text = perfil.telefono ?? '';
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading client profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas salir?'),
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

    if (confirm != true) return;

    try {
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cerrar sesión: $e')));
    }
  }

  Future<void> _guardarCambios() async {
    if (_perfil == null) return;

    // Validar
    if (_nombreController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre no puede estar vacío'),
          backgroundColor: const Color(0xFF8D72C2),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? newAvatarUrl = _perfil!.avatarUrl;

      // Subir nueva foto si se seleccionó una
      if (_nuevaFoto != null) {
        final bytes = await _nuevaFoto!.readAsBytes();
        newAvatarUrl = await ClientPerfilService.instance.uploadAvatar(
          usuarioId: AuthService.instance.currentUser!.id,
          fileBytes: bytes,
          fileName:
              'avatar_cliente_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      await ClientPerfilService.instance.updatePerfil(
        perfilId: _perfil!.id,
        nombreCompleto: _nombreController.text.trim(),
        telefono: _telefonoController.text.trim().isEmpty
            ? null
            : _telefonoController.text.trim(),
        avatarUrl: newAvatarUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPerfil(); // Recargar
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error guardando cambios: $e'),
            backgroundColor: const Color(0xFF8D72C2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _seleccionarFoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 80,
    );
    if (file != null) {
      setState(() => _nuevaFoto = file);
    }
  }

  void _addOrEditAddress([int? index]) {
    final tituloCtrl = TextEditingController(
      text: index != null ? _direcciones[index]['titulo'] : '',
    );
    final direCtrl = TextEditingController(
      text: index != null ? _direcciones[index]['direccion'] : '',
    );

    bool isLocating = false;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                index == null ? 'Nueva Dirección' : 'Editar Dirección',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: tituloCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Título (Ej. Casa)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: direCtrl,
                    decoration: InputDecoration(
                      labelText: 'Dirección completa',
                      border: const OutlineInputBorder(),
                      suffixIcon: isLocating
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.my_location,
                                color: Color(0xFF8D72C2),
                              ),
                              tooltip: 'Usar ubicación actual',
                              onPressed: () async {
                                setDialogState(() => isLocating = true);
                                try {
                                  final perm =
                                      await Geolocator.checkPermission();
                                  if (perm == LocationPermission.denied) {
                                    final newPerm =
                                        await Geolocator.requestPermission();
                                    if (newPerm == LocationPermission.denied) {
                                      setDialogState(() => isLocating = false);
                                      return;
                                    }
                                  }
                                  final pos =
                                      await Geolocator.getCurrentPosition(
                                        desiredAccuracy: LocationAccuracy.high,
                                      );
                                  final placemarks =
                                      await placemarkFromCoordinates(
                                        pos.latitude,
                                        pos.longitude,
                                      );
                                  if (placemarks.isNotEmpty) {
                                    final p = placemarks.first;
                                    direCtrl.text =
                                        '${p.street} ${p.subLocality}, ${p.locality}, ${p.administrativeArea}'
                                            .trim()
                                            .replaceAll(RegExp(r'\s+'), ' ');
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error obteniendo ubicación: $e',
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  setDialogState(() => isLocating = false);
                                }
                              },
                            ),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8D72C2),
                  ),
                  onPressed: () async {
                    if (tituloCtrl.text.trim().isEmpty ||
                        direCtrl.text.trim().isEmpty)
                      return;
                    setState(() {
                      if (index == null) {
                        _direcciones.add({
                          'titulo': tituloCtrl.text.trim(),
                          'direccion': direCtrl.text.trim(),
                        });
                      } else {
                        _direcciones[index] = {
                          'titulo': tituloCtrl.text.trim(),
                          'direccion': direCtrl.text.trim(),
                        };
                      }
                    });
                    // Save persistently
                    await ClientDireccionesService.instance.saveDirecciones(
                      _direcciones,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text(
                    'Guardar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFF),
      appBar: AppBar(
        title: const Text(
          'Mi Perfil',
          style: TextStyle(
            color: Color(0xFF010302),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D72C2)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Información Personal',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Foto
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[200],
                            border: Border.all(
                              color: const Color(0xFF8D72C2),
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: _nuevaFoto != null
                                ? FutureBuilder<Uint8List>(
                                    future: _nuevaFoto!.readAsBytes(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData)
                                        return Image.memory(
                                          snapshot.data!,
                                          fit: BoxFit.cover,
                                        );
                                      return const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.grey,
                                      );
                                    },
                                  )
                                : (_perfil?.avatarUrl != null
                                      ? Image.network(
                                          _perfil!.avatarUrl!,
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.grey,
                                        )),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isSaving ? null : _seleccionarFoto,
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
                  ),
                  const SizedBox(height: 24),

                  // Campos Personales
                  TextField(
                    controller: _nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre Completo',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    enabled: !_isSaving,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _telefonoController,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                    enabled: !_isSaving,
                  ),
                  const SizedBox(height: 32),

                  // Direcciones Guardadas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Direcciones Guardadas',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: _isSaving ? null : () => _addOrEditAddress(),
                        icon: const Icon(
                          Icons.add_circle,
                          color: Color(0xFF8D72C2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_direcciones.isEmpty)
                    const Text(
                      'No tienes direcciones guardadas.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    ..._direcciones.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final dir = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        color: Colors.white,
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF0E6FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFF8D72C2),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            dir['titulo']!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(dir['direccion']!),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                onPressed: _isSaving
                                    ? null
                                    : () => _addOrEditAddress(idx),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: const Color(0xFF8D72C2),
                                  size: 20,
                                ),
                                onPressed: _isSaving
                                    ? null
                                    : () async {
                                        setState(
                                          () => _direcciones.removeAt(idx),
                                        );
                                        await ClientDireccionesService.instance
                                            .saveDirecciones(_direcciones);
                                      },
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),

                  const SizedBox(height: 48),

                  // Botones de acción finales
                  if (_isSaving)
                    const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF8D72C2),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _guardarCambios,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8D72C2),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Guardar Cambios',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  // Solo recargar para restaurar valores
                                  _loadPerfil();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Cambios cancelados'),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(color: Colors.grey.shade400),
                                ),
                                child: const Text(
                                  'Cancelar',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _signOut,
                                icon: const Icon(
                                  Icons.logout,
                                  color: const Color(0xFF8D72C2),
                                ),
                                label: const Text(
                                  'Cerrar Sesión',
                                  style: TextStyle(
                                    color: const Color(0xFF8D72C2),
                                    fontSize: 16,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: const BorderSide(color: const Color(0xFF8D72C2)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}
