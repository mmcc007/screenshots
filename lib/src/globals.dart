import 'image_magick.dart';

/// default config file name
const String kConfigFileName = 'screenshots.yaml';

/// screenshots environment file name
const String kEnvFileName = 'env.json';

/// Distinguish device OS.
enum DeviceType { android, ios }

/// Run mode
enum RunMode { normal, recording, comparison }

// singleton
ImageMagick get im => ImageMagick();

const kImageExtension = 'png';
