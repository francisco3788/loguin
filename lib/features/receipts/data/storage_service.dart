import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class PdfSelectionCanceled implements Exception {
  const PdfSelectionCanceled();
}

class StorageService {
  StorageService(this._client);

  static const _bucket = 'my_receipts';
  static const _pdfContentType = 'application/pdf';

  final SupabaseClient _client;

  Future<void> uploadPdf() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('No hay usuario autenticado.');
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      throw const PdfSelectionCanceled();
    }

    final file = result.files.first;
    final fileBytes = file.bytes;

    if (fileBytes == null || fileBytes.isEmpty) {
      throw Exception('El archivo seleccionado no es valido.');
    }

    final path = '$userId/receipts/${const Uuid().v4()}.pdf';

    await _client.storage.from(_bucket).uploadBinary(
          path,
          fileBytes,
          fileOptions: const FileOptions(contentType: _pdfContentType),
        );
  }

  Future<List<FileObject>> listMyPdfs() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('No hay usuario autenticado.');
    }

    return _client.storage.from(_bucket).list(
          path: '$userId/receipts/',
          searchOptions: const SearchOptions(
            limit: 100,
            sortBy: SortBy(column: 'created_at', order: 'desc'),
          ),
        );
  }

  Future<String> signedUrl(String path) async {
    return _client.storage.from(_bucket).createSignedUrl(path, 120);
  }

  Future<void> deletePdf(String path) async {
    await _client.storage.from(_bucket).remove([path]);
  }
}
