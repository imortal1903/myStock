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
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    autoZoom: true,
    formats: const [
      BarcodeFormat.ean13,
    ],
  );

  bool _handled = false;

  String? _lastCode;
  int _confirmations = 0;

  static const int _requiredConfirmations = 3;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;

    final value = (barcode.displayValue ?? barcode.rawValue)?.trim();

    if (value == null || value.isEmpty) return;

    if (value.length != 13 || !_isValidEan13(value)) {
      _lastCode = null;
      _confirmations = 0;
      return;
    }

    if (_lastCode == value) {
      _confirmations++;

      if (_confirmations >= _requiredConfirmations) {
        _handled = true;
        Navigator.pop(context, value);
      }
    } else {
      _lastCode = value;
      _confirmations = 1;
    }
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
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          IgnorePointer(
            child: Column(
              children: [
                Expanded(child: Container(color: Colors.black.withValues(alpha: 0.55))),
                Row(
                  children: [
                    Expanded(child: Container(color: Colors.black.withValues(alpha: 0.55))),
                    Container(
                      width: 270,
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.accent, width: 2),
                        borderRadius: BorderRadius.circular(16),
                      ),
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
bool _isValidEan13(String code) {
  if (code.length != 13) return false;

  final digits = code.split('').map(int.parse).toList();

  int sum = 0;

  for (int i = 0; i < 12; i++) {
    sum += digits[i] * (i.isEven ? 1 : 3);
  }

  final checkDigit = (10 - (sum % 10)) % 10;

  return checkDigit == digits[12];
}