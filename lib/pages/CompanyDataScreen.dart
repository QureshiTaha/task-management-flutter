import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:task_management/resources/local_storage.dart';

class CompanyDataScreen extends StatefulWidget {
  const CompanyDataScreen({super.key});

  @override
  State<CompanyDataScreen> createState() => _CompanyDataScreenState();
}

class _CompanyDataScreenState extends State<CompanyDataScreen> {
  InAppWebViewController? webViewController;
  String? userEmail = localStorage.getString("loginUserEmail");
  String? userPassword = localStorage.getString("loginUserPassword");
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
        appBar: AppBar(title: const Text('Company Dashboard')),
        body: Column(
          children: <Widget>[
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(
                    'https://company.iceweb.in/?userEmail=$userEmail&userPassword=${userPassword}',
                  ),

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
