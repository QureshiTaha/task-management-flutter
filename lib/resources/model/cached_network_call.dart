import 'dart:math';

class CachedNetworkCall {
  final String id;
  final String path, method;
  final dynamic body;
  final Map<String, dynamic> params, query;

  String? title, description;

  CachedNetworkCall({
    required this.path,
    required this.method,
    this.title,
    this.description,
    String? id,
    this.params = const {},
    this.query = const {},
    this.body = const {},
  }) : id = id ?? getRandomString(16);

  Map toMap() {
    return {
      "path": path,
      "id": id,
      "title": title,
      "description": description,
      "method": method,
      "params": params,
      "query": query,
      "body": body,
    };
  }

  static CachedNetworkCall fromMap(Map data) {
    return CachedNetworkCall(
      id: data["id"],
      path: data["path"],
      title: data["title"],
      description: data["description"],
      method: data["method"],
      params: Map.from(data["params"]),
      query: Map.from(data["query"]),
      body: data["body"],
    );
  }
}

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';

Random _rnd = Random.secure();

String getRandomString(int length) {
  return String.fromCharCodes(
    Iterable.generate(
      length,
      (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length)),
    ),
  );
}
