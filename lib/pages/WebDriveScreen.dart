import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebDriveScreen extends StatefulWidget {
  const WebDriveScreen({super.key});

  @override
  State<WebDriveScreen> createState() => _WebDriveScreenState();
}

class _WebDriveScreenState extends State<WebDriveScreen> {
  InAppWebViewController? webViewController;
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: ((didPop, result) async {
        final controller = webViewController;
        if (controller != null) {
          if (await controller.canGoBack()) {
            controller.goBack();
            // controller.goForward();
          } else {
            Navigator.popAndPushNamed(context, "/home");
          }
        }
      }),
      child: Scaffold(
        appBar: AppBar(title: const Text('Drive')),
        body: Column(
          children: <Widget>[
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri('https://drive.iceweb.in/login'),
                  headers: {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods':
                        'GET, POST, PATCH, PUT, DELETE, OPTIONS',
                    'Access-Control-Allow-Headers':
                        'Origin, Content-Type, X-Auth-Token',
                  },
                ),
                initialSettings: InAppWebViewSettings(),
                onWebViewCreated:
                    (controller) => {webViewController = controller},
                initialOptions: InAppWebViewGroupOptions(
                  crossPlatform: InAppWebViewOptions(
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
