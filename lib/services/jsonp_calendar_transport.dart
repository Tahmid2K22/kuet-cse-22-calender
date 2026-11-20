import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../config/app_config.dart';
import 'calendar_exception.dart';
import 'calendar_transport.dart';

/// Fetches the Web App with a JSONP `<script>` request.
///
/// Google Apps Script's `ContentService` cannot add CORS headers, so a normal
/// `fetch` from the browser is blocked. A script tag is not subject to CORS;
/// the Web App detects the `callback` parameter and replies with
/// `callbackName("...json...");`.
class JsonpCalendarTransport extends CalendarTransport {
  JsonpCalendarTransport({Duration? timeout})
    : _timeout = timeout ?? AppConfig.requestTimeout;

  final Duration _timeout;

  static int _sequence = 0;

  @override
  Future<CalendarTransportResponse> get(Uri uri) {
    final callbackName =
        '__academicCalendarJsonp_${DateTime.now().microsecondsSinceEpoch}_'
        '${_sequence++}';

    final completer = Completer<CalendarTransportResponse>();
    final script = web.HTMLScriptElement();
    var completed = false;
    Timer? timer;

    late final JSFunction onCallback;
    late final JSFunction onError;
    late final JSFunction onLoad;

    void cleanup() {
      timer?.cancel();
      script.removeEventListener('error', onError);
      script.removeEventListener('load', onLoad);
      script.remove();
      globalContext.delete(callbackName.toJS);
    }

    void succeed(CalendarTransportResponse response) {
      if (completed) return;
      completed = true;
      cleanup();
      completer.complete(response);
    }

    void fail(CalendarException error) {
      if (completed) return;
      completed = true;
      cleanup();
      completer.completeError(error);
    }

    onCallback = ((JSAny? payload) {
      // The Apps Script wrapper sends a JSON string. Accepting maps and lists
      // as well keeps the transport compatible with other JSONP backends.
      final value = payload?.dartify();
      final body = switch (value) {
        String text => text,
        null => '',
        _ => jsonEncode(value),
      };

      succeed(CalendarTransportResponse(statusCode: 200, body: body));
    }).toJS;

    onError = ((web.Event event) {
      fail(
        const CalendarException(
          kind: CalendarErrorKind.network,
          message:
              'Could not reach the calendar service. Check your internet '
              'connection.',
        ),
      );
    }).toJS;

    onLoad = ((web.Event event) {
      // A successful JSONP response calls the callback before `load`. Reaching
      // this listener means the server replied with something else, usually a
      // sign-in page or an error page.
      fail(
        const CalendarException(
          kind: CalendarErrorKind.invalidResponse,
          message:
              'The calendar service did not return a JSONP response. Check '
              'that the latest Apps Script version is deployed with access '
              'set to "Anyone".',
        ),
      );
    }).toJS;

    script.async = true;
    script.src = uri
        .replace(
          queryParameters: {...uri.queryParameters, 'callback': callbackName},
        )
        .toString();

    script.addEventListener('error', onError);
    script.addEventListener('load', onLoad);

    final parent = web.document.head ?? web.document.body;
    if (parent == null) {
      fail(
        const CalendarException(
          kind: CalendarErrorKind.invalidResponse,
          message: 'The browser could not create the calendar request.',
        ),
      );
      return completer.future;
    }

    try {
      // The global callback must exist before the script starts executing.
      globalContext.setProperty(callbackName.toJS, onCallback);

      timer = Timer(_timeout, () {
        fail(
          const CalendarException(
            kind: CalendarErrorKind.timeout,
            message: 'The calendar request timed out. Please try again.',
          ),
        );
      });

      parent.append(script);
    } catch (error) {
      fail(
        CalendarException(
          kind: CalendarErrorKind.invalidResponse,
          message: 'The browser could not create the calendar request.',
          details: error.toString(),
        ),
      );
    }

    return completer.future;
  }
}

/// Factory selected by the conditional export on the web.
CalendarTransport createCalendarTransport() => JsonpCalendarTransport();
