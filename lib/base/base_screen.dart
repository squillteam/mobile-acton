import 'dart:convert';
import 'dart:typed_data';
import 'package:acton/helpers/device/GeoLocation.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:image/image.dart';

class BaseScreen extends StatefulWidget {
  const BaseScreen({super.key});

  @override
  State<BaseScreen> createState() => _BaseState();
}

class _BaseState extends State<BaseScreen> {
  late final WebViewController _webViewController;

  @override
  void initState() {
    super.initState();

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..addJavaScriptChannel('MessageInvoker',
          onMessageReceived: (JavaScriptMessage jsMessage) async {
        Map<String, dynamic> data = jsonDecode(jsMessage.message);
        printer(data);
      })
      ..addJavaScriptChannel('ExitInvoker',
          onMessageReceived: (JavaScriptMessage jsMessage) {
        SystemNavigator.pop();
      })
      ..addJavaScriptChannel('CurrentLocationInvoker',
          onMessageReceived: (JavaScriptMessage jsMessage) async {
        Position position = await GeoLocation().getPosition();

        _webViewController.runJavaScript(
            'window.onCurrentLocation(${position.latitude},${position.longitude});');
      })
      ..loadRequest(Uri.parse("https://web-acton.vercel.app"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        WebViewWidget(controller: _webViewController),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onLongPress: () {
              SystemNavigator.pop();
            },
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(color: Colors.transparent),
            ),
          ),
        )
      ]),
    );
  }

  Future<void> printer(Map<String, dynamic> data) async {
    try {
      // const paper = PaperSize.mm80;
      // final profile = await CapabilityProfile.load();
      // final printer = NetworkPrinter(paper, profile);

      // final PosPrintResult res = await printer.connect("10.0.6.2", port: 9100, timeout: const Duration(seconds: 60));
      const paper = PaperSize.mm80;
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(paper, profile);

      final PosPrintResult res = await printer.connect("10.0.6.2",
          port: 9100, timeout: const Duration(seconds: 60));

      if (res == PosPrintResult.success) {
        ByteData imgProductLogo = await rootBundle.load(
            "assets/${(data["methodology"] as String).replaceAll(" ", "_")}.png");
        Uint8List bytesImgProductLogo = imgProductLogo.buffer.asUint8List();
        Image? imgProduct = decodeImage(bytesImgProductLogo);

        if (imgProduct != null) {
          printer.image(imgProduct);
        }

        printer.feed(1);

        printer.text("Nome: ${data["name"]}");
        printer.text("Metodologia: ${data["methodology"]}");
        printer.text("Nivel: ${data["level"]}");
        printer.text("Fase: ${data["stage"]}");

        printer.feed(1);

        int index = 0;
        for (var needs
            in List<Map<String, dynamic>>.from(data["specialNeeds"])) {
          if (index == 0) {
            printer.text("Necessidades especiais");
          }
          printer.text("> ${needs["showName"]}");
          index++;
        }

        printer.feed(1);

        ByteData imgActonLogo = await rootBundle.load("assets/acton_logo.png");
        Uint8List bytesImgActonLogo = imgActonLogo.buffer.asUint8List();
        Image? imageActon = decodeImage(bytesImgActonLogo);

        if (imageActon != null) {
          printer.image(imageActon);
        }

        printer.feed(1);
        printer.cut();

        printer.disconnect();
      } else {
        throw Exception("Printer connection error: ${res.msg}");
      }
    } catch (e) {
      print(e);
    }
  }
}
