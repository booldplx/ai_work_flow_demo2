import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import '../data/workshops.dart';
import '../data/workshop_session.dart';
import 'view_models.dart';

const accent = Color(0xFF963E2A);
const secondary = Color(0xFF625D57);
final repositoryProvider = Provider<WorkshopRepository>(
  (_) => throw StateError('Repository required'),
);
final sessionProvider = Provider<WorkshopSession>((ref) {
  final session = WorkshopSession(ref.watch(repositoryProvider));
  ref.onDispose(session.dispose);
  return session;
});
final discoverProvider = ChangeNotifierProvider.autoDispose<DiscoverViewModel>((
  ref,
) {
  final vm = DiscoverViewModel(
    ref.watch(repositoryProvider),
    session: ref.watch(sessionProvider),
  );
  unawaited(vm.load());
  return vm;
});

/// 场次按固定东八区展示，不受手机系统时区影响。
DateTime workshopTime(DateTime value) =>
    value.toUtc().add(const Duration(hours: 8));
String clock(DateTime value) {
  final time = workshopTime(value);
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

TextStyle style(double size, {bool bold = false, Color? color}) => TextStyle(
  fontSize: size,
  height: 1.3,
  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
  color: color,
);

class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});
  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  bool _opening = false;
  Future<void> _open(Workshop workshop) async {
    if (_opening) return;
    _opening = true;
    await context.pushNamed(
      'workshop',
      pathParameters: {'workshopId': workshop.id},
    );
    _opening = false;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: accent, width: 3),
                        ),
                      ),
                      child: Text(
                        '发现',
                        style: style(22, bold: true, color: accent),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    enabled: false,
                    child: Center(
                      child: Text('我的预约', style: style(22, color: secondary)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    body: SafeArea(
      child: Consumer(
        builder: (context, ref, _) {
          final vm = ref.watch(discoverProvider);
          return RefreshablePagedList(vm: vm, onOpen: _open);
        },
      ),
    ),
  );
}

class RefreshablePagedList extends StatefulWidget {
  const RefreshablePagedList({
    super.key,
    required this.vm,
    required this.onOpen,
  });
  final DiscoverViewModel vm;
  final ValueChanged<Workshop> onOpen;
  @override
  State<RefreshablePagedList> createState() => _RefreshablePagedListState();
}

class _RefreshablePagedListState extends State<RefreshablePagedList> {
  final _controller = ScrollController();
  Future<void> _refresh() async {
    await widget.vm.refresh();
    if (mounted && !widget.vm.refreshError && _controller.hasClients) {
      _controller.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notice) {
            if (notice is ScrollUpdateNotification &&
                notice.dragDetails != null &&
                (notice.scrollDelta ?? 0) > 0 &&
                notice.metrics.extentAfter < 120 &&
                ModalRoute.of(context)?.isCurrent == true) {
              unawaited(vm.loadMore());
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              key: const PageStorageKey('workshop-list'),
              controller: _controller,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 32, 18, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('周末工坊', style: style(44, bold: true)),
                        const SizedBox(height: 20),
                        Text('近期活动', style: style(22)),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                      ],
                    ),
                  ),
                ),
                if (vm.loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (vm.initialError)
                  SliverToBoxAdapter(
                    child: FeedbackPanel(text: '加载失败', onRetry: vm.load),
                  )
                else if (vm.loaded && vm.items.isEmpty)
                  const SliverToBoxAdapter(child: FeedbackPanel(text: '暂无活动'))
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    sliver: SliverList.builder(
                      itemCount: vm.items.length,
                      itemBuilder: (context, index) {
                        final item = vm.items[index];
                        return WorkshopRow(
                          key: ValueKey(item.id),
                          workshop: item,
                          onTap: () => widget.onOpen(item),
                        );
                      },
                    ),
                  ),
                // 页尾只按状态渲染，布局本身不发起分页请求。
                SliverLayoutBuilder(
                  builder: (context, constraints) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: vm.appending
                            ? const Text('加载中')
                            : vm.appendError
                            ? TextButton(
                                onPressed: () => vm.loadMore(retry: true),
                                child: const Text('重试'),
                              )
                            : vm.nextPage != null &&
                                  constraints.precedingScrollExtent <=
                                      constraints.viewportMainAxisExtent
                            ? TextButton(
                                onPressed: vm.loadMore,
                                child: const Text('加载更多'),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (vm.refreshError)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('刷新失败'),
                  TextButton(onPressed: _refresh, child: const Text('重试')),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class WorkshopRow extends StatelessWidget {
  const WorkshopRow({super.key, required this.workshop, required this.onTap});
  final Workshop workshop;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final date = workshopTime(workshop.startsAt);
    final booked = workshop.myReservationId != null;
    final status = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: MediaQuery.textScalerOf(context).scale(16) * 2.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (booked) Text('已预约', style: style(16, color: accent)),
          Text(
            booked || workshop.remaining > 0
                ? '余 ${workshop.remaining} 席'
                : '已满额',
            style: style(
              16,
              color: booked || workshop.remaining > 0 ? accent : secondary,
            ),
          ),
        ],
      ),
    );
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  padding: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Color(0xFF9C958E), width: 0.6),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text('${date.month}月', style: style(17)),
                      Text('${date.day}', style: style(44)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow =
                          constraints.maxWidth < 230 ||
                          MediaQuery.textScalerOf(context).scale(16) > 22;
                      final title = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(workshop.title, style: style(24, bold: true)),
                          const SizedBox(height: 8),
                          Text(
                            '${workshop.venue} · ${clock(workshop.startsAt)}–${clock(workshop.endsAt)}',
                            style: style(16),
                          ),
                        ],
                      );
                      return narrow
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                title,
                                const SizedBox(height: 8),
                                status,
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: title),
                                const SizedBox(width: 12),
                                status,
                              ],
                            );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class WorkshopDetailPage extends ConsumerStatefulWidget {
  const WorkshopDetailPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<WorkshopDetailPage> createState() => _WorkshopDetailPageState();
}

class _WorkshopDetailPageState extends ConsumerState<WorkshopDetailPage>
    with WidgetsBindingObserver {
  late DetailViewModel _vm;
  OverlayEntry? _toast;
  Timer? _toastTimer;
  int _seenFeedback = 0;
  final _actionKey = GlobalKey();

  void _showFeedback() {
    if (!mounted || _seenFeedback == _vm.feedbackSerial) return;
    final serial = _seenFeedback = _vm.feedbackSerial;
    final message = _vm.feedback ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _seenFeedback == serial &&
          ModalRoute.of(context)?.isCurrent == true) {
        _displayToast(message);
      }
    });
  }

  void _displayToast(String message) {
    _clearToast();
    final box = _actionKey.currentContext?.findRenderObject() as RenderBox?;
    final bottom = box != null && box.hasSize
        ? MediaQuery.sizeOf(context).height -
              box.localToGlobal(Offset.zero).dy +
              12
        : MediaQuery.paddingOf(context).bottom + 24;
    _toast = OverlayEntry(
      builder: (_) => Positioned(
        bottom: bottom,
        left: 24,
        right: 24,
        child: IgnorePointer(
          child: Material(
            color: const Color(0xFF1C1B19),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: style(16, color: const Color(0xFFF7F5F2)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_toast!);
    _toastTimer = Timer(const Duration(seconds: 2), _clearToast);
  }

  void _clearToast() {
    _toastTimer?.cancel();
    _toast?.remove();
    _toast?.dispose();
    _toast = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _vm.phase == ReservationPhase.unknown) {
      unawaited(_vm.queryResult());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vm = DetailViewModel(
      ref.read(repositoryProvider),
      widget.id,
      session: ref.read(sessionProvider),
    );
    _vm.addListener(_showFeedback);
    unawaited(_vm.load());
  }

  @override
  void didUpdateWidget(WorkshopDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _clearToast();
      _seenFeedback = 0;
      _vm.removeListener(_showFeedback);
      _vm.dispose();
      _vm = DetailViewModel(
        ref.read(repositoryProvider),
        widget.id,
        session: ref.read(sessionProvider),
      );
      _vm.addListener(_showFeedback);
      unawaited(_vm.load());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearToast();
    _vm.removeListener(_showFeedback);
    _vm.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/discover');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: context.canPop(),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: Scaffold(
      bottomNavigationBar: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          if (_vm.loading || _vm.failed || _vm.workshop == null) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            key: _actionKey,
            child: ReservationActionPanel(vm: _vm),
          );
        },
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              tooltip: '返回',
              onPressed: _back,
              icon: const Icon(Icons.arrow_back_ios_new),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _vm,
                builder: (context, _) {
                  if (_vm.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_vm.failed) {
                    return SingleChildScrollView(
                      child: FeedbackPanel(
                        text: _vm.notFound ? '活动不存在' : '加载失败',
                        onRetry: _vm.notFound ? null : _vm.load,
                      ),
                    );
                  }
                  final item = _vm.workshop!;
                  final date = workshopTime(item.startsAt);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${date.month}月', style: style(30, bold: true)),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '${date.day}', style: style(88)),
                              TextSpan(text: '日', style: style(38)),
                            ],
                          ),
                        ),
                        const Divider(height: 32),
                        Text(item.title, style: style(40, bold: true)),
                        const Divider(height: 48),
                        _field(
                          '时间',
                          '${clock(item.startsAt)}–${clock(item.endsAt)}',
                        ),
                        _field('地点', item.venue),
                        _field('名额', '余 ${item.remaining} 席', color: accent),
                        const SizedBox(height: 24),
                        Text('活动介绍', style: style(24, bold: true)),
                        const SizedBox(height: 16),
                        Text(item.description, style: style(16)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _field(String label, String value, {Color? color}) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final labelText = Text(label, style: style(18));
            final valueText = Text(
              value,
              style: style(18, color: color),
              textAlign: TextAlign.right,
            );
            if (MediaQuery.textScalerOf(context).scale(18) > 26) {
              return SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [labelText, const SizedBox(height: 8), valueText],
                ),
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelText,
                const SizedBox(width: 20),
                Expanded(child: valueText),
              ],
            );
          },
        ),
      ),
      const Divider(height: 1),
    ],
  );
}

class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({super.key, required this.text, this.onRetry});
  final String text;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        Text(text),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}

class ReservationActionPanel extends StatelessWidget {
  const ReservationActionPanel({super.key, required this.vm});
  final DetailViewModel vm;
  @override
  Widget build(BuildContext context) {
    final phase = vm.phase;
    final booked = vm.workshop!.myReservationId != null;
    String label;
    VoidCallback? action;
    if (phase == ReservationPhase.submitting) {
      label = '预约中…';
    } else if (phase == ReservationPhase.reconciling) {
      label = '查询中…';
    } else if (phase == ReservationPhase.unknown) {
      label = '重新查询';
      action = vm.queryResult;
    } else if (booked) {
      label = '已预约';
    } else if (vm.workshop!.remaining == 0) {
      label = '已满额';
    } else {
      label = '预约活动';
      action = vm.reserve;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (phase == ReservationPhase.unknown)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('预约结果待确认', style: style(16)),
          ),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor:
                  action != null || phase == ReservationPhase.submitting
                  ? accent
                  : null,
              foregroundColor: const Color(0xFFF7F5F2),
              disabledForegroundColor: phase == ReservationPhase.submitting
                  ? const Color(0xFFF7F5F2)
                  : secondary,
              minimumSize: const Size(0, 64),
              shape: const RoundedRectangleBorder(),
            ),
            onPressed: action,
            child: Text(label, style: style(22)),
          ),
        ),
        if (booked && phase == ReservationPhase.idle)
          TextButton(onPressed: null, child: Text('查看我的预约', style: style(18))),
      ],
    );
  }
}
