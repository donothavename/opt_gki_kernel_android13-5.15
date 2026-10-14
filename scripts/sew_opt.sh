sew_kernel_opt() {
    abk_log "移植 SEW 内核优化……"

    add_lsm
    add_mi_sw_sync
    add_binder_sched_opt
    add_xiaomi-kshrink_slabd
    add_kshrink_lruvecd
    add_boeffla_wl_blocker
    add_mi_rmap_efficiency
    add_xiaomi-unionpower
    add_sew_mmap_bypass
    add_sew_alloc_adjust
    add_os4port_sched
    add_os4port_mm
    add_xiaomi_boottime
}

add_lsm() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/security/Kconfig"
    abk_require_file "$common_dir/security/Makefile"

    abk_log "添加 LSM 模块阻断……"

    abk_copy_into_kernel "$MODULE_DIR/files/jiuxia-sew_audit_lsm/." "common"

    abk_append_line_once "$common_dir/security/Makefile" 'obj-$(CONFIG_SEW_AUDIT_LSM)\t\t+= sew_audit_lsm.o'

    sed -i 's/source "security\/integrity\/Kconfig"/config SEW_AUDIT_LSM\n\tbool "Sew module load audit LSM"\n\tdepends on SECURITY\n\tdefault y\n\thelp\n\t  Block loading of kernel modules that duplicate functionality built\n\t  into the Sew kernel (binder_prio, moon_*, kshrink_* prefixes), from\n\t  system partitions only. finit_module() covers the Android init\n\t  modules.load path; the older init_module() memory path is not\n\t  intercepted.\n\nsource "security\/integrity\/Kconfig"/g' "$common_dir/security/Kconfig"
}

add_mi_sw_sync() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/drivers/dma-buf/Kconfig"

    abk_log "添加 mi_sw_sync ……"

    abk_copy_into_kernel "$MODULE_DIR/files/mi_sw_sync/." "common"

    sed -i 's/depends on DEBUG_FS//g' "$common_dir/drivers/dma-buf/Kconfig"

    abk_enable_config CONFIG_SW_SYNC
    abk_enable_config CONFIG_SYNC_FILE
}

add_binder_sched_opt() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/drivers/android/Kconfig"
    abk_require_file "$common_dir/drivers/android/Makefile"

    abk_log "添加 Binder 调度优化……"

    abk_copy_into_kernel "$MODULE_DIR/files/binder_sched_opt/." "common"

    abk_append_line_once "$common_dir/drivers/android/Makefile" 'obj-$(CONFIG_BINDER_SCHED_OPT)\t\t+= binder_sched_opt.o'

    sed -i 's/config ANDROID_DEBUG_SYMBOLS/config BINDER_SCHED_OPT\n\tbool "Binder UI transaction scheduling optimization"\n\tdepends on ANDROID_BINDER_IPC \&\& ANDROID_VENDOR_HOOKS\n\tdefault y\n\thelp\n\t  Apply the UI transaction scheduling policy as built-in code.\n\nconfig ANDROID_DEBUG_SYMBOLS/g' "$common_dir/drivers/android/Kconfig"

    abk_enable_config CONFIG_BINDER_SCHED_OPT
}

add_xiaomi-kshrink_slabd() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/mm/Kconfig"
    abk_require_file "$common_dir/mm/Makefile"

    abk_log "添加异步 Slab 回收……"

    abk_copy_into_kernel "$MODULE_DIR/files/xiaomi-kshrink_slabd/." "common"

    abk_append_line_once "$common_dir/mm/Makefile" 'obj-$(CONFIG_KSHRINK_SLABD) += slabd.o'

    sed -i 's/endmenu/config KSHRINK_SLABD\n\tbool "Asynchronous slab reclaim"\n\tdefault y\n\tdepends on MEMCG \&\& ANDROID_VENDOR_HOOKS\n\thelp\n\t  Move one eligible user reclaim slab pass at a time to a freezable\n\t  kernel worker. This preserves the core reclaim path whenever the\n\t  worker already has pending work.\n\nendmenu/g' "$common_dir/mm/Kconfig"

    abk_enable_config CONFIG_KSHRINK_SLABD
}

add_kshrink_lruvecd() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/mm/Kconfig"
    abk_require_file "$common_dir/mm/Makefile"
    abk_require_file "$common_dir/mm/vmscan.c"
    abk_require_file "$common_dir/mm/page_ext.c"
    abk_require_file "$common_dir/drivers/android/vendor_hooks.c"
    abk_require_file "$common_dir/include/trace/hooks/vmscan.h"

    abk_log "添加异步 lruvec 回收……"

    abk_copy_into_kernel "$MODULE_DIR/files/kshrink_lruvecd/." "common"

    abk_append_line_once "$common_dir/mm/Makefile" 'obj-$(CONFIG_KSHRINK_LRUVECD) += kshrink_lruvecd.o'

    sed -i 's/endmenu/config KSHRINK_LRUVECD\n\tbool "Asynchronous lruvec reclaim"\n\tdepends on PAGE_EXTENSION \&\& ANDROID_VENDOR_HOOKS\n\thelp\n\t  Defer rmap-lock-contended pages to an asynchronous reclaim worker.\n\nendmenu/g' "$common_dir/mm/Kconfig"

    sed -i 's/sc->nr_reclaimed += reclaimed;/sc->nr_reclaimed += reclaimed;\n\n\ttrace_android_vh_handle_failed_page_trylock_mglru(\&list);/g' "$common_dir/mm/vmscan.c"

    sed -i 's/#include <linux\/rcupdate.h>/#include <linux\/kshrink_lruvecd.h>\n#include <linux\/rcupdate.h>/g' "$common_dir/mm/page_ext.c"
    sed -i 's/page_pinner_ops,/page_pinner_ops,\n#endif\n#ifdef CONFIG_KSHRINK_LRUVECD\n\t\&kshrink_page_ext_ops,/g' "$common_dir/mm/page_ext.c"

    sed -i 's/EXPORT_TRACEPOINT_SYMBOL_GPL(android_vh_handle_failed_page_trylock);/EXPORT_TRACEPOINT_SYMBOL_GPL(android_vh_handle_failed_page_trylock);\nEXPORT_TRACEPOINT_SYMBOL_GPL(android_vh_handle_failed_page_trylock_mglru);/g' "$common_dir/drivers/android/vendor_hooks.c"

    sed -i 's/TP_ARGS(page_list));/TP_ARGS(page_list));\nDECLARE_HOOK(android_vh_handle_failed_page_trylock_mglru,\n\tTP_PROTO(struct list_head *page_list),\n\tTP_ARGS(page_list));/g' "$common_dir/include/trace/hooks/vmscan.h"

    abk_enable_config CONFIG_KSHRINK_LRUVECD
}

add_boeffla_wl_blocker() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/kernel/power/Kconfig"
    abk_require_file "$common_dir/drivers/base/power/main.c"
    abk_require_file "$common_dir/drivers/base/power/Makefile"

    abk_log "添加通用唤醒锁阻止程序驱动程序……"

    abk_copy_into_kernel "$MODULE_DIR/files/boeffla_wl_blocker/." "common"

    abk_append_line_once "$common_dir/kernel/power/Kconfig" 'source "kernel/power/boeffla_wl_blocker/Kconfig"'

    sed -i '/void dpm_resume_early/,/}/ s/ktime_t starttime = ktime_get();/ktime_t starttime = ktime_get();\n\n#ifdef CONFIG_BOEFFLA_WL_BLOCKER\n\tpm_print_active_wakeup_sources();\n#endif/' "$common_dir/drivers/base/power/main.c"

    sed -i 's/test.o/test.o\nobj-$(CONFIG_BOEFFLA_WL_BLOCKER)	+= boeffla_wl_blocker.o/g' "$common_dir/drivers/base/power/Makefile"

    abk_enable_config CONFIG_BOEFFLA_WL_BLOCKER
}

add_mi_rmap_efficiency() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/mm/Kconfig"
    abk_require_file "$common_dir/mm/Makefile"
    abk_require_file "$common_dir/mm/vmscan.c"
    abk_require_file "$common_dir/include/trace/hooks/mm.h"
    abk_require_file "$common_dir/drivers/android/vendor_hooks.c"

    abk_log "添加 mi_rmap_efficiency ……"

    abk_copy_into_kernel "$MODULE_DIR/files/xiaomi-mi_rmap/." "common"

    abk_append_line_once "$common_dir/mm/Makefile" 'obj-$(CONFIG_MI_RMAP_EFFICIENCY) += mi_rmap_efficiency.o'

    sed -i 's/endmenu/config MI_RMAP_EFFICIENCY\n\tbool "MI rmap efficiency: protect high-mapcount pages"\n\tdefault y\n\tdepends on ANDROID_VENDOR_HOOKS\n\thelp\n\t  Skip high-mapcount pages (>= mi_mapcount_thres, default 32) during\n\t  reclaim to reduce CPU load caused by reverse mapping during memory\n\t  reclaim, protecting multi-process-shared pages (GPU\/display buffers)\n\t  from being recycled. Faithful port of Xiaomis mi_rmap_efficiency.\n\nendmenu/g' "$common_dir/mm/Kconfig"

    sed -i 's/bool should_protect = false/int should_protect = 0/g' "$common_dir/mm/vmscan.c"
    sed -i 's/trace_android_vh_page_should_be_protected(page, &should_protect)/trace_android_vh_sew_page_should_be_protected(page, sc->nr_scanned, sc->priority, \&sc->android_vendor_data1, \&should_protect)/g' "$common_dir/mm/vmscan.c"
    perl -0777 -pi -e 's/\t\/\* Incremented by the number of inactive pages that were scanned \*\/\s+unsigned long nr_scanned;/\t\/* Incremented by the number of inactive pages that were scanned *\/\n\tunsigned long nr_scanned;\n\n\t\/* Vendor reclaim-ext data (e.g. skipped-page accounting). *\/\n\tu64 android_vendor_data1;/gs' "$common_dir/mm/vmscan.c"

    sed -i 's/android_vh_page_should_be_protected/android_vh_sew_page_should_be_protected,\n\tTP_PROTO(struct page *page, unsigned long nr_scanned, s8 priority, u64 *ext, int *should_protect),\n\tTP_ARGS(page, nr_scanned, priority, ext, should_protect));\nDECLARE_HOOK(android_vh_page_should_be_protected/g' "$common_dir/include/trace/hooks/mm.h"

    sed -i 's/EXPORT_TRACEPOINT_SYMBOL_GPL(android_vh_page_should_be_protected);/EXPORT_TRACEPOINT_SYMBOL_GPL(android_vh_page_should_be_protected);\nEXPORT_TRACEPOINT_SYMBOL_GPL(android_vh_sew_page_should_be_protected);/g' "$common_dir/drivers/android/vendor_hooks.c"

    abk_enable_config CONFIG_MI_RMAP_EFFICIENCY
}

add_xiaomi-unionpower() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/drivers/Kconfig"
    abk_require_file "$common_dir/drivers/Makefile"

    abk_log "添加 xiaomi-unionpower ……"

    abk_copy_into_kernel "$MODULE_DIR/files/xiaomi-unionpower/." "common"

    abk_append_line_once "$common_dir/drivers/Makefile" 'obj-$(CONFIG_MI_UNION_POWER) += mihw/'

    sed -i 's/endmenu/\nsource "drivers\/mihw\/Kconfig"\nendmenu/g' "$common_dir/drivers/Kconfig"

    abk_enable_config CONFIG_MI_UNION_POWER
}

add_sew_mmap_bypass() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/mm/Kconfig"
    abk_require_file "$common_dir/mm/Makefile"
    abk_require_file "$common_dir/mm/vmscan.c"
    abk_require_file "$common_dir/include/trace/hooks/vmscan.h"
    abk_require_file "$common_dir/drivers/android/vendor_hooks.c"

    abk_log "添加 sew_mmap_bypass ……"

    abk_copy_into_kernel "$MODULE_DIR/files/sew_mmap_bypass/." "common"

    abk_append_line_once "$common_dir/mm/Makefile" 'obj-$(CONFIG_SEW_MMAP_BYPASS) += sew_mmap_bypass.o'

    sed -i 's/endmenu/config SEW_MMAP_BYPASS\n\tbool "Sew mmap direct-reclaim throttle bypass"\n\tdepends on ANDROID_VENDOR_HOOKS\n\tdefault y\n\thelp\n\t  Bypass direct-reclaim throttling for userspace tasks to reduce\n\t  mmap allocation latency under memory pressure (Sew R7).\n\nendmenu/g' "$common_dir/mm/Kconfig"

    sed -i 's/\/\* Account for the throttling \*\//{\n\t\tbool bypass = false;\n\n\t\ttrace_android_vh_throttle_direct_reclaim_bypass(\&bypass);\n\t\tif (bypass)\n\t\t\tgoto out;\n\t}\n/g' "$common_dir/mm/vmscan.c"

    sed -i 's/TP_ARGS(nr_reclaimed));/TP_ARGS(nr_reclaimed));\nDECLARE_HOOK(android_vh_throttle_direct_reclaim_bypass,\n\tTP_PROTO(bool *bypass),\n\tTP_ARGS(bypass));/g' "$common_dir/include/trace/hooks/vmscan.h"

    sed -i 's/EXPORT_TRACEPOINT_SYMBOL_GPL(android_vh_shrink_slab_bypass);/EXPORT_TRACEPOINT_SYMBOL_GPL(android_vh_shrink_slab_bypass);\nEXPORT_TRACEPOINT_SYMBOL_GPL(android_vh_throttle_direct_reclaim_bypass);/g' "$common_dir/drivers/android/vendor_hooks.c"
}

add_sew_alloc_adjust() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/mm/Kconfig"
    abk_require_file "$common_dir/mm/Makefile"

    abk_log "添加 sew_alloc_adjust ……"

    abk_copy_into_kernel "$MODULE_DIR/files/sew_alloc_adjust/." "common"

    abk_append_line_once "$common_dir/mm/Makefile" 'obj-$(CONFIG_SEW_ALLOC_ADJUST) += sew_alloc_adjust.o'

    sed -i 's/endmenu/config SEW_ALLOC_ADJUST\n\tbool "Sew high-order DMA-IOMMU alloc flags adjustment"\n\tdefault y\n\tdepends on ANDROID_VENDOR_HOOKS\n\thelp\n\t  Drop __GFP_RECLAIM for high-order (order > PAGE_ALLOC_COSTLY_ORDER)\n\t  DMA-IOMMU and kvmalloc allocations to reduce reclaim-induced jank\n\t  under memory pressure (Sew R7).\n\nendmenu/g' "$common_dir/mm/Kconfig"
}

add_os4port_sched() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/init/Kconfig"
    abk_require_file "$common_dir/kernel/task_work.c"
    abk_require_file "$common_dir/kernel/sched/core.c"
    abk_require_file "$common_dir/kernel/sched/Makefile"
    abk_require_file "$common_dir/kernel/sched/vendor_hooks.c"
    abk_require_file "$common_dir/include/trace/hooks/sched.h"

    abk_log "添加 OS4 移植·调度 ……"

    abk_copy_into_kernel "$MODULE_DIR/files/os4port-sched/." "common"

    abk_append_line_once "$common_dir/kernel/task_work.c" 'EXPORT_SYMBOL_GPL(task_work_add);'

    abk_append_line_once "$common_dir/kernel/sched/Makefile" 'obj-$(CONFIG_SEW_RTLOAD) += sew_rtload.o'
    abk_append_line_once "$common_dir/kernel/sched/Makefile" 'obj-$(CONFIG_SCHED_YIELD_PENALTY) += sew_yield_penalty.o'
    abk_append_line_once "$common_dir/kernel/sched/Makefile" 'obj-$(CONFIG_SEW_QOS_INHERIT) += sew_qos_inherit.o'

    abk_append_line_once "$common_dir/kernel/sched/vendor_hooks.c" 'EXPORT_TRACEPOINT_SYMBOL_GPL(android_rvh_before_do_sched_yield);'

    sed -i 's/\trq = this_rq_lock_irq(\&rf);/\tlong skip = 0;\n\n\ttrace_android_rvh_before_do_sched_yield(\&skip);\n\tif (skip)\n\t\treturn;\n\trq = this_rq_lock_irq(\&rf);/g' "$common_dir/kernel/sched/core.c"

    sed -i 's/struct cgroup_subsys_state;/DECLARE_RESTRICTED_HOOK(android_rvh_before_do_sched_yield,\n\tTP_PROTO(long *unused),\n\tTP_ARGS(unused), 1);\n\nstruct cgroup_subsys_state;/g' "$common_dir/include/trace/hooks/sched.h"

    sed -i 's/menu "Scheduler features"/menu "Scheduler features"\n\nconfig SEW_RTLOAD\n\ttristate "Sew RT load observer (kprobe on __sched_setscheduler)"\n\tdepends on KPROBES \&\& ARM64\n\tdefault n\n\thelp\n\t  Count SCHED_FIFO\/SCHED_RR policy requests through a kprobe on\n\t  __sched_setscheduler and expose the counters through\n\t  \/dev\/sew_rtload. Observation only; no scheduling behavior is\n\t  changed. (Module lives in kernel\/sched\/sew_rtload.c; the config\n\t  sits with the Sew family because kernel\/sched\/ has no Kconfig of\n\t  its own.)/g' "$common_dir/init/Kconfig"
    sed -i 's/menu "Scheduler features"/menu "Scheduler features"\n\nconfig SCHED_YIELD_PENALTY\n\ttristate "Sew yield penalty"\n\tdepends on ANDROID_VENDOR_HOOKS\n\tdefault n\n\thelp\n\t  OS4 sched-penalty port: replace sched_yield() of a target task\n\t  with a bounded sleep up to the next frame boundary. uid-gated\n\t  (app range only), off by default./g' "$common_dir/init/Kconfig"
    sed -i 's/menu "Scheduler features"/menu "Scheduler features"\n\nconfig SEW_QOS_INHERIT\n\ttristate "Sew minimal futex QOS-inheritance"\n\tdepends on ANDROID_VENDOR_HOOKS\n\tdefault n\n\thelp\n\t  OS4 xr_qi reduced port: uclamp_min hint for futex waiters of a\n\t  configured vip tgid. Lock-inheritance on the futex chain only./g' "$common_dir/init/Kconfig"

    abk_enable_config CONFIG_SEW_RTLOAD
    abk_enable_config CONFIG_SEW_QOS_INHERIT
    abk_enable_config CONFIG_SCHED_YIELD_PENALTY
}

add_os4port_mm() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/mm/Kconfig"
    abk_require_file "$common_dir/mm/Makefile"
    abk_require_file "$common_dir/mm/vmscan.c"
    abk_require_file "$common_dir/mm/page_alloc.c"
    abk_require_file "$common_dir/include/trace/hooks/mm.h"
    abk_require_file "$common_dir/include/trace/hooks/vmscan.h"
    abk_require_file "$common_dir/drivers/android/vendor_hooks.c"

    abk_log "添加 OS4 移植·内存 ……"

    abk_copy_into_kernel "$MODULE_DIR/files/os4port-mm/." "common"

    abk_append_line_once "$common_dir/mm/Makefile" 'obj-$(CONFIG_SEW_UNFAIRMEM) += sew_unfairmem.o'
    abk_append_line_once "$common_dir/mm/Makefile" 'obj-$(CONFIG_SEW_MI_RECLAIM) += sew_mi_reclaim.o'
    abk_append_line_once "$common_dir/mm/Makefile" 'obj-$(CONFIG_SEW_DYNAMIC_READAHEAD) += sew_dynamic_readahead.o'
    abk_append_line_once "$common_dir/mm/Makefile" 'obj-$(CONFIG_SEW_SCENE_SWAPPINESS) += sew_scene_swappiness.o'
    abk_append_line_once "$common_dir/mm/Makefile" 'obj-$(CONFIG_SEW_BOOTMONITOR) += sew_bootmonitor.o'
    abk_append_line_once "$common_dir/mm/Makefile" 'obj-$(CONFIG_SEW_RSS_MONITOR) += sew_rss_monitor.o'

    abk_append_line_once "$common_dir/drivers/android/vendor_hooks.c" 'EXPORT_TRACEPOINT_SYMBOL_GPL(android_vh_get_page_wmark);'
    abk_append_line_once "$common_dir/drivers/android/vendor_hooks.c" 'EXPORT_TRACEPOINT_SYMBOL_GPL(android_vh_alloc_pages_slowpath_start);'
    abk_append_line_once "$common_dir/drivers/android/vendor_hooks.c" 'EXPORT_TRACEPOINT_SYMBOL_GPL(android_vh_direct_reclaim_end);'

    sed -i 's/trace_mm_vmscan_direct_reclaim_end(nr_reclaimed);/trace_mm_vmscan_direct_reclaim_end(nr_reclaimed);\n\ttrace_android_vh_direct_reclaim_end(nr_reclaimed);/g' "$common_dir/mm/vmscan.c"

    sed -i 's/\tmark = wmark_pages(zone, alloc_flags & ALLOC_WMARK_MASK);/\tmark = wmark_pages(zone, alloc_flags \& ALLOC_WMARK_MASK);\n\t\ttrace_android_vh_get_page_wmark(alloc_flags, \&mark);/g' "$common_dir/mm/page_alloc.c"
    sed -i 's/bool should_alloc_retry = false;/bool should_alloc_retry = false;\n\ttrace_android_vh_alloc_pages_slowpath_start(gfp_mask, order);/g' "$common_dir/mm/page_alloc.c"

    sed -i 's/endmenu/config SEW_UNFAIRMEM\n\ttristate "Sew unfairmem: bounded watermark relax for flagged tasks"\n\tdepends on ANDROID_VENDOR_HOOKS\n\tdefault n\n\thelp\n\t  OS4 unfairmem port: relax the allocation watermark for\n\t  sf_pid\/scene_tid (bounded), and have slabd skip slab reclaim\n\t  for those tasks (single-consumer merge in mm\/slabd.c).\n\nendmenu/g' "$common_dir/mm/Kconfig"
    sed -i 's/endmenu/config SEW_MI_RECLAIM\n\ttristate "Sew reclaim-path observability"\n\tdepends on ANDROID_VENDOR_HOOKS\n\tdefault n\n\thelp\n\t  OS4 mi_reclaim idea, observe-only first cut: counts slow-path\n\t  entries and direct-reclaim outcomes via the new hooks.\n\nendmenu/g' "$common_dir/mm/Kconfig"
    sed -i 's/endmenu/config SEW_DYNAMIC_READAHEAD\n\ttristate "Sew dynamic readahead (per-uid)"\n\tdepends on ANDROID_VENDOR_HOOKS\n\tdefault n\n\thelp\n\t  OS4 dynamic_readahead reduced port: per-uid fault_around and\n\t  readahead-window scale control.\n\nendmenu/g' "$common_dir/mm/Kconfig"
    sed -i 's/endmenu/config SEW_BOOTMONITOR\n\ttristate "Sew boot-event logger (OS4 bootmonitor reduced port)"\n\tdefault n\n\thelp\n\t  Record ordered boot-event anchors and mirror the summary into\n\t  the ramoops-persisted kernel log. \/proc\/sew_bootmonitor shows\n\t  the current boot is table. As a module the anchor timestamps\n\t  are relative to modprobe time; say y for kernel-relative ones.\n\nendmenu/g' "$common_dir/mm/Kconfig"
    sed -i 's/endmenu/config SEW_SCENE_SWAPPINESS\n\ttristate "Sew scene-based reclaim swappiness"\n\tdepends on ANDROID_VENDOR_HOOKS\n\tdefault n\n\thelp\n\t  Select the reclaim swappiness value by scene name written to\n\t  \/proc\/sew_scene_swappiness\/scene (default\/game\/camera\/browser).\n\t  Scene "default" is a strict passthrough that never modifies the\n\t  hook value, preserving the vm.swappiness policy set by the\n\t  additional modules.\n\nendmenu/g' "$common_dir/mm/Kconfig"
    sed -i 's/endmenu/config SEW_RSS_MONITOR\n\ttristate "Sew RSS\/runtime monitor for a tgid allowlist"\n\tdepends on TRACEPOINTS\n\tdefault n\n\thelp\n\t  Observe RSS and accumulated runtime of a tgid allowlist through a\n\t  dynamic probe on the sched_stat_runtime tracepoint. Tasks whose\n\t  RSS crosses rss_threshold_kb are reported via ratelimited kernel\n\t  logs; stats are readable from \/dev\/sew_rss_monitor. Observation\n\t  only.\n\nendmenu/g' "$common_dir/mm/Kconfig"

    sed -i 's/#endif \/\* _TRACE_HOOK_MM_H \*\//DECLARE_HOOK(android_vh_get_page_wmark,\n\tTP_PROTO(unsigned int alloc_flags, unsigned long *page_wmark),\n\tTP_ARGS(alloc_flags, page_wmark));\n#endif \/\* _TRACE_HOOK_MM_H \*\//g' "$common_dir/include/trace/hooks/mm.h"

    sed -i 's/#endif \/\* _TRACE_HOOK_VMSCAN_H \*\//DECLARE_HOOK(android_vh_alloc_pages_slowpath_start,\n\tTP_PROTO(gfp_t gfp_mask, unsigned int order),\n\tTP_ARGS(gfp_mask, order));\n\tDECLARE_HOOK(android_vh_direct_reclaim_end,\n\tTP_PROTO(unsigned long nr_reclaimed),\n\tTP_ARGS(nr_reclaimed));\n#endif \/\* _TRACE_HOOK_VMSCAN_H \*\//g' "$common_dir/include/trace/hooks/vmscan.h"

    abk_enable_config CONFIG_SEW_UNFAIRMEM
}

add_xiaomi_boottime() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/drivers/Kconfig"
    abk_require_file "$common_dir/drivers/Makefile"

    abk_log "添加 xiaomi-boottime ……"

    abk_copy_into_kernel "$MODULE_DIR/files/xiaomi-boottime/." "common"

    abk_append_line_once "$common_dir/drivers/Makefile" 'obj-y\t\t\t+= xiaomi/'

    abk_append_line_once "$common_dir/drivers/Kconfig" 'source "drivers/xiaomi/Kconfig"'
}