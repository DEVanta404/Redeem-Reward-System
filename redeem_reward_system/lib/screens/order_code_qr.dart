import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class OrderCodeQr extends StatelessWidget {
  final String orderCode;
  final double size;

  const OrderCodeQr({super.key, required this.orderCode, this.size = 156});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: QrImageView(
        data: orderCode,
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        semanticsLabel: 'QR code for order $orderCode',
      ),
    );
  }
}
