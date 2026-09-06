import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/common.dart';
import 'package:clash_party/models/state.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/views/proxies/list.dart';
import 'package:clash_party/views/proxies/providers.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'current_node_bar.dart';
import 'setting.dart';

class ProxiesView extends ConsumerStatefulWidget {
  const ProxiesView({super.key});

  @override
  ConsumerState<ProxiesView> createState() => _ProxiesViewState();
}

class _ProxiesViewState extends ConsumerState<ProxiesView> {
  List<Widget> _buildActions(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return [
      CommonPopupBox(
        targetBuilder: (open) {
          return IconButton(
            onPressed: () {
              final isMobile = ref.read(isMobileViewProvider);
              open(offset: Offset(0, isMobile ? 0 : 20));
            },
            icon: const Icon(Icons.more_vert),
          );
        },
        popup: CommonPopupMenu(
          items: [
            PopupMenuItemData(
              icon: Icons.tune,
              label: appLocalizations.settings,
              onPressed: () {
                showSheet(
                  context: context,
                  props: const SheetProps(isScrollControlled: true),
                  builder: (_) {
                    return AdaptiveSheetScaffold(
                      body: const ProxiesSetting(),
                      title: appLocalizations.settings,
                    );
                  },
                );
              },
            ),
            // **常驻，不按"有没有提供者"隐藏。** 一个功能在菜单里时有时无，
            // 用户根本不知道它存不存在；没有提供者时进去看到空状态，那才是能
            // 看懂的答案。
            PopupMenuItemData(
              icon: Icons.poll_outlined,
              label: appLocalizations.providers,
              onPressed: () {
                showExtend(
                  context,
                  builder: (_) {
                    return const ProvidersView();
                  },
                );
              },
            ),
          ],
        ),
      ),
    ];
  }

  void _onSearch(String value) {
    ref.read(queryProvider(QueryTag.proxies).notifier).value = value;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(loadingProvider(LoadingTag.proxies));
    return CommonScaffold(
      isLoading: isLoading,
      resizeToAvoidBottomInset: false,
      actions: _buildActions(context),
      title: context.appLocalizations.proxies,
      searchState: AppBarSearchState(onSearch: _onSearch),
      body: const Column(
        children: [
          CurrentNodeBar(),
          // 只有列表这一种排版了：标签页那版按用户要求去掉。
          Expanded(child: ProxiesListView()),
        ],
      ),
    );
  }
}
