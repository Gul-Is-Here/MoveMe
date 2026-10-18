import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parktag_app/app/services/sticker_printer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('File names follow "QR Sticker - Owner name - Vehicle number"', () {
    expect(StickerPrinter.fileName('Ali Raza', ['LEA-2231']), 'QR Sticker - Ali Raza - LEA-2231');
    expect(StickerPrinter.fileName('Ali', ['LEA-2231', 'KHI/909']), 'QR Sticker - Ali - LEA-2231, KHI909');
  });

  test('Stickers point at the vehicle scan page', () {
    expect(
      const StickerPrint(vehicleId: 'abc', plateNumber: 'LEA-2231').scanUrl,
      'https://moveme-da262.web.app/scan/abc',
    );
  });

  test('A sheet repeats each sticker by its copies, four to a page', () async {
    final bytes = await StickerPrinter.buildSheet(const [
      StickerPrint(vehicleId: 'v1', plateNumber: 'LEA-2231', copies: 3),
      StickerPrint(vehicleId: 'v2', plateNumber: 'KHI-909', copies: 2),
    ]);
    final pdf = String.fromCharCodes(bytes);
    expect(pdf.startsWith('%PDF'), isTrue);
    // 5 stickers → 2 A4 pages.
    expect(RegExp(r'/Type\s*/Page\b').allMatches(pdf).length, 2);

    final out = Platform.environment['STICKER_PDF_OUT'];
    if (out != null) await File(out).writeAsBytes(bytes);
  });
}
