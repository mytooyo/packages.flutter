import 'dart:js_util';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:native_pdf_renderer/src/web/pdfjs.dart';
import 'package:native_pdf_renderer/src/web/resources/document_repository.dart';
import 'package:native_pdf_renderer/src/web/resources/page_repository.dart';

class NativePdfRendererPlugin {
  final _documents = DocumentRepository();
  final _pages = PageRepository();

  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'io.scer.pdf.renderer',
      const StandardMethodCodec(),
      registrar.messenger,
    );
    final instance = NativePdfRendererPlugin();
    channel.setMethodCallHandler(instance.onMethodCall);
  }

  Future<dynamic> onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'open.document.data':
        return openDocumentDataHandler(call);
      case 'open.document.file':
        return openDocumentFileHandler(call);
      case 'open.document.asset':
        return openDocumentAssetHandler(call);
      case 'open.page':
        return openPageHandler(call);
      case 'close.document':
        return closeDocumentHandler(call);
      case 'close.page':
        return closePageHandler(call);
      case 'render':
        return renderHandler(call);
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'The plugin for web doesn\'t implement '
              'the method \'${call.method}\'',
        );
    }
  }

  Future<Map<String, dynamic>> openDocumentDataHandler(MethodCall call) async {
    final args = call.arguments;
    final Uint8List data = args['data'];
    final bool cMapPacked = args['cMapPacked'];
    final String cMapUrl = args['cMapUrl'];

    final documentData = Uint8List.fromList(data);

    final settings = Settings()
      ..data = documentData
      ..cMapPacked = cMapPacked
      ..cMapUrl = cMapUrl;

    final documentLoader = PdfJs.getDocument(settings);
    final document = await promiseToFuture<PdfJsDoc>(documentLoader.promise);

    return _documents.register(document).infoMap;
  }

  Future<void> openDocumentFileHandler(MethodCall call) async {
    throw PlatformException(
        code: 'Unimplemented',
        details: 'The plugin for web doesn\'t implement '
            'the method \'${call.method}\'');
  }

  Future<Map<String, dynamic>> openDocumentAssetHandler(MethodCall call) async {
    final args = call.arguments;
    final String assetPath = args['name'];
    final bytes = await rootBundle.load(assetPath);
    return openDocumentDataHandler(MethodCall(
      'open.document.data',
      {
        'data': bytes.buffer.asUint8List(),
        'cMapPacked': args['cMapPacked'],
        'cMapUrl': args['cMapUrl'],
      },
    ));
  }

  Future<Map<String, dynamic>> openPageHandler(MethodCall call) async {
    final String documentId = call.arguments['documentId'];
    final int pageNumber = call.arguments['page'];
    final page = await _documents.get(documentId).openPage(pageNumber);
    return _pages.register(documentId, page).infoMap;
  }

  Future<bool> closeDocumentHandler(MethodCall call) async {
    final String id = call.arguments;
    _documents.close(id);
    return true;
  }

  Future<bool> closePageHandler(MethodCall call) async {
    final String id = call.arguments;
    _pages.close(id);
    return true;
  }

  Future<Map<String, dynamic>> renderHandler(MethodCall call) async {
    final String pageId = call.arguments['pageId'];
    final int width = call.arguments['width'];
    final int height = call.arguments['height'];

    final page = _pages.get(pageId);
    final result = await page.render(
      width: width,
      height: height,
    );

    return result.toMap;
  }
}
