import 'package:intl/intl.dart';

class NumberToWords {
  static const List<String> _ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
    'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'
  ];

  static const List<String> _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
  ];

  static String convert(double amount) {
    if (amount == 0) return 'Zero';

    int whole = amount.floor();
    int paise = ((amount - whole) * 100).round();

    String result = _convertIndian(whole);
    if (paise > 0) {
      result += ' Rupees and ${_convertBelowThousand(paise)} Paise';
    } else {
      result += ' Rupees';
    }

    return '$result Only';
  }

  static String _convertIndian(int n) {
    if (n == 0) return '';
    
    if (n < 1000) return _convertBelowThousand(n);

    String res = "";
    
    // Crores
    if (n >= 10000000) {
      res += "${_convertBelowThousand(n ~/ 10000000)} Crore ";
      n %= 10000000;
    }
    
    // Lakhs
    if (n >= 100000) {
      res += "${_convertBelowThousand(n ~/ 100000)} Lakh ";
      n %= 100000;
    }
    
    // Thousands
    if (n >= 1000) {
      res += "${_convertBelowThousand(n ~/ 1000)} Thousand ";
      n %= 1000;
    }
    
    if (n > 0) {
      res += _convertBelowThousand(n);
    }
    
    return res.trim();
  }

  static String _convertBelowThousand(int n) {
    if (n < 20) return _ones[n];
    if (n < 100) return "${_tens[n ~/ 10]} ${_ones[n %= 10]}".trim();
    
    String res = "${_ones[n ~/ 100]} Hundred";
    if (n % 100 > 0) {
      res += " and ${_convertBelowThousand(n % 100)}";
    }
    return res;
  }
}
