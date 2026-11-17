import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';

import 'app/app.dart';
import 'app/services.dart';
import 'design/caption_scaffold.dart';
import 'storage/local_database.dart';
import 'features/library/library_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CaptionApp(home: _Bootstrap()));
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  AppServices? _services;
  Object? _error;
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() => _error = null);
    try {
      final services = await AppServices.open();
      // Android consumes the lost-data cache centrally before any new launch.
      try {
        await services.attempts.recoverInterrupted();
        await services.recoverPicker(ImagePicker());
      } catch (_) {
        await services.close();
        rethrow;
      }
      if (mounted) {
        setState(() => _services = services);
      } else {
        await services.close();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) => _services == null
      ? CaptionScaffold(
          title: 'Caption',
          body: _error == null
              ? const Column(
                  children: [
                    CircularProgressIndicator(),
                    Text('Opening local library…'),
                  ],
                )
              : Column(
                  children: [
                    Text(switch (_error) {
                      LocalStorageException(:final message) => message,
                      _ => 'Local storage could not open. Keep this data and try again.',
                    }),
                    OutlinedButton(
                      onPressed: _open,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
        )
      : LibraryScreen(services: _services!);
}
