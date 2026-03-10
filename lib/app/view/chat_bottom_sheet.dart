import 'package:festeasy/app/view/provider_solicitud_detail_page.dart'
    as festeasy_provider;
import 'package:festeasy/app/view/request_status_page.dart' as festeasy_client;
import 'package:festeasy/services/provider_solicitudes_service.dart'
    as festeasy_service;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatBottomSheet extends StatefulWidget {
  const ChatBottomSheet({
    required this.solicitudId,
    required this.clienteNombre,
    required this.isProvider,
    this.clienteAvatarUrl,
    super.key,
  });

  final String solicitudId;
  final String clienteNombre;
  final String? clienteAvatarUrl;
  final bool isProvider;

  @override
  State<ChatBottomSheet> createState() => _ChatBottomSheetState();
}

class _ChatBottomSheetState extends State<ChatBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final SupabaseClient _client = Supabase.instance.client;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _listenRealtime();
  }

  Future<void> _loadMessages() async {
    try {
      final response = await _client
          .from('mensajes_solicitud')
          .select()
          .eq('solicitud_id', widget.solicitudId)
          .order('creado_en', ascending: true);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Error cargando mensajes: $e');
    }
  }

  void _listenRealtime() {
    _client
        .channel('public:mensajes_solicitud')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mensajes_solicitud',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'solicitud_id',
            value: widget.solicitudId,
          ),
          callback: (payload) {
            if (mounted) {
              setState(() {
                _messages.add(payload.newRecord);
              });
            }
          },
        )
        .subscribe();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final myMsg = {
        'solicitud_id': widget.solicitudId,
        'emisor_usuario_id': myId,
        'mensaje': text,
        'creado_en': DateTime.now().toUtc().toIso8601String(),
        'leido': false,
      };

      // Intentar enviar a BD, si falla, al menos lo mostramos en local
      // para no romper la app
      await _client.from('mensajes_solicitud').insert(myMsg);
    } catch (e) {
      debugPrint('Error enviando: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo enviar el mensaje, '
              'verifica que la tabla exista.',
            ),
          ),
        );
      }
    }
  }

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0 && now.day == date.day) {
      return 'Hoy';
    } else if (difference.inDays == 1 ||
        (difference.inDays == 0 && now.day != date.day)) {
      return 'Ayer';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = _client.auth.currentUser?.id;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: widget.clienteAvatarUrl != null
                      ? NetworkImage(widget.clienteAvatarUrl!)
                      : null,
                  child: widget.clienteAvatarUrl == null
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.clienteNombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF010302),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          if (widget.isProvider) {
                            final data = await festeasy_service
                                .ProviderSolicitudesService
                                .instance
                                .getSolicitudById(widget.solicitudId);
                            if (data != null && context.mounted) {
                              Navigator.of(context).pop();
                              await Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      festeasy_provider.ProviderSolicitudDetailPage(
                                        solicitud: data,
                                      ),
                                ),
                              );
                            }
                          } else {
                            Navigator.of(context).pop();
                            await Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    festeasy_client.RequestStatusPage(
                                      solicitudId: widget.solicitudId,
                                    ),
                              ),
                            );
                          }
                        },
                        child: const Row(
                          children: [
                            Icon(
                              Icons.description,
                              color: Colors.blue,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Ver detalles de solicitud',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 13,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Messages Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aún no hay mensajes.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Text(
                        '¡Inicia la conversación para negociar detalles!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['emisor_usuario_id'] == myId;
                      final date = DateTime.parse(
                        msg['creado_en'] as String,
                      ).toLocal();

                      bool showDate = false;
                      if (index == 0) {
                        showDate = true;
                      } else {
                        final prevMsg = _messages[index - 1];
                        final prevDate = DateTime.parse(
                          prevMsg['creado_en'] as String,
                        ).toLocal();
                        if (date.day != prevDate.day ||
                            date.month != prevDate.month ||
                            date.year != prevDate.year) {
                          showDate = true;
                        }
                      }

                      Widget messageBubble = Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? const Color(0xFFE01D25)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isMe
                                  ? Radius.zero
                                  : const Radius.circular(16),
                              bottomLeft: isMe
                                  ? const Radius.circular(16)
                                  : Radius.zero,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                (msg['mensaje'] as String?) ?? '',
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('HH:mm').format(date),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );

                      if (showDate) {
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatDateSeparator(date),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            messageBubble,
                          ],
                        );
                      }
                      return messageBubble;
                    },
                  ),
          ),
          // Input Area
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Mensaje...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFFE01D25),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _client.channel('public:mensajes_solicitud').unsubscribe();
    super.dispose();
  }
}
