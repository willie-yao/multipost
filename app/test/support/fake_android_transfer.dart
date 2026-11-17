import 'package:cross_posting_app/features/instagram/android_transfer.dart';
import 'package:cross_posting_app/features/instagram/instagram_package.dart';

class FakeAndroidTransfer implements AndroidTransfer {
  FakeAndroidTransfer({Set<int> failOrdinals = const {}})
    : failOrdinals = {...failOrdinals};
  final Set<int> failOrdinals;
  final savedBatches = <Set<int>>[];
  final receipts = <String, String>{};
  Exception? copyFailure;
  String? copied;
  Future<void> Function(List<PhotoExportJob>)? beforeSave;
  @override
  Future<void> copyCaption(String caption) async {
    if (copyFailure case final error?) throw error;
    copied = caption;
  }

  @override
  Future<List<PhotoSaveResult>> savePhotos(
    InstagramPackage package,
    List<PhotoExportJob> jobs,
  ) async {
    await beforeSave?.call(jobs);
    savedBatches.add(jobs.map((j) => j.ordinal).toSet());
    return [
      for (final job in jobs)
        if (failOrdinals.contains(job.ordinal))
          PhotoSaveResult(ordinal: job.ordinal, errorCode: 'write-failed')
        else
          PhotoSaveResult(
            ordinal: job.ordinal,
            uri: receipts.putIfAbsent(
              job.id,
              () => Uri(
                scheme: 'content',
                host: 'caption-test',
                path: '/${job.ordinal}',
              ).toString(),
            ),
          ),
    ];
  }

  @override
  Future<List<PhotoSaveResult>> reconcilePhotos(
    InstagramPackage package,
    List<PhotoExportJob> jobs,
  ) async => [
    for (final job in jobs)
      PhotoSaveResult(
        ordinal: job.ordinal,
        uri: receipts[job.id],
        errorCode: receipts.containsKey(job.id) ? null : 'missing',
      ),
  ];
}
