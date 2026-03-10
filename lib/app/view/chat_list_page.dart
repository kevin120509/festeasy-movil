import 'package:festeasy/app/view/chat_bottom_sheet.dart';
import 'package:festeasy/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({required this.isProvider, super.key});

  final bool isProvider;

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversaciones = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final data = await ChatService.instance.getConversaciones(
      usuarioId: userId,
      isProvider: widget.isProvider,
    );

    if (mounted) {
      setState(() {
        _conversaciones = data;
        _isLoading = false;
      });
    }
  }

  void _abrirChat(Map<String, dynamic> conversacion) {
    final baseName =
        (conversacion['nombre_contraparte'] as String?) ??
        (widget.isProvider ? 'Cliente' : 'Proveedor');
    final eventName =
        (((conversacion['solicitud'] as Map?) ?? {})['titulo_evento']
            as String?) ??
        'Evento';
    final name = '$baseName - $eventName';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatBottomSheet(
        solicitudId: conversacion['solicitud_id'] as String,
        clienteNombre: name,
        isProvider: widget.isProvider,
        clienteAvatarUrl: conversacion['avatar_contraparte'] as String?,
      ),
    ).then((_) {
      if (mounted) {
        _loadConversations();
      }
    });
  }

  String _formatFecha(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final date = DateTime.parse(isoDate).toLocal();
      final difference = DateTime.now().difference(date);
      if (difference.inDays == 0) {
        return DateFormat('HH:mm').format(date);
      } else if (difference.inDays == 1) {
        return 'Ayer';
      } else {
        return DateFormat('dd/MM/yyyy').format(date);
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFF),
      appBar: AppBar(
        title: const Text(
          'Mensajes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF010302),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF010302),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFE01D25)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversaciones.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No tienes conversaciones aún',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Aquí aparecerán tus chats cuando\n'
                    'inicies un proceso con un proveedor o cliente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadConversations,
              color: const Color(0xFFE01D25),
              child: ListView.separated(
                itemCount: _conversaciones.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 80, endIndent: 16),
                itemBuilder: (context, index) {
                  final conv = _conversaciones[index];
                  final avatar = conv['avatar_contraparte'] as String?;
                  final baseName =
                      (conv['nombre_contraparte'] as String?) ?? 'Usuario';
                  final eventName =
                      (((conv['solicitud'] as Map?) ?? {})['titulo_evento']
                          as String?) ??
                      'Evento';
                  final name = '$baseName - $eventName';

                  return InkWell(
                    onTap: () => _abrirChat(conv),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: avatar != null
                                    ? NetworkImage(avatar)
                                    : null,
                                child: avatar == null
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.grey,
                                        size: 30,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Color(0xFF010302),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      _formatFecha(
                                        conv['fecha_ultimo_mensaje'] as String?,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  (conv['ultimo_mensaje'] as String?) ??
                                      'Sin mensajes aún',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
    );
  }
}
