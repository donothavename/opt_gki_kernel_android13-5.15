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

other_opt() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/fs/f2fs/data.c"

    abk_log "其他优化……"

    opt_a510
    opt_string
    opt_page_clear
    opt_copy_page
    enable_llvm_polly

    sed -i 's/find_get_page(mapping, index)/find_get_page_flags(mapping, index, FGP_ACCESSED)/g' "$common_dir/fs/f2fs/data.c"
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
    abk_require_file "$common_dir/arch/arm64/lib/memcmp.S"

    abk_log "更新 string lib"

    abk_copy_into_kernel "$MODULE_DIR/files/opt_string/." "common"
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