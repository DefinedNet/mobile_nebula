class UnsafeRoute {
  String route;
  String via;

  UnsafeRoute({required this.route, required this.via});

  factory UnsafeRoute.fromJson(Map<String, dynamic> json) {
    return UnsafeRoute(
      route: json['route'],
      via: json['via'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route': route,
      'via': via,
    };
  }
}
