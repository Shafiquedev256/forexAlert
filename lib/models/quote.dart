/// A price observation and when it was taken (epoch milliseconds).
class Quote {
  const Quote({required this.price, required this.ts});

  final double price;
  final int ts;

  Map<String, dynamic> toJson() => {'p': price, 't': ts};

  factory Quote.fromJson(Map<String, dynamic> json) =>
      Quote(price: (json['p'] as num).toDouble(), ts: json['t'] as int);
}
