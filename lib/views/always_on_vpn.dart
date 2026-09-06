import 'package:clash_party/common/common.dart';
import 'package:clash_party/plugins/app.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/profiles/overwrite/custom/widgets.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// 引导用户去系统里打开「始终开启 VPN」。
///
/// 这是个**系统开关，不是应用自己的设置**——开了之后手机重启、应用被杀，系统也会
/// 自动把 VPN 拉起来。安卓没有给应用改它的接口（也没有查它开没开的接口），
/// 应用能做的只有把人送到设置页，所以这里既没有开关也没有状态。
///
/// 送得到的最深一层是系统的「VPN」列表页，还要用户自己点本应用旁边的齿轮才能看到
/// 「始终开启 VPN」。更深那一层是隐藏入口，各家 ROM 路径还不一样，硬跳会崩或者跳
/// 到空白页，所以不跳。跳列表页也失败时（个别 ROM 把这个页面砍了），改成把路径
/// 直接写给用户看。
class AlwaysOnVpnItem extends StatelessWidget {
  const AlwaysOnVpnItem({super.key});

  Future<void> _handleOpen(BuildContext context) async {
    final appLocalizations = context.appLocalizations;
    final opened = await app?.openVpnSettings();
    if (opened == true) {
      return;
    }
    await globalState.showMessage(
      title: appLocalizations.alwaysOnVpn,
      cancelable: false,
      message: TextSpan(text: appLocalizations.alwaysOnVpnGuide),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return ListItem(
      minVerticalPadding: 8,
      title: Text(appLocalizations.alwaysOnVpn),
      subtitle: Text(appLocalizations.alwaysOnVpnDesc),
      onTap: () => _handleOpen(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          // 路径本身也直接给出来：有的 ROM 跳过去之后长得完全不一样，
          // 只说「前往」等于把人扔在设置里自己找。
          InfoMessageButton(message: appLocalizations.alwaysOnVpnGuide),
          CommonMinFilledButtonTheme(
            child: FilledButton.tonal(
              onPressed: () => _handleOpen(context),
              child: Text(appLocalizations.go),
            ),
          ),
        ],
      ),
    );
  }
}
