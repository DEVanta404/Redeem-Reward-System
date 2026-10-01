const pesoSymbol = '\u20B1';

String formatPeso(num amount) => '$pesoSymbol${amount.toStringAsFixed(2)}';
