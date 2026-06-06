import 'model_downloader.dart';
import 'model_downloader_factory_io.dart'
    if (dart.library.html) 'model_downloader_factory_web.dart'
    as impl;

ModelDownloader createModelDownloader() => impl.createModelDownloader();
