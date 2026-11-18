import 'package:material_ui/material_ui.dart';

import '../design/caption_theme.dart';

class CaptionApp extends StatelessWidget {
  const CaptionApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multipost',
      debugShowCheckedModeBanner: false,
      theme: captionTheme(Brightness.light),
      darkTheme: captionTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: home,
    );
  }
}
