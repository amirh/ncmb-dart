part of '../ncmb.dart';

class NCMBRequest {
  NCMB _ncmb;
  NCMBRequest(NCMB ncmb) {
    _ncmb = ncmb;
  }
  
  Future<List> get(String name, Map queries) async {
    try {
      Map<String, dynamic> res = await exec('GET', name, queries: queries);
      return res['results'] as List;
    } catch (e) {
      throw e;
    }
  }
  
  Future<Map> post(String name, Map fields) async {
    return exec('POST', name, fields: fields);
  }
  
  Future<Map> put(String name, String objectId, Map fields) async {
    return exec('PUT', name, fields: fields, objectId: objectId);
  }
  
  Future<Map> delete(String name, String objectId) async {
    return exec('DELETE', name, objectId: objectId);
  }
  
  Future<Map> exec(String method, String name, {fields = const {}, objectId = '', queries = const {}, path = ''}) async {
    Signature s = new Signature(_ncmb);
    DateTime time = DateTime.now();
    final newFields = Map.from(fields)
      ..removeWhere((k, v) => (k == 'objectId' || k == 'createDate' || k == 'updateDate'));
    String signature = s.generate(method, name, time, objectId: objectId, queries: queries, definePath: path);
    String url = s.url(name, objectId: objectId, queries: queries, definePath: path);
    Map<String, String> headers = {
      "X-NCMB-Application-Key": _ncmb.applicationKey,
      "X-NCMB-Timestamp": time.toIso8601String(),
      "X-NCMB-Signature": signature,
      "Content-Type": "application/json"
    };
    if (name == 'files') {
      headers.remove('Content-Type');
    }
    if (_ncmb.sessionToken != null) {
      headers['X-NCMB-Apps-Session-Token'] = _ncmb.sessionToken;
    }
    try {
      var response = await req(url, method, newFields, headers, multipart: (name == 'files'), fileName: objectId);
      if (response.data is Uint8List) {
        return {"data": response.data};
      }
      if (method == 'DELETE') return {};
      return response.data;
    } on DioError catch(e) {
      throw Exception(e.response.data);
    }
  }
  
  String jsonEncode(Map fields) {
    fields.forEach((k, v) {
      if (v is DateTime) {
        var format = new DateFormat("yyyy-MM-ddTHH:mm:ss.S'Z'");
        fields[k] = {
          '__type': 'Date', 'iso': format.format(v)
        };
      }
      if (v is NCMBAcl) {
        fields[k] = v.toJson();
      }
    });
    return json.encode(fields);
  }
  
  void printWrapped(String text) {
    final pattern = new RegExp('.{1,800}'); // 800 is the size of each chunk
    pattern.allMatches(text).forEach((match) => print(match.group(0)));
  }
  Future<Response> req(String url, String method, Map fields, Map headers, {multipart = false, fileName = ''}) async {
    Response response;
    var dio = new Dio();
    switch (method) {
      case 'GET': {
        if (multipart) {
          response = await dio.get<List<int>>(url,
            options: Options(
              headers: headers,
              responseType: ResponseType.bytes
            )
          );
        } else {
          response = await dio.get(url,
            options: Options(
              headers: headers
            )
          );
        }
      }
      break;
      
      case 'POST': {
        var data;
        if (multipart) {
          FormData formData = FormData.fromMap({
            'acl': fields['acl'].toJson(),
            'file': MultipartFile.fromBytes(fields['file'], filename: fileName, contentType: fields['mimeType'])
          });
          data = formData;
        } else {
          data = jsonEncode(fields);
        }
        response = await dio.post(url,
          data: data,
          options: Options(
            headers: headers
          )
        );
      }
      break;
      
      case 'PUT': {
        response = await dio.put(url,
          data: jsonEncode(fields),
          options: Options(
            headers: headers
          )
        );
      }
      break;

      case 'DELETE': {
        response = await dio.delete(url,
          options: Options(
            headers: headers
          )
        );
      }
      break;
    }
    return response;
  }
}