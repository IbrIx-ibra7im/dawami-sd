import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Web implementation: captures the current frame from any active <video> element.
String? captureLiveWebCameraFrame() {
  try {
    final videoElements = web.document.querySelectorAll('video');
    for (int i = 0; i < videoElements.length; i++) {
      final node = videoElements.item(i);
      if (node != null && node.isA<web.HTMLVideoElement>()) {
        final video = node as web.HTMLVideoElement;
        final w = video.videoWidth;
        final h = video.videoHeight;
        if (w > 0 && h > 0) {
          final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
          canvas.width = w;
          canvas.height = h;
          final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
          if (ctx != null) {
            ctx.drawImage(video, 0, 0);
            final dataUrl = canvas.toDataURL('image/jpeg', 0.88.toJS);
            return dataUrl;
          }
        }
      }
    }
  } catch (_) {}
  return null;
}
