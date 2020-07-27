class UnsafeRoute {
  String route;
  String via;

  UnsafeRoute({this.route, this.via});

  UnsafeRoute.fromJson(Map<String, dynamic> json) {
    route = json['route'];
    via = json['via'];
  }

  Map<String, dynamic> toJson() {
    return {
      'route': route,
      'via': via,
    };
  }
}