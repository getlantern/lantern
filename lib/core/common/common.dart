// Common file to export all common files
import 'package:lantern/core/router/router.dart';
import '../services/injection_container.dart';

export 'package:lantern/core/common/app_image_paths.dart';
export 'package:lantern/core/common/app_asset.dart';
export  'package:lantern/core/common/platfrom_utils.dart';
export  'package:lantern/core/common/app_theme.dart';

// UI
export 'package:lantern/core/widgets/lantern_logo.dart';


AppRouter get appRouter => sl<AppRouter>();






