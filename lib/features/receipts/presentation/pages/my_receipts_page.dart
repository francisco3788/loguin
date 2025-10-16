import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/storage_service.dart';

class MyReceiptsPage extends StatefulWidget {
  const MyReceiptsPage({super.key});

  @override
  State<MyReceiptsPage> createState() => _MyReceiptsPageState();
}

class _MyReceiptsPageState extends State<MyReceiptsPage> {
  late Future<List<FileObject>> _receiptsFuture;
  bool _isUploading = false;
  bool _isProcessingAction = false;
  String? _lastErrorMessage;

  StorageService get _storage => context.read<StorageService>();

  @override
  void initState() {
    super.initState();
    _receiptsFuture = _loadReceipts();
  }

  Future<List<FileObject>> _loadReceipts() {
    return _storage.listMyPdfs().then((value) {
      _lastErrorMessage = null;
      return value;
    }).catchError((error, _) {
      final message =
          _mapError(error) ?? 'No se pudo cargar la lista de recibos.';
      if (_lastErrorMessage != message) {
        _showSnack(message, isError: true);
        _lastErrorMessage = message;
      }
      throw error;
    });
  }

  Future<void> _refreshReceipts() async {
    final future = _loadReceipts();
    setState(() {
      _receiptsFuture = future;
    });
    await future;
  }

  Future<void> _handleUpload() async {
    setState(() => _isUploading = true);
    try {
      await _storage.uploadPdf();
      await _refreshReceipts();
      _showSnack('PDF subido correctamente.');
    } on PdfSelectionCanceled {
      // El usuario cancelo la seleccion.
    } on Exception catch (error) {
      final message = _mapError(error);
      if (message != null) {
        _showSnack(message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _handleDownload(FileObject file) async {
    setState(() => _isProcessingAction = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No hay usuario autenticado.');
      }
      final path = '$userId/receipts/${file.name}';
      final url = await _storage.signedUrl(path);
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!launched) {
        throw Exception('No se pudo abrir el enlace de descarga.');
      }
    } on Exception catch (error) {
      final message = _mapError(error) ?? 'No se pudo descargar el PDF.';
      _showSnack(message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  Future<void> _handleDelete(FileObject file) async {
    setState(() => _isProcessingAction = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No hay usuario autenticado.');
      }
      final path = '$userId/receipts/${file.name}';
      await _storage.deletePdf(path);
      await _refreshReceipts();
      _showSnack('PDF eliminado.');
    } on Exception catch (error) {
      final message = _mapError(error);
      if (message != null) {
        _showSnack(message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  String? _mapError(Object? error) {
    if (error == null) {
      return null;
    }
    if (error is StorageException) {
      return error.message;
    }
    return error.toString();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Recibos'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_isUploading || _isProcessingAction) ? null : _handleUpload,
        icon: _isUploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.upload_file),
        label: Text(_isUploading ? 'Subiendo...' : 'Subir PDF'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF6F1FF),
              Color(0xFFE8DBFF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FutureBuilder<List<FileObject>>(
              future: _receiptsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return _ErrorState(
                    onRetry: () {
                      _refreshReceipts();
                    },
                  );
                }

                final files = snapshot.data ?? <FileObject>[];

                if (files.isEmpty) {
                  return const _EmptyState();
                }

                return _ReceiptsList(
                  files: files,
                  isBusy: _isProcessingAction,
                  onDownload: _handleDownload,
                  onDelete: _handleDelete,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptsList extends StatelessWidget {
  const _ReceiptsList({
    required this.files,
    required this.isBusy,
    required this.onDownload,
    required this.onDelete,
  });

  final List<FileObject> files;
  final bool isBusy;
  final ValueChanged<FileObject> onDownload;
  final ValueChanged<FileObject> onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ListView.separated(
          itemCount: files.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final file = files[index];
            return _ReceiptTile(
              file: file,
              isBusy: isBusy,
              onDownload: onDownload,
              onDelete: onDelete,
            );
          },
        ),
      ),
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({
    required this.file,
    required this.isBusy,
    required this.onDownload,
    required this.onDelete,
  });

  final FileObject file;
  final bool isBusy;
  final ValueChanged<FileObject> onDownload;
  final ValueChanged<FileObject> onDelete;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[];

    final createdAt = file.createdAt;
    if (createdAt != null) {
      final parsed = DateTime.tryParse(createdAt);
      if (parsed != null) {
        final local = parsed.toLocal();
        subtitleParts.add(
          'Subido el ${_twoDigits(local.day)}/${_twoDigits(local.month)}/${local.year} ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}',
        );
      }
    }

    final metadata = file.metadata;
    final size = metadata?['size'];
    if (size is num && size > 0) {
      subtitleParts.add(_formatBytes(size.toInt()));
    }

    final subtitle = subtitleParts.isEmpty ? null : subtitleParts.join(' | ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
      ),
      title: Text(file.name),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: Wrap(
        spacing: 12,
        children: [
          IconButton(
            tooltip: 'Descargar',
            onPressed: isBusy ? null : () => onDownload(file),
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: isBusy ? null : () => onDelete(file),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin recibos todavia',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Sube tus PDF para verlos aqui y acceder a descargas rapidas.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_outlined,
              size: 60,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'No pudimos cargar tus recibos',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            )
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  const suffixes = ['B', 'KB', 'MB', 'GB'];
  double size = bytes.toDouble();
  var suffixIndex = 0;
  while (size >= 1024 && suffixIndex < suffixes.length - 1) {
    size /= 1024;
    suffixIndex++;
  }
  return '${size.toStringAsFixed(size < 10 && suffixIndex > 0 ? 1 : 0)} ${suffixes[suffixIndex]}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');


