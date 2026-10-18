import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../modules/dashboard/models/vehicle_model.dart' show scanBaseUrl;

/// One vehicle's sticker and how many copies to print.
class StickerPrint {
  const StickerPrint({required this.vehicleId, required this.plateNumber, this.copies = 1});

  final String vehicleId;
  final String plateNumber;
  final int copies;

  String get scanUrl => '$scanBaseUrl/scan/$vehicleId';
}

/// Builds printable QR stickers. Printed stickers carry only the plate,
/// never the order number or the owner's details.
class StickerPrinter {
  static const _stickerWidth = 85 * PdfPageFormat.mm;
  static const _stickerHeight = 110 * PdfPageFormat.mm;

  /// "QR Sticker - Owner name - Vehicle number"
  static String fileName(String ownerName, Iterable<String> plates) =>
      'QR Sticker - ${ownerName.trim()} - ${plates.join(', ')}'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');

  static Future<pw.MemoryImage> _logo() async =>
      pw.MemoryImage((await rootBundle.load('assets/Applogo.png')).buffer.asUint8List());

  static pw.Widget _sticker(StickerPrint sticker, pw.MemoryImage logo) {
    return pw.Container(
      width: _stickerWidth,
      height: _stickerHeight,
      padding: const pw.EdgeInsets.all(6 * PdfPageFormat.mm),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.black, width: 2 * PdfPageFormat.mm),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6 * PdfPageFormat.mm)),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.ClipRRect(
                horizontalRadius: 4,
                verticalRadius: 4,
                child: pw.Image(logo, width: 7 * PdfPageFormat.mm, height: 7 * PdfPageFormat.mm),
              ),
              pw.SizedBox(width: 2 * PdfPageFormat.mm),
              pw.Text('MoveMe', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Text(
            'Blocking you in? Scan to message the owner',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(errorCorrectLevel: pw.BarcodeQRCorrectionLevel.high),
            data: sticker.scanUrl,
            width: 58 * PdfPageFormat.mm,
            height: 58 * PdfPageFormat.mm,
            drawText: false,
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4 * PdfPageFormat.mm, vertical: 1.5 * PdfPageFormat.mm),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2 * PdfPageFormat.mm)),
            ),
            child: pw.Text(sticker.plateNumber, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Text('Your number stays private', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  /// Every sticker repeated by its [StickerPrint.copies], four to an A4 page.
  static Future<Uint8List> buildSheet(List<StickerPrint> stickers) async {
    final logo = await _logo();
    final all = [for (final s in stickers) for (var i = 0; i < s.copies; i++) s];
    final doc = pw.Document(title: 'MoveMe QR stickers');
    const perPage = 4;
    for (var start = 0; start < all.length; start += perPage) {
      final page = all.skip(start).take(perPage).toList();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(12 * PdfPageFormat.mm),
          build: (_) => pw.Wrap(
            spacing: 8 * PdfPageFormat.mm,
            runSpacing: 8 * PdfPageFormat.mm,
            children: [for (final s in page) _sticker(s, logo)],
          ),
        ),
      );
    }
    return doc.save();
  }

  /// One sticker as a 300 dpi PNG.
  static Future<Uint8List> buildImage(StickerPrint sticker) async {
    final logo = await _logo();
    final doc = pw.Document()
      ..addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(_stickerWidth, _stickerHeight),
          margin: pw.EdgeInsets.zero,
          build: (_) => _sticker(sticker, logo),
        ),
      );
    final raster = await Printing.raster(await doc.save(), dpi: 300).first;
    return raster.toPng();
  }

  static Future<void> printStickers(List<StickerPrint> stickers, {required String name}) async {
    final bytes = await buildSheet(stickers);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
  }

  static Future<void> sharePdf(List<StickerPrint> stickers, {required String name}) async {
    await Printing.sharePdf(bytes: await buildSheet(stickers), filename: '$name.pdf');
  }

  static Future<void> shareImage(StickerPrint sticker, {required String name}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name.png');
    await file.writeAsBytes(await buildImage(sticker));
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: name));
  }
}
