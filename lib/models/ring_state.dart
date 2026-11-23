/// Which alerts are ringing right now and since when.
class RingState {
  const RingState({this.alertIds = const [], this.startedAt = 0});

  static const RingState idle = RingState();

  final List<String> alertIds;
  final int startedAt;

  bool get active => alertIds.isNotEmpty;

  Map<String, dynamic> toJson() => {'ids': alertIds, 'at': startedAt};

  factory RingState.fromJson(Map<String, dynamic> json) => RingState(
        alertIds: (json['ids'] as List<dynamic>).cast<String>(),
        startedAt: json['at'] as int,
      );
}
