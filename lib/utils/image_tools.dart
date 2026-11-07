import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A black-and-white picture, packed 8 dots per byte (left dot = highest bit),
/// exactly the way thermal printers want it. 1 = black dot.
class MonoBitmap {
  final int width; // in dots, always a multiple of 8
  final int height;
  final Uint8List data; // (width / 8) * height bytes

  const MonoBitmap(this.width, this.height, this.data);

  int get bytesPerRow => width ~/ 8;

  bool isBlack(int x, int y) =>
      (data[y * bytesPerRow + (x >> 3)] & (0x80 >> (x & 7))) != 0;
}

/// Prepares a logo picked from the gallery so it can be saved and shared:
/// removes see-through parts, trims the empty white border, makes it
/// grey-scale and at most 576 dots wide (the full width of 80mm paper).
/// Returns PNG bytes, or null if the file is not a picture.
Uint8List? prepareLogo(Uint8List fileBytes) {
  final decoded = img.decodeImage(fileBytes);
  if (decoded == null) return null;
  var image = _flattenOnWhite(decoded);
  image = img.grayscale(image);
  image = _trimWhiteBorder(image);
  if (image.width > 576) {
    image = img.copyResize(
      image,
      width: 576,
      interpolation: img.Interpolation.average,
    );
  }
  return Uint8List.fromList(img.encodePng(image));
}

/// Turns a saved logo into printer dots, [widthDots] wide.
MonoBitmap logoToMono(
  Uint8List pngBytes,
  int widthDots, {
  int threshold = 170,
}) {
  final decoded = img.decodeImage(pngBytes);
  if (decoded == null) return MonoBitmap(0, 0, Uint8List(0));
  var image = img.grayscale(_flattenOnWhite(decoded));
  final width = (widthDots ~/ 8) * 8;
  if (image.width != width) {
    image = img.copyResize(
      image,
      width: width,
      interpolation: img.Interpolation.average,
    );
  }
  final height = image.height;
  final bytesPerRow = width ~/ 8;
  final data = Uint8List(bytesPerRow * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final lum = image.getPixel(x, y).luminance;
      if (lum < threshold) {
        data[y * bytesPerRow + (x >> 3)] |= 0x80 >> (x & 7);
      }
    }
  }
  return MonoBitmap(width, height, data);
}

/// A PNG showing exactly which dots the printer will burn (for previews).
Uint8List monoToPng(MonoBitmap m) {
  final out = img.Image(width: m.width, height: m.height);
  for (var y = 0; y < m.height; y++) {
    for (var x = 0; x < m.width; x++) {
      final v = m.isBlack(x, y) ? 0 : 255;
      out.setPixelRgb(x, y, v, v, v);
    }
  }
  return Uint8List.fromList(img.encodePng(out));
}

/// Small product photo (max 256 px) as a base64 JPEG, so it can be shared
/// with other phones. Returns null if the file is not a picture.
String? makeThumbnailBase64(Uint8List fileBytes) {
  final decoded = img.decodeImage(fileBytes);
  if (decoded == null) return null;
  var image = _flattenOnWhite(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > 256) {
    image = image.width >= image.height
        ? img.copyResize(
            image,
            width: 256,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            image,
            height: 256,
            interpolation: img.Interpolation.average,
          );
  }
  return base64Encode(img.encodeJpg(image, quality: 75));
}

img.Image _flattenOnWhite(img.Image src) {
  if (!src.hasAlpha) return src;
  final out = img.Image(width: src.width, height: src.height);
  img.fill(out, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(out, src);
  return out;
}

img.Image _trimWhiteBorder(img.Image src, {int whiteLevel = 235}) {
  var top = src.height, left = src.width, bottom = -1, right = -1;
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      if (src.getPixel(x, y).luminance < whiteLevel) {
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
  }
  if (bottom < 0) return src; // completely white
  const pad = 4;
  left = (left - pad).clamp(0, src.width - 1);
  top = (top - pad).clamp(0, src.height - 1);
  right = (right + pad).clamp(0, src.width - 1);
  bottom = (bottom + pad).clamp(0, src.height - 1);
  return img.copyCrop(
    src,
    x: left,
    y: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
}
