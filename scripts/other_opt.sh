export POLLY_BLOCK=$(cat <<- 'EOF'

ifdef CONFIG_LLVM_POLLY
KBUILD_CFLAGS        += -mllvm -polly \
                   -mllvm -polly-run-inliner \
                   -mllvm -polly-ast-use-context \
                   -mllvm -polly-detect-keep-going \
                   -mllvm -polly-invariant-load-hoisting \
                   -mllvm -polly-vectorizer=stripmine

ifeq ($(shell test $(CONFIG_CLANG_VERSION) -gt 130000; echo $$?),0)
KBUILD_CFLAGS        += -mllvm -polly-loopfusion-greedy=1 \
                   -mllvm -polly-reschedule=1 \
                   -mllvm -polly-postopts=1 \
                   -mllvm -polly-num-threads=0 \
                   -mllvm -polly-omp-backend=LLVM \
                   -mllvm -polly-scheduling=dynamic \
                   -mllvm -polly-scheduling-chunksize=1
else
KBUILD_CFLAGS        += -mllvm -polly-opt-fusion=max
endif

# Polly may optimise loops with dead paths beyound what the linker
# can understand. This may negate the effect of the linker's DCE
# so we tell Polly to perfom proven DCE on the loops it optimises
# in order to preserve the overall effect of the linker's DCE.
ifdef CONFIG_LD_DEAD_CODE_DATA_ELIMINATION
POLLY_FLAGS        += -mllvm -polly-run-dce
endif
endif
EOF)

export OPT_A510=$(cat <<- 'EOF'

ifeq ($(shell test $(CONFIG_CLANG_VERSION) -gt 130000 2>/dev/null; echo $$?),0)
KBUILD_CFLAGS	+= -march=armv9-a+crypto+nosve -mcpu=cortex-a510
KBUILD_AFLAGS   += -march=armv9-a+crypto+nosve -mcpu=cortex-a510
endif
ifeq ($(CONFIG_LD_IS_LLD), y)
KBUILD_LDFLAGS  += -mllvm -march=armv9-a+crypto+nosve -mcpu=cortex-a510
endif
EOF)

export TRACE_PRINTK_BLOCK=$(cat << 'EOF'

if TRACING

config DISABLE_TRACE_PRINTK
	bool "Force disable trace_printk() usage"
	default y
	help
	  When trace_printk() is used in any of the kernel source, it enables
	  debugging functions which are not desired for production kernel.
	  Enabling this option will replace trace_printk() with pr_debug().

	  If in doubt, say Y.

endif
EOF)

other_opt() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/fs/f2fs/gc.c"
    abk_require_file "$common_dir/fs/f2fs/gc.h"
    abk_require_file "$common_dir/fs/f2fs/f2fs.h"
    abk_require_file "$common_dir/mm/vmstat.c"
    abk_require_file "$common_dir/fs/f2fs/data.c"
    abk_require_file "$common_dir/fs/f2fs/sysfs.c"
    abk_require_file "$common_dir/fs/f2fs/super.c"
    abk_require_file "$common_dir/mm/page_alloc.c"
    abk_require_file "$common_dir/fs/f2fs/segment.h"
    abk_require_file "$common_dir/kernel/sched/fair.c"
    abk_require_file "$common_dir/kernel/power/process.c"
    abk_require_file "$common_dir/kernel/time/alarmtimer.c"
    abk_require_file "$common_dir/kernel/power/wakelock.c"
    abk_require_file "$common_dir/drivers/android/binder_alloc.c"

    abk_log "其他优化……"

    o3_opt
    add_ssg
    opt_a510
    opt_string
    opt_power
    opt_page_clear
    opt_copy_page
    opt_trace_printk
    enable_llvm_polly
    add_boeffla_wl_blocker
    add_mi_rmap_efficiency
    add_xiaomi-unionpower
    add_sew_mmap_bypass
    add_sew_alloc_adjust
    add_os4port_sched
    add_os4port_mm
    add_xiaomi_boottime

    sed -i 's/msecs_to_jiffies(20)/msecs_to_jiffies(8)/g' "$common_dir/fs/f2fs/f2fs.h"

    sed -i 's/__read_mostly = 15000/__read_mostly/g' "$common_dir/mm/page_alloc.c"

    sed -i 's/__read_mostly = HZ/__read_mostly = 20 * HZ/g' "$common_dir/mm/vmstat.c"

    sed -i 's/20 * MSEC_PER_SEC/MSEC_PER_SEC/g' "$common_dir/kernel/power/process.c"

    sed -i 's/__pm_stay_awake(wl->ws)/__pm_wakeup_event(wl->ws, 500)/g' "$common_dir/kernel/power/wakelock.c"

    sed -i 's/2 * MSEC_PER_SEC/ktime_to_ms(min) + 5/g' "$common_dir/kernel/time/alarmtimer.c"

    sed -i 's/DEF_MIN_FSYNC_BLOCKS\t8/DEF_MIN_FSYNC_BLOCKS\t20/g' "$common_dir/fs/f2fs/segment.h"

    sed -i 's/static_branch_unlikely/IS_ENABLED(CONFIG_NUMA_BALANCING) \&\& static_branch_unlikely/g' "$common_dir/kernel/sched/fair.c"
 
    sed -i 's/find_get_page(mapping, index)/find_get_page_flags(mapping, index, FGP_ACCESSED)/g' "$common_dir/fs/f2fs/data.c"

    sed -i 's/DEF_GC_THREAD_URGENT_SLEEP_TIME\t500/DEF_GC_THREAD_URGENT_SLEEP_TIME\t50/g' "$common_dir/fs/f2fs/gc.h"

    sed -i 's/ MEMORY_MODE_NORMAL;/ MEMORY_MODE_NORMAL;\n\tset_opt(sbi, ATGC);\n\tset_opt(sbi, GC_MERGE);/g' "$common_dir/fs/f2fs/super.c"

    sed -i 's/F2FS_RW_ATTR(GC_THREAD, f2fs_gc_kthread, gc_urgent_sleep_time/F2FS_RO_ATTR(GC_THREAD, f2fs_gc_kthread, gc_urgent_sleep_time/g' "$common_dir/fs/f2fs/sysfs.c"

    perl -0777 -pi -e 's/\tsbi->gc_thread = NULL;\s+}\s+out:/\tsbi->gc_thread = NULL;\n\t}\n\tset_task_ioprio(sbi->gc_thread->f2fs_gc_task, IOPRIO_PRIO_VALUE(IOPRIO_CLASS_IDLE, 0));\nout:/g' "$common_dir/fs/f2fs/gc.c"

    sed -i 's/kfree(alloc->pages)/kvfree(alloc->pages)/g' "$common_dir/drivers/android/binder_alloc.c"
    sed -i 's/kcalloc(alloc->buffer_size/kvcalloc(alloc->buffer_size/g' "$common_dir/drivers/android/binder_alloc.c"
    perl -0777 -pi -e 's/\s+kvfree\(alloc->pages\);\s+}\s+mutex_unlock\(&alloc->mutex\);/\n\t}\n\tmutex_unlock(&alloc->mutex);\n\tkvfree(alloc->pages);/gs' "$common_dir/drivers/android/binder_alloc.c"

    abk_copy_into_kernel "$MODULE_DIR/files/other/." "common"
}

o3_opt() {
    local common_dir target_makefile
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/init/Kconfig"

    abk_log "启用 -O3 优化……"

    sed -i 's/\tdepends on ARC$//g' "$common_dir/init/Kconfig"

    abk_enable_config CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3
}

add_ssg() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/block/Makefile"
    abk_require_file "$common_dir/block/Kconfig.iosched"

    abk_log "添加 SSG IO 调度器……"

    abk_copy_into_kernel "$MODULE_DIR/files/ssg/." "common"

    sed -i 's/bfq.o/bfq.o\n\nssg-$(CONFIG_MQ_IOSCHED_SSG)\t:= ssg-iosched.o\nssg-$(CONFIG_MQ_IOSCHED_SSG_CGROUP)\t+= ssg-cgroup.o\nobj-$(CONFIG_MQ_IOSCHED_SSG)\t+= ssg.o\n\nobj-$(CONFIG_BLK_CMDLINE_PARSER)\t+= cmdline-parser.o/g' "$common_dir/block/Makefile"

    sed -i 's/endmenu/config MQ_IOSCHED_SSG\n\ttristate "SamSung Generic I\/O scheduler"\n\tdefault n\n\thelp\n\t  SamSung Generic IO scheduler.\n\nconfig MQ_IOSCHED_SSG_CGROUP\n\ttristate "Control Group for SamSung Generic I\/O scheduler"\n\tdefault n\n\tdepends on BLK_CGROUP\n\tdepends on MQ_IOSCHED_SSG\n\thelp\n\t  Control Group for SamSung Generic IO scheduler.\n\nendmenu/g' "$common_dir/block/Kconfig.iosched"

    abk_enable_config CONFIG_MQ_IOSCHED_SSG
    abk_enable_config CONFIG_MQ_IOSCHED_SSG_CGROUP
}

opt_a510() {
    local common_dir target_makefile
    common_dir="$(abk_common_dir)"
    target_makefile="$common_dir/arch/arm64/Makefile"

    abk_require_file "$target_makefile"

    if ! grep -Fq -- "-mcpu=cortex-a510" "$target_makefile"; then
        abk_log "针对 Cortex-A510 优化编译器……"
        awk '{
            print $0;
            if (prev ~ /\$\(warning Detected assembler with broken .inst; disassembly will be unreliable\)/ && $0 ~ /^endif/) {
                print ENVIRON["OPT_A510"]
            }
            prev = $0
        }' "$target_makefile" > "$target_makefile.tmp" && mv "$target_makefile.tmp" "$target_makefile"
    fi
}

opt_string() {
    local common_dir target_makefile
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/arch/arm64/lib/strcmp.S"
    abk_require_file "$common_dir/arch/arm64/lib/strncmp.S"
    abk_require_file "$common_dir/arch/arm64/lib/memcmp.S"
    abk_require_file "$common_dir/arch/arm64/include/asm/string.h"
    abk_require_file "$common_dir/arch/arm64/include/asm/assembler.h"

    abk_log "更新 string lib"

    abk_copy_into_kernel "$MODULE_DIR/files/opt_string/." "common"

    sed -i 's/EXPORT_SYMBOL_NOHWKASAN/EXPORT_SYMBOL_NOKASAN/g' "$common_dir/arch/arm64/lib/strncmp.S"

    sed -i '/#ifdef CONFIG_KASAN_HW_TAGS/,/#endif/d' "$common_dir/arch/arm64/include/asm/assembler.h"

    perl -0777 -pi -e 's/#ifndef CONFIG_KASAN_HW_TAGS\n((?:[^\n]*\n)*?)#endif\n/$1/g' "$common_dir/arch/arm64/include/asm/string.h"

}

opt_power() {
    local common_dir target_makefile
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/mm/vmstat.c"
    abk_require_file "$common_dir/fs/fs-writeback.c"
    abk_require_file "$common_dir/kernel/sched/psi.c"
    abk_require_file "$common_dir/fs/incfs/data_mgmt.c"
    abk_require_file "$common_dir/mm/page_reporting.c"

    abk_log "使用节能工作队列……"

    sed -i 's/schedule_delayed_work(/queue_delayed_work(system_power_efficient_wq, /g' "$common_dir/mm/vmstat.c"
    sed -i 's/schedule_delayed_work(/queue_delayed_work(system_power_efficient_wq, /g' "$common_dir/fs/fs-writeback.c"
    sed -i 's/schedule_delayed_work(/queue_delayed_work(system_power_efficient_wq, /g' "$common_dir/kernel/sched/psi.c"
    sed -i 's/schedule_delayed_work(/queue_delayed_work(system_power_efficient_wq, /g' "$common_dir/fs/incfs/data_mgmt.c"
    sed -i 's/schedule_delayed_work(/queue_delayed_work(system_power_efficient_wq, /g' "$common_dir/mm/page_reporting.c"
}

opt_page_clear() {
    local common_dir target_makefile
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/arch/arm64/lib/clear_page.S"
    abk_require_file "$common_dir/arch/arm64/mm/mmu.c"
    abk_require_file "$common_dir/fs/ext4/super.c"
    abk_require_file "$common_dir/fs/f2fs/segment.c"
    abk_require_file "$common_dir/fs/f2fs/segment.h"
    abk_require_file "$common_dir/kernel/trace/tracing_map.c"

    abk_log "优化 page clearing"

    abk_copy_into_kernel "$MODULE_DIR/files/clear_page/." "common"

    sed -i 's/memset(ptr, 0, PAGE_SIZE)/clear_page(ptr)/g' "$common_dir/arch/arm64/mm/mmu.c"

    sed -i 's/memset(buf, 0, PAGE_SIZE)/clear_page(buf)/g' "$common_dir/fs/ext4/super.c"

    sed -i 's/memset(dst, 0, PAGE_SIZE)/clear_page(dst)/g' "$common_dir/fs/f2fs/segment.c"
    sed -i 's/memset(kaddr, 0, PAGE_SIZE)/clear_page(kaddr)/g' "$common_dir/fs/f2fs/segment.c"

    sed -i 's/memset(raw_sit, 0, PAGE_SIZE)/clear_page(raw_sit)/g' "$common_dir/fs/f2fs/segment.h"

    sed -i 's/memset(a->pages\[i\], 0, PAGE_SIZE)/clear_page(a->pages\[i\])/g' "$common_dir/kernel/trace/tracing_map.c"
}

opt_copy_page() {
    local common_dir target_makefile
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/drivers/block/zram/zram_drv.c"
    abk_require_file "$common_dir/mm/zsmalloc.c"
    abk_require_file "$common_dir/fs/f2fs/checkpoint.c"
    abk_require_file "$common_dir/fs/f2fs/compress.c"
    abk_require_file "$common_dir/fs/f2fs/node.c"
    abk_require_file "$common_dir/fs/f2fs/segment.c"

    abk_log "优化 copy page"

    sed -i 's/memcpy(dst, src, PAGE_SIZE)/copy_page(dst, src)/g' "$common_dir/drivers/block/zram/zram_drv.c"

    sed -i 's/memcpy(d_addr, s_addr, PAGE_SIZE)/copy_page(d_addr, s_addr)/g' "$common_dir/mm/zsmalloc.c"

    sed -i 's/memcpy(page_address(page), src, PAGE_SIZE)/copy_page(page_address(page), src)/g' "$common_dir/fs/f2fs/checkpoint.c"

    sed -i 's/memcpy(page_address(cpage), page_address(page), PAGE_SIZE)/copy_page(page_address(cpage), page_address(page))/g' "$common_dir/fs/f2fs/compress.c"
    perl -0777 -pi -e 's/memcpy\(page_address\(page\),\s+page_address\(cpage\), PAGE_SIZE\)/copy_page(page_address(page), page_address(cpage))/gs' "$common_dir/fs/f2fs/compress.c"

    sed -i 's/memcpy(dst_addr, src_addr, PAGE_SIZE)/copy_page(dst_addr, src_addr)/g' "$common_dir/fs/f2fs/node.c"

    sed -i 's/memcpy(page_address(page), src, PAGE_SIZE)/copy_page(page_address(page), src)/g' "$common_dir/fs/f2fs/segment.c"
}

opt_trace_printk() {
    local common_dir target_file
    common_dir="$(abk_common_dir)"
    target_file="$common_dir/kernel/trace/Kconfig"

    abk_require_file "$target_file"
    abk_require_file "$common_dir/include/linux/kernel.h"

    abk_log "启用 TRACE_PRINTK 优化……"

    perl -0777 -pi -e 's/^(#define trace_printk\(fmt, \.\.\.\)[\s\S]*?__trace_printk[\s\S]*?\} while \(0\))/#ifdef CONFIG_DISABLE_TRACE_PRINTK\n#define trace_printk pr_debug\n#else\n$1\n#endif/m' "$common_dir/include/linux/kernel.h"

    if ! grep -Fq "DISABLE_TRACE_PRINTK" "$target_file"; then
        awk '{
            print $0;
            if (prev ~ /\tbool$/ && $0 ~ /\tselect TRACING$/) {
                print ENVIRON["TRACE_PRINTK_BLOCK"]
            }
            prev = $0
        }' "$target_file" > "$target_file.tmp" && mv "$target_file.tmp" "$target_file"
    fi
}

enable_llvm_polly() {
    local common_dir target_makefile
    common_dir="$(abk_common_dir)"
    target_makefile="$common_dir/Makefile"

    abk_require_file "$target_makefile"
    abk_require_file "$common_dir/arch/Kconfig"

    abk_copy_into_kernel "$MODULE_DIR/files/llvm/." "common"

    abk_append_line_once "$common_dir/arch/Kconfig" 'source "arch/llvm/Kconfig"'

    if ! grep -Fq "CONFIG_LLVM_POLLY" "$target_makefile"; then
        abk_log "启用 LLVM_POLLY ……"
        awk '{
            print $0;
            if (prev ~ /KBUILD_CFLAGS \+= -Os/ && $0 ~ /^endif/) {
                print ENVIRON["POLLY_BLOCK"]
            }
            prev = $0
        }' "$target_makefile" > "$target_makefile.tmp" && mv "$target_makefile.tmp" "$target_makefile"
    fi

    abk_enable_config CONFIG_LLVM_POLLY
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