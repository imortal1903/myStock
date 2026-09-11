import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/color_palette.dart';

/// Página de leitura de código de barras.
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 100,
    facing: CameraFacing.back,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.code128,
    ],
  );

  bool _handled = false;

  String? _lastCode;
  int _confirmations = 0;
  DateTime? _lastDetection;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;

    final barcode = capture.barcodes.cast<Barcode?>().firstWhere(
          (b) => b?.rawValue != null,
      orElse: () => null,
    );
    if (barcode == null) return;

    final value = (barcode.displayValue ?? barcode.rawValue)?.trim();
    if (value == null || value.isEmpty) return;

    if (!_isValidBarcode(value, barcode.format)) {
      _resetTracking();
      return;
    }

    final now = DateTime.now();

    if (_lastDetection != null &&
        now.difference(_lastDetection!) > const Duration(milliseconds: 700)) {
      _resetTracking();
    }
    _lastDetection = now;

    if (_lastCode != value) {
      _lastCode = value;
      _confirmations = 1;
    } else {
      _confirmations++;
    }

    final requiredConfirmations = barcode.format == BarcodeFormat.code128 ? 2 : 1;

    if (_confirmations >= requiredConfirmations) {
      _handled = true;
      await _controller.stop();

      if (!mounted) return;
      Navigator.pop(context, value);
    }
  }

  void _resetTracking() {
    _lastCode = null;
    _confirmations = 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text(
          'Ler código de barras',
          style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, _) => Icon(
                state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off,
                color: state.torchState == TorchState.on ? colors.accent : colors.textFaint,
              ),
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final scanWindow = Rect.fromCenter(
                center: constraints.biggest.center(Offset.zero),
                width: 270,
                height: 150,
              );

              return MobileScanner(
                controller: _controller,
                fit: BoxFit.cover,
                scanWindow: scanWindow,
                onDetect: _onDetect,
              );
            },
          ),
          IgnorePointer(
            child: Column(
              children: [
                Expanded(child: Container(color: Colors.black.withValues(alpha: 0.55))),
                Row(
                  children: [
                    Expanded(child: Container(color: Colors.black.withValues(alpha: 0.55))),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 270,
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: colors.accent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),

                        Container(
                          width: 240,
                          height: 2,
                          color: Colors.redAccent,
                        ),
                      ],
                    ),
                    Expanded(child: Container(color: Colors.black.withValues(alpha: 0.55))),
                  ],
                ),
                Expanded(child: Container(color: Colors.black.withValues(alpha: 0.55))),
              ],
            ),
          ),
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Text(
              'Posicione o código de barras dentro da moldura',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onPrimarySecondary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// Validar EAN-13
bool _isValidBarcode(String code, BarcodeFormat format) {
  int digitAt(String code, int index) => code.codeUnitAt(index) - 48;

  switch (format) {
    case BarcodeFormat.ean13:
      if (code.length != 13) return false;
      int sum = 0;

      for (int i = 0; i < 12; i++) {
        sum += digitAt(code, i) * (i.isEven ? 1 : 3);
      }

      final checkDigit = (10 - (sum % 10)) % 10;
      return checkDigit == digitAt(code, 12);

    case BarcodeFormat.ean8:
      if (code.length != 8) return false;
      int sum = 0;

      for (int i = 0; i < 7; i++) {
        sum += digitAt(code, i) * (i.isEven ? 3 : 1);
      }

      final checkDigit = (10 - (sum % 10)) % 10;
      return checkDigit == digitAt(code, 7);

    case BarcodeFormat.code128:
      if (code.isEmpty || code.length > 48) return false;
      return code.codeUnits.every((u) => u >= 32 && u <= 126);

    default:
      return false;
  }
}