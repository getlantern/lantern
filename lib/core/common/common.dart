// Common file to export all common files
import 'package:lantern/core/router/router.dart';
import '../services/injection_container.dart';

export 'package:lantern/core/common/app_image_paths.dart';
export 'package:lantern/core/common/app_asset.dart';
export 'package:lantern/core/common/app_colors.dart';
export 'package:lantern/core/common/app_dimens.dart';
export 'package:lantern/core/common/app_eum.dart';
export 'package:lantern/core/common/app_extension.dart';


// Utils
export  'package:lantern/core/common/platfrom_utils.dart';
export 'package:lantern/core/common/app_urls.dart';
export  'package:lantern/core/common/app_theme.dart';

// UI
export 'package:lantern/core/widgets/lantern_logo.dart';
export  'package:lantern/core/common/app_buttons.dart';
export 'package:lantern/core/widgets/app_tile.dart';
export '../../core/widgets/divider_space.dart';
export 'package:lantern/core/widgets/pro_button.dart';
export 'package:lantern/core/widgets/custom_app_bar.dart';
export 'package:lantern/core/localization/i18n.dart';
export 'package:lantern/core/widgets/data_usage.dart';
export 'package:lantern/core/widgets/bottomsheet.dart';
export 'package:lantern/core/widgets/app_card.dart';
export 'package:lantern/core/utils/url_utils.dart';
export 'package:lantern/core/widgets/base_screen.dart';
export 'package:lantern/core/widgets/platform_card.dart';




// Routes
export 'package:lantern/core/router/router.gr.dart';

// DB
export 'package:lantern/core/services/local_storage.dart';

AppRouter get appRouter => sl<AppRouter>();






