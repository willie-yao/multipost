import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'design/caption_scaffold.dart';

void main() {
  runApp(
    const CaptionApp(
      home: CaptionScaffold(title: 'Caption', body: SizedBox.shrink()),
    ),
  );
}
