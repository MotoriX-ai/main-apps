import 'dart:convert';
import 'dart:js_interop';

@JS('motorixSubscribePush')
external JSPromise<JSString> _motorixSubscribePush(JSString publicKey);

Future<Map<String, dynamic>> subscribeWebPush(String publicKey) async {
  final encoded = (await _motorixSubscribePush(publicKey.toJS).toDart).toDart;
  return Map<String, dynamic>.from(jsonDecode(encoded) as Map);
}
