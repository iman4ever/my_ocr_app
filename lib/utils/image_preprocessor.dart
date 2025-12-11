import 'dart:io';
import 'package:image/image.dart' as img;

/// Simple preprocessing to improve OCR accuracy:
/// - convert to grayscale
/// - resize to a reasonable width while keeping aspect ratio
/// - apply a simple adaptive-like threshold (global for now)
Future<File> preprocessForOcr(File inputFile) async {
  final bytes = await inputFile.readAsBytes();
  img.Image? image = img.decodeImage(bytes);
  if (image == null) return inputFile;

  // Convert to grayscale
  image = img.grayscale(image);

  // Resize if too large (maintain aspect ratio)
  const maxWidth = 1200;
  if (image.width > maxWidth) {
    final newHeight = (image.height * (maxWidth / image.width)).round();
    image = img.copyResize(image, width: maxWidth, height: newHeight);
  }

  // Simple global thresholding to increase contrast
  // Compute average luminance and use as threshold
  int sum = 0;
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final dynamic pixel = image.getPixel(x, y);
      int r;
      if (pixel is int) {
        r = (pixel >> 16) & 0xFF;
      } else if (pixel is img.Pixel) {
        r = pixel.r.toInt();
      } else {
        // Fallback: attempt to convert to int
        final int p = pixel as int;
        r = (p >> 16) & 0xFF;
      }
      // image is already grayscale so r==g==b, use r
      sum += r;
    }
  }
  final avg = (sum / (image.width * image.height)).round();
  final threshold = (avg * 0.95).clamp(0, 255).toInt();

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final dynamic pixel = image.getPixel(x, y);
      int r;
      if (pixel is int) {
        r = (pixel >> 16) & 0xFF;
      } else if (pixel is img.Pixel) {
        r = pixel.r.toInt();
      } else {
        final int p = pixel as int;
        r = (p >> 16) & 0xFF;
      }
      final int v = (r > threshold) ? 255 : 0;
      // Use setPixelRgba with explicit alpha (some versions require alpha arg)
      image.setPixelRgba(x, y, v, v, v, 255);
    }
  }

  final outBytes = img.encodePng(image);
  final outFile = File('${inputFile.path}_preprocessed.png');
  await outFile.writeAsBytes(outBytes);
  return outFile;
}
