import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:clash_party/common/common.dart';
import 'package:clash_party/plugins/app.dart';
import 'package:clash_party/providers/action.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/activate_box.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// 扫码页认得的深链协议头。和 AndroidManifest 里 MainActivity 那三条
/// `<data android:scheme=.../>` 保持一致。
const _profileLinkSchemes = {'clash', 'clashmeta', 'clashparty'};

/// 深链里真正带订阅地址的那个 host，和 common/link.dart 的判断保持一致。
const _profileLinkHost = 'install-config';

/// 从二维码内容里解出「能直接拿去添加订阅的地址」，解不出来返回 null。
///
/// 这里刻意比原来宽：原先只认 [BarcodeType.url]，也就是完全依赖扫码库自己的
/// 归类。库把 `clash://install-config?url=...` 归成纯文本（它只认 http/https/www
/// 这类），于是最常见的一种订阅二维码会被当成「不认识」——扫了没反应。
///
/// 判定顺序：
/// 1. 本身就是 http / https / ftp 直链；
/// 2. 是 `clash://install-config?url=<订阅地址>` 这类深链，取出里面的地址；
/// 3. 兜底：扫码库判成 URL 的，原样交给下游（保持改动前的行为，不缩小范围）。
String? resolveScannedProfileUrl(
  String? rawValue, {
  bool isUrlBarcode = false,
}) {
  final value = rawValue?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  if (value.isUrl) {
    return value;
  }
  final uri = Uri.tryParse(value);
  if (uri != null &&
      _profileLinkSchemes.contains(uri.scheme.toLowerCase()) &&
      uri.host.toLowerCase() == _profileLinkHost) {
    final inner = uri.queryParameters['url']?.trim();
    if (inner != null && inner.isUrl) {
      return inner;
    }
  }
  if (isUrlBarcode) {
    return value;
  }
  return null;
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  StreamSubscription<Object?>? _subscription;

  bool _handled = false;

  /// 上一次提示「不认识」的时间。同一个码不会重复触发（noDuplicates），但镜头里
  /// 同时有好几个码时会接连回调，节流一下免得提示条排队刷屏。
  DateTime? _lastRejectedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = controller.barcodes.listen(_handleBarcode);
    unawaited(controller.start());
  }

  void _handleBarcode(BarcodeCapture barcodeCapture) {
    // The stream keeps emitting while the camera sees the code; popping
    // more than once would dismiss the page underneath too.
    if (_handled || !mounted) {
      return;
    }
    // 光有 _handled 挡不住另一条路：用户点右上角的 ✕（或按系统返回）之后，
    // 本页要花 300 毫秒（CommonRoute 的退场时长）才真正消失，这期间 State
    // 还挂着、相机还在扫、订阅也还在。此时若识别到一个码就会再 pop 一次，
    // 而正在退场的路由已经不算「当前路由」了，这一下弹掉的是**它下面那层**
    // ——用户会看到订阅页莫名其妙地一起关掉。
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) {
      return;
    }
    final barcode = barcodeCapture.barcodes.firstOrNull;
    if (barcode == null) {
      return;
    }
    final url = resolveScannedProfileUrl(
      barcode.rawValue,
      isUrlBarcode: barcode.type == BarcodeType.url,
    );
    if (url == null) {
      // 原来这里是直接 Navigator.pop(context)：页面一声不吭地关掉，用户看到的
      // 就是「扫了没反应」，分不清是没扫上、还是应用坏了。现在明确说一句，并且
      // 把页面留着让人接着扫下一个。
      _notifyUnrecognized();
      return;
    }
    _handled = true;
    Navigator.pop<String>(context, url);
  }

  void _notifyUnrecognized() {
    final now = DateTime.now();
    final last = _lastRejectedAt;
    if (last != null && now.difference(last) < const Duration(seconds: 3)) {
      return;
    }
    _lastRejectedAt = now;
    // 只说「这个码不能用」，**绝不回显扫到的内容**：二维码里往往就是带 token 的
    // 真实订阅地址，提示条会被截图、会被贴进 issue。
    context.showNotifier(context.appLocalizations.scanUnrecognizedTip);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
        // 先取消再订阅：resumed 不保证前面一定来过 inactive，直接叠一条订阅
        // 会让同一个码触发两次回调。
        unawaited(_subscription?.cancel());
        _subscription = controller.barcodes.listen(_handleBarcode);
        unawaited(controller.start());
      case AppLifecycleState.inactive:
        unawaited(_subscription?.cancel());
        _subscription = null;
        unawaited(controller.stop());
    }
  }

  /// 相机起不来时的兜底界面。库自带的那个是黑底 + 一个 Material 默认的红色感叹号
  /// 加一行英文错误码，用户看了既不知道发生了什么、也不知道该做什么。
  /// 最常见的情况是没给相机权限，所以这里直接给出「点击授权」的出口。
  Widget _buildError(BuildContext context, MobileScannerException error) {
    final colorScheme = context.colorScheme;
    final tokens = context.styleTokens;
    final isPermissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPermissionDenied
                    ? Icons.no_photography_outlined
                    : Icons.videocam_off_outlined,
                size: 48,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                error.errorCode.message,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (isPermissionDenied) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    app?.openAppSettings();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.accent(colorScheme),
                    foregroundColor: tokens.onAccent(colorScheme),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(tokens.controlRadius),
                    ),
                  ),
                  child: Text(context.appLocalizations.tapToAuthorize),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleImportFromImage() {
    globalState.container
        .read(profilesActionProvider.notifier)
        .addProfileFormQrCode();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final accent = context.styleTokens.accent(colorScheme);
    final double sideLength = min(
      400,
      MediaQuery.of(context).size.width * 0.67,
    );
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(Offset.zero),
      width: sideLength,
      height: sideLength,
    );
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          Center(
            child: MobileScanner(
              controller: controller,
              scanWindow: scanWindow,
              errorBuilder: _buildError,
              placeholderBuilder: (_) => ColoredBox(color: colorScheme.surface),
            ),
          ),
          CustomPaint(
            painter: ScannerOverlay(
              scanWindow: scanWindow,
              borderColor: accent,
            ),
          ),
          AppBar(
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            leading: IconButton(
              style: IconButton.styleFrom(
                iconSize: 32,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.close),
            ),
            actions: [
              ValueListenableBuilder<MobileScannerState>(
                valueListenable: controller,
                builder: (context, state, _) {
                  // 手电筒开着＝一个「已启用」的状态，用应用统一的强调色表示，
                  // 而不是自成一格的橙色。
                  var icon = const Icon(Icons.flash_off);
                  var backgroundColor = Colors.black26;
                  switch (state.torchState) {
                    case TorchState.off:
                      icon = const Icon(Icons.flash_off);
                      backgroundColor = Colors.black26;
                    case TorchState.on:
                      icon = const Icon(Icons.flash_on);
                      backgroundColor = accent;
                    case TorchState.unavailable:
                      icon = const Icon(Icons.flash_off);
                      backgroundColor = Colors.transparent;
                    case TorchState.auto:
                      icon = const Icon(Icons.flash_auto);
                      backgroundColor = accent;
                  }
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: ActivateBox(
                      active: state.torchState != TorchState.unavailable,
                      child: IconButton(
                        color: Colors.white,
                        icon: icon,
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: backgroundColor,
                        ),
                        onPressed: () => controller.toggleTorch(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 32),
            alignment: Alignment.bottomCenter,
            child: IconButton(
              style: IconButton.styleFrom(
                // 悬在摄像头画面上，白底黑图标才不会被背景淹掉；原来的
                // Colors.grey 是 Material 默认灰，和应用其它按钮不是一路。
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
              ),
              padding: const EdgeInsets.all(16),
              iconSize: 32.0,
              onPressed: _handleImportFromImage,
              icon: const Icon(Icons.photo_camera_back),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _subscription = null;
    // super.dispose() must run synchronously; awaiting first trips the
    // framework's lifecycle assertion.
    unawaited(controller.dispose());
    super.dispose();
  }
}

class ScannerOverlay extends CustomPainter {
  const ScannerOverlay({
    required this.scanWindow,
    required this.borderColor,
    this.borderRadius = 12.0,
  });

  final Rect scanWindow;
  final Color borderColor;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.largest);

    final cutoutPath = Path()
      ..addRSuperellipse(
        RSuperellipse.fromRectAndCorners(
          scanWindow,
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
          bottomLeft: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
      );

    final backgroundPaint = Paint()
      ..color = Colors.black.opacity50
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final backgroundWithCutout = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final border = RSuperellipse.fromRectAndCorners(
      scanWindow,
      topLeft: Radius.circular(borderRadius),
      topRight: Radius.circular(borderRadius),
      bottomLeft: Radius.circular(borderRadius),
      bottomRight: Radius.circular(borderRadius),
    );

    canvas.drawPath(backgroundWithCutout, backgroundPaint);
    canvas.drawRSuperellipse(border, borderPaint);
  }

  @override
  bool shouldRepaint(ScannerOverlay oldDelegate) {
    return scanWindow != oldDelegate.scanWindow ||
        borderColor != oldDelegate.borderColor ||
        borderRadius != oldDelegate.borderRadius;
  }
}
