import 'package:material_ui/material_ui.dart';

import '../design/caption_theme.dart';

class CaptionApp extends StatelessWidget {
  const CaptionApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caption',
      debugShowCheckedModeBanner: false,
      theme: captionTheme(),
      themeMode: ThemeMode.dark,
      home: home,
    );
  }
}
